import CoreData
import NaasteKit
import Testing
@testable import NaasteApp

/// Delen en wissen. Echt delen via iCloud kan alleen met twee toestellen en Apple ID's;
/// hier wordt getest wat zonder iCloud te controleren is.
@MainActor
@Suite("Delen en wissen")
struct DelenTests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.viewContext }

    private func maakApp() throws -> AppModel {
        let defaults = try #require(UserDefaults(suiteName: "DelenTests-\(UUID())"))
        return AppModel(persistence: persistence, entitlements: EntitlementStore(defaults: defaults))
    }

    @Test func nietGedeeldZonderShare() throws {
        let app = try maakApp()
        let naaste = Naaste(context: context)
        try persistence.bewaar()
        #expect(app.delen.share(van: naaste) == nil)
        #expect(app.delen.aantalDeelnemers(van: nil) == 0)
        #expect(!app.delen.isDeelnemer(bij: naaste))
    }

    @Test func voorbeeldKanNietGedeeldWorden() throws {
        let app = try maakApp()
        let voorbeeld = try #require(app.laadVoorbeeld())
        app.openDelen(voorbeeld, uitnodigen: true)
        #expect(app.paywall == nil)
        #expect(app.foutmelding == nil)
    }

    @Test func allesWissen() async throws {
        let app = try maakApp()
        let naaste = Naaste(context: context)
        naaste.naam = "Riet"
        let lid = Familielid(context: context)
        lid.naaste = naaste
        let document = Document(context: context)
        document.naaste = naaste
        let losseTaak = Taak(context: context) // zonder naaste: moet ook weg
        losseTaak.titel = "los"
        _ = try #require(app.laadVoorbeeld())
        try persistence.bewaar()

        let sleutel = Opslagsleutel.ikBen(naaste)
        UserDefaults.standard.set(lid.uuid?.uuidString, forKey: sleutel)
        UserDefaults.standard.set(naaste.uuid?.uuidString, forKey: Opslagsleutel.geselecteerdeNaaste)

        let gelukt = await app.wisAlleGegevens()
        #expect(gelukt)
        for entiteit in AppModel.alleEntiteiten {
            let aantal = try context.count(for: NSFetchRequest<NSManagedObject>(entityName: entiteit))
            #expect(aantal == 0, "\(entiteit) is niet leeg")
        }
        #expect(UserDefaults.standard.string(forKey: sleutel) == nil)
        #expect(UserDefaults.standard.string(forKey: Opslagsleutel.geselecteerdeNaaste) == nil)
    }
}
