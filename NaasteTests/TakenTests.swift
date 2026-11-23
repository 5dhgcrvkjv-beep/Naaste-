import CoreData
import NaasteKit
import Testing
@testable import NaasteApp

/// Taken (gratis) en het urenlogboek (Plus).
@MainActor
@Suite("Taken en uren")
struct TakenTests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.viewContext }

    @Test func afvinkenZetDatum() {
        let taak = Taak(context: context)
        taak.zetAfgerond(true)
        #expect(taak.afgerond && taak.afgerondOp != nil)
        taak.zetAfgerond(false)
        #expect(!taak.afgerond && taak.afgerondOp == nil)
    }

    @Test func sorteringDeadlineEerst() {
        let zonder = Taak(context: context)
        zonder.titel = "zonder"
        let later = Taak(context: context)
        later.titel = "later"
        later.deadline = Date().addingTimeInterval(86_400 * 5)
        let eerst = Taak(context: context)
        eerst.titel = "eerst"
        eerst.deadline = Date().addingTimeInterval(86_400)
        let volgorde = [zonder, later, eerst].sorted(by: Taak.sorteer).map(\.titel)
        #expect(volgorde == ["eerst", "later", "zonder"])
    }

    @Test func urenlogboekVraagtPlusBehalveBijVoorbeeld() throws {
        let defaults = try #require(UserDefaults(suiteName: "TakenTests-\(UUID())"))
        let app = AppModel(persistence: persistence, entitlements: EntitlementStore(defaults: defaults))
        let eigen = Naaste(context: context)
        try persistence.bewaar()
        #expect(!app.isPlus)

        #expect(!app.heeftToegang(tot: .urenlogboek, bij: eigen))
        #expect(!app.vraagToegang(tot: .urenlogboek, bij: eigen))
        #expect(app.paywall == .functie(.urenlogboek))

        app.paywall = nil
        let voorbeeld = try #require(app.laadVoorbeeld())
        #expect(app.heeftToegang(tot: .urenlogboek, bij: voorbeeld))
        #expect(app.paywall == nil)
    }

    @Test func voorbeeldUrenPerPersoon() throws {
        let defaults = try #require(UserDefaults(suiteName: "TakenTests-\(UUID())"))
        let app = AppModel(persistence: persistence, entitlements: EntitlementStore(defaults: defaults))
        let voorbeeld = try #require(app.laadVoorbeeld())
        let regels = (voorbeeld.urenregels as? Set<Urenregel> ?? []).map(\.data)
        let perPersoon = UrenRekenaar.perPersoon(regels)
        #expect(perPersoon.count >= 2)
        #expect(abs(perPersoon.map(\.aandeel).reduce(0, +) - 1) < 0.0001)
    }
}
