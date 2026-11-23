import CoreData
import NaasteKit
import Testing
@testable import NaasteApp

/// Zaken, tijdlijn en welke herinneringen een melding krijgen.
@MainActor
@Suite("Zaken en herinneringen")
struct ZaakTests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.viewContext }

    private func maakApp() throws -> AppModel {
        let defaults = try #require(UserDefaults(suiteName: "ZaakTests-\(UUID())"))
        return AppModel(persistence: persistence, entitlements: EntitlementStore(defaults: defaults))
    }

    private func dagen(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: .now)!
    }

    @Test func meldingenAlleenVoorEchteNaasten() throws {
        let app = try maakApp()
        let echt = Naaste(context: context)
        echt.naam = "Riet"
        let herinnering = Herinnering(context: context)
        herinnering.naaste = echt
        herinnering.titel = "CAK betalen"
        herinnering.datum = dagen(10)
        let klaar = Herinnering(context: context)
        klaar.naaste = echt
        klaar.datum = dagen(5)
        klaar.afgerond = true

        let zaak = Zaak(context: context)
        zaak.naaste = echt
        zaak.titel = "Wmo"
        zaak.statusWaarde = .inBehandeling
        zaak.vervolgdatum = dagen(3)
        zaak.vervolgHerinneren = true

        let afgerondeZaak = Zaak(context: context)
        afgerondeZaak.naaste = echt
        afgerondeZaak.statusWaarde = .afgerond
        afgerondeZaak.vervolgdatum = dagen(3)
        afgerondeZaak.vervolgHerinneren = true

        // De voorbeeld-naaste heeft ook herinneringen en zaken, maar krijgt geen meldingen.
        let voorbeeld = try #require(app.laadVoorbeeld())
        #expect(!voorbeeld.herinneringenLijst.isEmpty)
        try persistence.bewaar()

        let onderwerpen = app.meldingOnderwerpen()
        #expect(onderwerpen.count == 2)
        #expect(Set(onderwerpen.map(\.titel)) == ["CAK betalen", "Vervolg: Wmo"])
        #expect(onderwerpen.allSatisfy { $0.naaste == "Riet" })
        // Vervolg van een zaak: alleen op de dag zelf.
        #expect(onderwerpen.first { $0.planbaar.id == zaak.uuid }?.planbaar.dagenVooraf == 0)
    }

    @Test func tijdlijnGebruiktGekozenFamilielid() throws {
        let app = try maakApp()
        let naaste = Naaste(context: context)
        let lid = Familielid(context: context)
        lid.naam = "Sanne"
        lid.naaste = naaste
        let zaak = Zaak(context: context)
        zaak.naaste = naaste
        try persistence.bewaar()

        let sleutel = Opslagsleutel.ikBen(naaste)
        defer { UserDefaults.standard.removeObject(forKey: sleutel) }
        #expect(app.auteur(bij: naaste) == nil)
        UserDefaults.standard.set(lid.uuid?.uuidString, forKey: sleutel)
        #expect(app.auteur(bij: naaste) == "Sanne")

        app.voegGebeurtenisToe(aan: zaak, soort: .contact, tekst: "Gemeente gebeld")
        #expect(zaak.tijdlijn.first?.auteur == "Sanne")
        #expect(zaak.tijdlijn.first?.soortWaarde == .contact)
    }

    @Test func documentKoppelenEenKeer() throws {
        let app = try maakApp()
        let naaste = Naaste(context: context)
        let zaak = Zaak(context: context)
        zaak.naaste = naaste
        let document = Document(context: context)
        document.titel = "Beschikking"
        document.naaste = naaste

        app.koppel(document, aan: zaak)
        app.koppel(document, aan: zaak)
        #expect(zaak.documentenLijst == [document])
        #expect(zaak.tijdlijn.count == 1)
        #expect(zaak.tijdlijn.first?.soortWaarde == .document)

        app.ontkoppel(document, van: zaak)
        #expect(zaak.documentenLijst.isEmpty)
        #expect(document.isDeleted == false)
    }

    @Test func zaakVerwijderenLaatDocumentEnHerinneringStaan() throws {
        let naaste = Naaste(context: context)
        let zaak = Zaak(context: context)
        zaak.naaste = naaste
        let document = Document(context: context)
        document.naaste = naaste
        zaak.mutableSetValue(forKey: "documenten").add(document)
        let herinnering = Herinnering(context: context)
        herinnering.naaste = naaste
        herinnering.zaak = zaak
        try persistence.bewaar()

        context.delete(zaak)
        try persistence.bewaar()
        #expect(!document.isDeleted && document.managedObjectContext != nil)
        #expect(herinnering.managedObjectContext != nil)
        #expect(herinnering.zaak == nil)
    }
}
