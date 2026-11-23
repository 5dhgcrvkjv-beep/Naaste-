import CoreData
import Foundation
import NaasteKit

// Getypeerde toegang tot de String-velden en handige afgeleide waarden.

extension Naaste {
    var weergaveNaam: String {
        let schoon = naam?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return schoon.isEmpty ? String(localized: "Naamloos") : schoon
    }

    /// Adres op één regel, of `nil` als er niets is ingevuld.
    var adresRegel: String? {
        let plaatsDeel = [postcode, plaats].compactMap { $0?.nietLeeg }.joined(separator: " ")
        let delen = [straat?.nietLeeg, plaatsDeel.nietLeeg].compactMap { $0 }
        return delen.isEmpty ? nil : delen.joined(separator: ", ")
    }

    var lopendeZaken: [Zaak] {
        zakenLijst.filter { $0.statusWaarde.isLopend }.sorted(by: Zaak.sorteerOpVervolg)
    }

    var openTaken: [Taak] {
        takenLijst.filter { !$0.afgerond }.sorted(by: Taak.sorteer)
    }

    var familieGesorteerd: [Familielid] {
        familieledenLijst.sorted { $0.weergaveNaam.localizedStandardCompare($1.weergaveNaam) == .orderedAscending }
    }

    var contactenGesorteerd: [Contactpersoon] {
        contactenLijst.sorted(by: Contactpersoon.sorteer)
    }
}

extension Contactpersoon {
    /// Op rol (volgorde van `ContactRol`), daarna op naam.
    static func sorteer(_ a: Contactpersoon, _ b: Contactpersoon) -> Bool {
        let ia = ContactRol.allCases.firstIndex(of: a.rolWaarde) ?? 0
        let ib = ContactRol.allCases.firstIndex(of: b.rolWaarde) ?? 0
        return ia != ib ? ia < ib : a.weergaveNaam.localizedStandardCompare(b.weergaveNaam) == .orderedAscending
    }

    var rolWaarde: ContactRol {
        get { ContactRol(opgeslagen: rol) }
        set { rol = newValue.rawValue }
    }

    var weergaveNaam: String {
        naam?.nietLeeg ?? organisatie?.nietLeeg ?? rolWaarde.titel
    }

    /// Tweede regel: organisatie (als die niet al de naam is) of de rol.
    var ondertitel: String {
        if let organisatie = organisatie?.nietLeeg, naam?.nietLeeg != nil {
            return "\(rolWaarde.titel) · \(organisatie)"
        }
        return rolWaarde.titel
    }
}

extension Familielid {
    var weergaveNaam: String { naam?.nietLeeg ?? String(localized: "Familielid") }

    var initialen: String {
        let woorden = weergaveNaam.split(separator: " ")
        let letters = woorden.prefix(2).compactMap(\.first).map(String.init)
        return letters.joined().uppercased()
    }

    var kleurWaarde: FamilieKleur {
        get { FamilieKleur(opgeslagen: kleur) }
        set { kleur = newValue.rawValue }
    }
}

extension Document {
    var categorieWaarde: DocumentCategorie {
        get { DocumentCategorie(opgeslagen: categorie) }
        set { categorie = newValue.rawValue }
    }

    var ocrStatusWaarde: OCRStatus {
        get { OCRStatus(opgeslagen: ocrStatus) }
        set { ocrStatus = newValue.rawValue }
    }

    var weergaveTitel: String { titel?.nietLeeg ?? String(localized: "Document zonder titel") }
}

extension Zaak {
    var statusWaarde: ZaakStatus {
        get { ZaakStatus(opgeslagen: status) }
        set { status = newValue.rawValue }
    }

    var categorieWaarde: DocumentCategorie {
        get { DocumentCategorie(opgeslagen: categorie) }
        set { categorie = newValue.rawValue }
    }

    var weergaveTitel: String { titel?.nietLeeg ?? String(localized: "Zaak zonder titel") }

    var tijdlijn: [ZaakGebeurtenis] {
        gebeurtenissenLijst.sorted { ($0.datum ?? .distantPast) > ($1.datum ?? .distantPast) }
    }

    /// Zaken met de eerstvolgende vervolgdatum eerst; zonder vervolgdatum achteraan.
    static func sorteerOpVervolg(_ a: Zaak, _ b: Zaak) -> Bool {
        switch (a.vervolgdatum, b.vervolgdatum) {
        case let (x?, y?): return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return (a.aangemaakt ?? .distantPast) > (b.aangemaakt ?? .distantPast)
        }
    }

    /// Zet een nieuwe status en legt dat vast in de tijdlijn.
    func zetStatus(_ nieuw: ZaakStatus, op datum: Date = Date(), door auteur: String?, notitie: String? = nil) {
        guard nieuw != statusWaarde, let context = managedObjectContext else { return }
        statusWaarde = nieuw
        if nieuw == .aangevraagd, datumAangevraagd == nil {
            datumAangevraagd = datum
        }
        let gebeurtenis = context.maak(ZaakGebeurtenis.self, bij: self)
        gebeurtenis.zaak = self
        gebeurtenis.datum = datum
        gebeurtenis.soortWaarde = .status
        gebeurtenis.nieuweStatus = nieuw.rawValue
        gebeurtenis.tekst = notitie?.nietLeeg
        gebeurtenis.auteur = auteur
        gewijzigd = Date()
    }
}

extension ZaakGebeurtenis {
    var soortWaarde: GebeurtenisSoort {
        get { GebeurtenisSoort(opgeslagen: soort) }
        set { soort = newValue.rawValue }
    }

    var nieuweStatusWaarde: ZaakStatus? {
        nieuweStatus.flatMap(ZaakStatus.init(rawValue:))
    }
}

extension Herinnering {
    var soortWaarde: HerinneringSoort {
        get { HerinneringSoort(opgeslagen: soort) }
        set { soort = newValue.rawValue }
    }

    var herhalingWaarde: Herhaling {
        get { Herhaling(opgeslagen: herhaling) }
        set { herhaling = newValue.rawValue }
    }

    var weergaveTitel: String { titel?.nietLeeg ?? soortWaarde.titel }

    /// Invoer voor de `ReminderPlanner`, of `nil` zonder datum/ID.
    var planbaar: PlanbareHerinnering? {
        guard let uuid, let datum else { return nil }
        return PlanbareHerinnering(
            id: uuid,
            datum: datum,
            heeftTijd: heeftTijd,
            herhaling: herhalingWaarde,
            dagenVooraf: Int(dagenVooraf),
            afgerond: afgerond
        )
    }

    /// Eerstvolgende keer (rekening houdend met herhaling).
    func volgendeDatum(nu: Date = Date()) -> Date? {
        guard let planbaar else { return datum }
        return ReminderPlanner().volgendeGebeurtenis(van: planbaar, nu: nu)
    }
}

extension Taak {
    var weergaveTitel: String { titel?.nietLeeg ?? String(localized: "Taak zonder titel") }

    /// Open taken: met deadline eerst (vroegste eerst), dan op eigen volgorde/aanmaakdatum.
    static func sorteer(_ a: Taak, _ b: Taak) -> Bool {
        switch (a.deadline, b.deadline) {
        case let (x?, y?) where x != y: return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: return (a.aangemaakt ?? .distantPast) < (b.aangemaakt ?? .distantPast)
        }
    }

    func zetAfgerond(_ klaar: Bool) {
        afgerond = klaar
        afgerondOp = klaar ? Date() : nil
        gewijzigd = Date()
    }
}

extension Urenregel {
    var categorieWaarde: UrenCategorie {
        get { UrenCategorie(opgeslagen: categorie) }
        set { categorie = newValue.rawValue }
    }

    var data: UrenRegelData {
        UrenRegelData(
            datum: datum ?? aangemaakt ?? .distantPast,
            minuten: Int(minuten),
            persoonID: familielid?.uuid?.uuidString,
            persoonNaam: familielid?.weergaveNaam ?? String(localized: "Niet toegewezen"),
            categorie: categorieWaarde
        )
    }
}

extension String {
    /// `nil` als de tekst leeg is of alleen uit spaties bestaat; anders de getrimde tekst.
    var nietLeeg: String? {
        let schoon = trimmingCharacters(in: .whitespacesAndNewlines)
        return schoon.isEmpty ? nil : schoon
    }
}

/// Kleur van een familielid (voor het rondje met initialen).
enum FamilieKleur: String, OpgeslagenEnum {
    case groen, blauw, oranje, paars, roze, bruin, grijs
    static let fallback: FamilieKleur = .groen

    /// Volgende kleur voor een nieuw familielid, zodat iedereen een andere kleur krijgt.
    static func volgende(na gebruikt: [FamilieKleur]) -> FamilieKleur {
        allCases.first { !gebruikt.contains($0) } ?? allCases[gebruikt.count % allCases.count]
    }
}
