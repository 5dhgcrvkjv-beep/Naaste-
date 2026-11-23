import CoreData
import NaasteKit
import SwiftUI

/// Zaken, tijdlijn en meldingen.
extension AppModel {
    // MARK: Wie ben ik

    /// Het familielid dat op deze iPhone als "ik" is gekozen (Instellingen → Familieleden).
    func ik(bij naaste: Naaste) -> Familielid? {
        guard let id = UserDefaults.standard.string(forKey: Opslagsleutel.ikBen(naaste)), !id.isEmpty else { return nil }
        return naaste.familieledenLijst.first { $0.uuid?.uuidString == id }
    }

    /// Naam voor in de tijdlijn ("Sanne zette de status op …").
    func auteur(bij naaste: Naaste?) -> String? {
        naaste.flatMap { ik(bij: $0)?.weergaveNaam }
    }

    // MARK: Tijdlijn

    func voegGebeurtenisToe(aan zaak: Zaak, soort: GebeurtenisSoort, tekst: String, datum: Date = .now) {
        let gebeurtenis = context.maak(ZaakGebeurtenis.self, bij: zaak)
        gebeurtenis.zaak = zaak
        gebeurtenis.soortWaarde = soort
        gebeurtenis.tekst = tekst.nietLeeg
        gebeurtenis.datum = datum
        gebeurtenis.auteur = auteur(bij: zaak.naaste)
        zaak.gewijzigd = .now
    }

    /// Koppelt een document aan een zaak en zet dat in de tijdlijn.
    func koppel(_ document: Document, aan zaak: Zaak) {
        guard !zaak.documentenLijst.contains(document) else { return }
        zaak.mutableSetValue(forKey: "documenten").add(document)
        voegGebeurtenisToe(aan: zaak, soort: .document, tekst: String(localized: "Document gekoppeld: \(document.weergaveTitel)"))
    }

    func ontkoppel(_ document: Document, van zaak: Zaak) {
        zaak.mutableSetValue(forKey: "documenten").remove(document)
        zaak.gewijzigd = .now
    }

    // MARK: Meldingen

    /// Herinneringen en vervolgdatums die een melding krijgen. De voorbeeld-naaste
    /// krijgt geen meldingen: die gegevens zijn verzonnen.
    func meldingOnderwerpen() -> [Meldingen.Onderwerp] {
        var onderwerpen: [Meldingen.Onderwerp] = []
        for herinnering in (try? context.fetch(Herinnering.alleOpen())) ?? [] {
            guard herinnering.naaste?.isVoorbeeld != true, let planbaar = herinnering.planbaar else { continue }
            onderwerpen.append(.init(planbaar: planbaar, titel: herinnering.weergaveTitel, naaste: herinnering.naaste?.weergaveNaam))
        }
        for zaak in (try? context.fetch(Zaak.metVervolgHerinnering())) ?? [] {
            guard zaak.naaste?.isVoorbeeld != true, let id = zaak.uuid, let datum = zaak.vervolgdatum else { continue }
            onderwerpen.append(.init(
                planbaar: PlanbareHerinnering(id: id, datum: datum, dagenVooraf: 0),
                titel: String(localized: "Vervolg: \(zaak.weergaveTitel)"),
                naaste: zaak.naaste?.weergaveNaam
            ))
        }
        return onderwerpen
    }

    func planMeldingen() {
        meldingen.planUitgesteld { [weak self] in self?.meldingOnderwerpen() ?? [] }
    }

    /// Na het bewaren van een herinnering of vervolgdatum: eerst toestemming, dan plannen.
    func vraagMeldingenToestemmingEnPlan() {
        Task {
            await meldingen.vraagToestemmingAlsNodig()
            planMeldingen()
        }
    }
}
