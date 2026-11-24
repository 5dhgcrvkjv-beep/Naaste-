import CoreData
import EventKit
import Testing
import UIKit
@testable import NaasteApp

@MainActor
@Suite("Navigatie, Spotlight en agenda", .serialized)
struct NavigatieTests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.viewContext }

    @Test func spotlightIDWordtBestemming() {
        let navigatie = Navigatie.shared
        navigatie.isVergrendeld = { false }
        let id = UUID()
        navigatie.open(spotlightID: "document/\(id.uuidString)")
        #expect(navigatie.open == .document(id))
        navigatie.open(spotlightID: "zaak/\(id.uuidString)")
        #expect(navigatie.open == .zaak(id))
        navigatie.open = nil
        navigatie.open(spotlightID: "onzin")
        #expect(navigatie.open == nil)
    }

    @Test func snelleActies() {
        let navigatie = Navigatie.shared
        navigatie.isVergrendeld = { false }
        #expect(navigatie.voerUit(UIApplicationShortcutItem(type: "nl.naaste.scan", localizedTitle: "")))
        #expect(navigatie.open == .scan)
        #expect(navigatie.voerUit(UIApplicationShortcutItem(type: "nl.naaste.uren", localizedTitle: "")))
        #expect(navigatie.open == .uren)
        #expect(!navigatie.voerUit(UIApplicationShortcutItem(type: "iets.anders", localizedTitle: "")))
        navigatie.open = nil
    }

    @Test func wachtOpOntgrendelen() {
        let navigatie = Navigatie.shared
        var slot = true
        navigatie.isVergrendeld = { slot }
        navigatie.open = nil
        navigatie.voerUit(UIApplicationShortcutItem(type: "nl.naaste.scan", localizedTitle: ""))
        #expect(navigatie.open == nil)
        slot = false
        navigatie.gaVerderNaOntgrendelen()
        #expect(navigatie.open == .scan)
        navigatie.open = nil
        navigatie.isVergrendeld = { false }
    }

    @Test func spotlightZonderVoorbeeldEnAfgerondeTaken() throws {
        let defaults = try #require(UserDefaults(suiteName: "NavigatieTests-\(UUID())"))
        let app = AppModel(persistence: persistence, entitlements: EntitlementStore(defaults: defaults))
        let naaste = Naaste(context: context)
        naaste.naam = "Riet"
        let document = Document(context: context)
        document.titel = "Beschikking"
        document.ocrTekst = "Gemeente Utrecht huishoudelijke hulp"
        document.naaste = naaste
        let open = Taak(context: context)
        open.titel = "Bellen"
        open.naaste = naaste
        let klaar = Taak(context: context)
        klaar.titel = "Klaar"
        klaar.afgerond = true
        klaar.naaste = naaste
        _ = VoorbeeldData.maak(in: context)
        try persistence.bewaar()

        let items = app.spotlightItems()
        let ids = Set(items.map(\.uniqueIdentifier))
        #expect(ids == ["document/\(document.uuid!.uuidString)", "taak/\(open.uuid!.uuidString)"])
        let documentItem = try #require(items.first { $0.uniqueIdentifier.hasPrefix("document/") })
        #expect(documentItem.attributeSet.textContent?.contains("huishoudelijke") == true)
        #expect(documentItem.attributeSet.contentDescription?.contains("Riet") == true)
    }

    @Test func agendaItemUitHerinnering() throws {
        let naaste = Naaste(context: context)
        naaste.naam = "Riet"
        let herinnering = Herinnering(context: context)
        herinnering.titel = "Eigen bijdrage CAK"
        herinnering.datum = Calendar.current.date(byAdding: .day, value: 3, to: .now)
        herinnering.heeftTijd = false
        herinnering.herhaling = "perKwartaal"
        herinnering.naaste = naaste

        let item = try #require(AgendaItem(herinnering: herinnering))
        #expect(item.titel == "Eigen bijdrage CAK (Riet)")
        #expect(item.heleDag)
        let regel = try #require(item.herhaalregel)
        #expect(regel.frequency == .monthly && regel.interval == 3)

        let zaak = Zaak(context: context)
        zaak.titel = "Wmo"
        #expect(AgendaItem(vervolgVan: zaak) == nil) // geen vervolgdatum
    }
}
