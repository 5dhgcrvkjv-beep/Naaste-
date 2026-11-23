import CoreData
import Foundation
import NaasteKit

/// Voorbeeld-naaste met realistische (verzonnen) gegevens, zodat nieuwe gebruikers
/// en de App Review alle functies direct kunnen zien. Telt niet mee voor de gratis limieten.
///
/// Telefoonnummers beginnen na het netnummer met 0 (bijv. 030 000 …): die worden in
/// Nederland niet uitgegeven, dus een tik op "bellen" bereikt nooit een echt persoon.
/// E-mailadressen gebruiken het gereserveerde domein example.com.
enum VoorbeeldData {
    @discardableResult
    static func maak(in context: NSManagedObjectContext, nu: Date = Date(), calendar: Calendar = .current) -> Naaste {
        func dag(_ offset: Int, uur: Int? = nil, minuut: Int = 0) -> Date {
            let basis = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: nu)) ?? nu
            guard let uur else { return basis }
            return calendar.date(bySettingHour: uur, minute: minuut, second: 0, of: basis) ?? basis
        }

        let naaste = Naaste(context: context)
        naaste.isVoorbeeld = true
        naaste.naam = "Riet de Vries"
        naaste.geboortedatum = calendar.date(from: DateComponents(year: 1941, month: 4, day: 17))
        naaste.straat = "Lindelaan 12"
        naaste.postcode = "3500 AA"
        naaste.plaats = "Utrecht"
        naaste.telefoon = "030 000 0100"
        naaste.huisartsNaam = "Huisartsenpraktijk De Linde"
        naaste.huisartsTelefoon = "030 000 0101"
        naaste.zorgverzekeraar = "Voorbeeld Zorgverzekeraar"
        naaste.polisnummer = "123456789"
        naaste.verzekeraarTelefoon = "030 000 0109"
        naaste.medicatieNotitie = String(localized: "Medicijnoverzicht staat in de blauwe map in de keukenla. Weekdoos wordt op zondag gevuld door de thuiszorg.")
        naaste.notities = String(localized: "Sleutelkastje naast de voordeur, code bij Sanne. Mevrouw hoort slecht aan de linkerkant: rustig en duidelijk praten.")

        // Familie
        let sanne = familielid("Sanne", .groen, naaste, context)
        let mark = familielid("Mark", .blauw, naaste, context)
        let ilse = familielid("Ilse", .oranje, naaste, context)

        // Contactpersonen
        contact(.thuiszorg, "Planning wijkteam Noord", "Thuiszorg Het Anker", "030 000 0102", "planning@example.com", naaste, context)
        contact(.wijkverpleging, "Marieke Jansen", "Wijkverpleging Het Anker", "06 0000 0103", nil, naaste, context)
        contact(.casemanager, "Peter Bakker", "Zorgcoördinatie Utrecht", "030 000 0104", "p.bakker@example.com", naaste, context)
        contact(.gemeente, "Wmo-loket", "Gemeente (voorbeeld)", "030 000 0105", "wmo@example.com", naaste, context)
        contact(.notaris, "mr. A. van Dam", "Notariskantoor Van Dam", "030 000 0106", "info@example.com", naaste, context)
        contact(.bank, "Klantenservice", "Voorbeeldbank", "030 000 0107", nil, naaste, context)

        // Documenten
        let aanvraagWmo = document(
            "Aanvraag Wmo huishoudelijke hulp", .wmo, dag(-21), naaste, context,
            regels: [
                "Melding maatwerkvoorziening Wmo",
                "Naam: R. de Vries, Lindelaan 12, Utrecht",
                "Gevraagde ondersteuning: huishoudelijke hulp, 3 uur per week.",
                "Toelichting: mevrouw kan door verminderde mobiliteit het huishouden niet meer zelf doen.",
                "Contactpersoon familie: Sanne de Vries."
            ]
        )
        document(
            "Polisoverzicht zorgverzekering 2026", .verzekering, dag(-60), naaste, context,
            regels: [
                "Polisoverzicht 2026",
                "Verzekerde: R. de Vries, polisnummer 123456789",
                "Basisverzekering: natura. Aanvullend: pakket Extra.",
                "Eigen risico: verplicht eigen risico van toepassing."
            ]
        )
        let pgb = document(
            "Toekenning pgb dagbesteding", .pgb, dag(-90), naaste, context,
            regels: [
                "Beschikking persoonsgebonden budget",
                "Hierbij ontvangt u de beschikking voor een pgb voor dagbesteding.",
                "Ingangsdatum: 1 januari. Geldig tot en met 31 december.",
                "Het budget wordt beheerd via de Sociale Verzekeringsbank (SVB)."
            ]
        )
        let volmacht = document(
            "Volmacht bankzaken", .juridisch, dag(-200), naaste, context,
            regels: [
                "Volmacht",
                "Ondergetekende, R. de Vries, verleent hierbij volmacht aan S. de Vries",
                "om namens haar bankzaken te regelen bij Voorbeeldbank.",
                "Deze volmacht is opgesteld bij Notariskantoor Van Dam."
            ]
        )

        // Zaken
        let wmo = zaak("Wmo-aanvraag huishoudelijke hulp", .wmo, .inBehandeling, naaste, context)
        wmo.datumAangevraagd = dag(-21)
        wmo.vervolgdatum = dag(5)
        wmo.vervolgHerinneren = true
        wmo.opgepaktDoor = sanne
        wmo.notities = String(localized: "Keukentafelgesprek gehad met consulent van de gemeente. Beslissing binnen 8 weken na de melding.")
        wmo.mutableSetValue(forKey: "documenten").add(aanvraagWmo)
        gebeurtenis(wmo, dag(-24), .notitie, nil, "Keukentafelgesprek gepland met de Wmo-consulent.", "Sanne", context)
        gebeurtenis(wmo, dag(-21), .status, .aangevraagd, "Formulier ingestuurd via het Wmo-loket.", "Sanne", context)
        gebeurtenis(wmo, dag(-10), .contact, nil, "Gemeente gebeld: aanvraag is in behandeling, bericht volgt.", "Mark", context)
        gebeurtenis(wmo, dag(-9), .status, .inBehandeling, nil, "Sanne", context)

        let wlz = zaak("Indicatie Wlz via het CIZ", .wlzCiz, .voorbereiden, naaste, context)
        wlz.opgepaktDoor = mark
        wlz.vervolgdatum = dag(12)
        wlz.vervolgHerinneren = true
        wlz.notities = String(localized: "Eerst met de casemanager bespreken. Gegevens van huisarts en thuiszorg verzamelen.")
        gebeurtenis(wlz, dag(-3), .notitie, nil, "Overleg met casemanager Peter Bakker ingepland.", "Mark", context)

        let pgbZaak = zaak("Pgb voor dagbesteding", .pgb, .toegekend, naaste, context)
        pgbZaak.datumAangevraagd = dag(-130)
        pgbZaak.opgepaktDoor = ilse
        pgbZaak.mutableSetValue(forKey: "documenten").add(pgb)
        gebeurtenis(pgbZaak, dag(-130), .status, .aangevraagd, nil, "Ilse", context)
        gebeurtenis(pgbZaak, dag(-90), .status, .toegekend, "Beschikking ontvangen, budget via de SVB.", "Ilse", context)

        let volmachtZaak = zaak("Volmacht bank regelen", .juridisch, .afgerond, naaste, context)
        volmachtZaak.opgepaktDoor = sanne
        volmachtZaak.mutableSetValue(forKey: "documenten").add(volmacht)
        gebeurtenis(volmachtZaak, dag(-200), .status, .afgerond, "Volmacht getekend bij de notaris.", "Sanne", context)

        // Herinneringen
        herinnering("Herindicatie huishoudelijke hulp", .herindicatie, dag(60), heeftTijd: false, .geen, vooraf: 30, zaak: wmo, naaste, context)
        let volgendeMaand = calendar.date(byAdding: .month, value: 1, to: nu) ?? nu
        var c = calendar.dateComponents([.year, .month], from: volgendeMaand)
        c.day = 1
        herinnering("Eigen bijdrage CAK betalen", .betaling, calendar.date(from: c) ?? dag(14), heeftTijd: false, .maandelijks, vooraf: 3, zaak: nil, naaste, context)
        herinnering("Afspraak huisarts (Sanne gaat mee)", .afspraak, dag(3, uur: 10, minuut: 30), heeftTijd: true, .geen, vooraf: 1, zaak: nil, naaste, context)
        herinnering("Zorgverzekering: overstappen of verlengen", .verlenging, dag(38), heeftTijd: false, .jaarlijks, vooraf: 14, zaak: nil, naaste, context)

        // Taken
        taak("Thuiszorg bellen over nieuwe tijden", mark, deadline: dag(2), naaste, context)
        taak("Kopie ID-bewijs naar de gemeente sturen", sanne, deadline: dag(4), naaste, context)
        taak("Formulier CIZ samen invullen", mark, deadline: dag(10), naaste, context)
        taak("Boodschappen voor het weekend", ilse, deadline: nil, naaste, context)
        let kaart = taak("Verjaardagskaart buurvrouw", ilse, deadline: nil, naaste, context)
        kaart.zetAfgerond(true)

        // Uren (afgelopen weken)
        let uren: [(Int, Familielid, UrenCategorie, Int, String)] = [
            (-1, sanne, .administratie, 45, "Post doorgenomen en CAK-brief opgeborgen"),
            (-2, mark, .vervoer, 120, "Mee naar het ziekenhuis voor controle"),
            (-3, ilse, .huishouden, 90, "Boodschappen en was"),
            (-5, sanne, .gezelschap, 60, "Koffie en wandeling"),
            (-8, mark, .administratie, 30, "Gemeente gebeld over Wmo-aanvraag"),
            (-9, ilse, .huishouden, 75, "Boodschappen"),
            (-12, sanne, .administratie, 90, "Wmo-formulier ingevuld"),
            (-15, mark, .gezelschap, 120, "Zondagmiddag op bezoek"),
            (-16, ilse, .vervoer, 60, "Naar de kapper gebracht"),
            (-20, sanne, .persoonlijkeZorg, 45, "Helpen met douchen toen thuiszorg uitviel")
        ]
        for (offset, persoon, categorie, minuten, omschrijving) in uren {
            let regel = Urenregel(context: context)
            regel.naaste = naaste
            regel.familielid = persoon
            regel.datum = dag(offset, uur: 14)
            regel.categorieWaarde = categorie
            regel.minuten = Int32(minuten)
            regel.omschrijving = omschrijving
        }

        return naaste
    }

    // MARK: - Hulpjes

    @discardableResult
    private static func familielid(_ naam: String, _ kleur: FamilieKleur, _ naaste: Naaste, _ context: NSManagedObjectContext) -> Familielid {
        let lid = Familielid(context: context)
        lid.naam = naam
        lid.kleurWaarde = kleur
        lid.naaste = naaste
        return lid
    }

    @discardableResult
    private static func contact(_ rol: ContactRol, _ naam: String, _ organisatie: String, _ telefoon: String?, _ email: String?, _ naaste: Naaste, _ context: NSManagedObjectContext) -> Contactpersoon {
        let contact = Contactpersoon(context: context)
        contact.rolWaarde = rol
        contact.naam = naam
        contact.organisatie = organisatie
        contact.telefoon = telefoon
        contact.email = email
        contact.naaste = naaste
        return contact
    }

    @discardableResult
    private static func document(_ titel: String, _ categorie: DocumentCategorie, _ datum: Date, _ naaste: Naaste, _ context: NSManagedObjectContext, regels: [String]) -> Document {
        var opmaak = PDFOpmaak()
        opmaak.voettekst = String(localized: "Voorbeelddocument – niet echt")
        opmaak.voegToe(.titel(regels.first ?? titel))
        opmaak.voegToe(.ondertitel(datum.formatted(date: .long, time: .omitted)))
        for regel in regels.dropFirst() {
            opmaak.voegToe(.tekst(regel))
        }
        opmaak.voegToe(.ruimte(24))
        opmaak.voegToe(.kleineTekst(String(localized: "Dit is een voorbeelddocument in de app Naaste. Het bevat verzonnen gegevens.")))

        let document = Document(context: context)
        document.titel = titel
        document.categorieWaarde = categorie
        document.documentDatum = datum
        document.bestand = opmaak.maakPDF(titelMetadata: titel)
        document.bestandsnaam = "\(titel).pdf"
        document.paginas = 1
        document.ocrTekst = regels.joined(separator: "\n")
        document.ocrStatusWaarde = .klaar
        document.naaste = naaste
        return document
    }

    private static func zaak(_ titel: String, _ categorie: DocumentCategorie, _ status: ZaakStatus, _ naaste: Naaste, _ context: NSManagedObjectContext) -> Zaak {
        let zaak = Zaak(context: context)
        zaak.titel = titel
        zaak.categorieWaarde = categorie
        zaak.statusWaarde = status
        zaak.naaste = naaste
        return zaak
    }

    private static func gebeurtenis(_ zaak: Zaak, _ datum: Date, _ soort: GebeurtenisSoort, _ status: ZaakStatus?, _ tekst: String?, _ auteur: String, _ context: NSManagedObjectContext) {
        let g = ZaakGebeurtenis(context: context)
        g.zaak = zaak
        g.datum = datum
        g.soortWaarde = soort
        g.nieuweStatus = status?.rawValue
        g.tekst = tekst
        g.auteur = auteur
    }

    private static func herinnering(_ titel: String, _ soort: HerinneringSoort, _ datum: Date, heeftTijd: Bool, _ herhaling: Herhaling, vooraf: Int, zaak: Zaak?, _ naaste: Naaste, _ context: NSManagedObjectContext) {
        let h = Herinnering(context: context)
        h.titel = titel
        h.soortWaarde = soort
        h.datum = datum
        h.heeftTijd = heeftTijd
        h.herhalingWaarde = herhaling
        h.dagenVooraf = Int16(vooraf)
        h.zaak = zaak
        h.naaste = naaste
    }

    @discardableResult
    private static func taak(_ titel: String, _ persoon: Familielid, deadline: Date?, _ naaste: Naaste, _ context: NSManagedObjectContext) -> Taak {
        let taak = Taak(context: context)
        taak.titel = titel
        taak.toegewezenAan = persoon
        taak.deadline = deadline
        taak.naaste = naaste
        return taak
    }
}
