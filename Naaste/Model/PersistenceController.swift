import CloudKit
import CoreData
import os

/// Core Data + CloudKit.
///
/// Twee opslagen met hetzelfde model:
/// - `prive.sqlite`  ↔ de privé-database in de iCloud van de gebruiker (eigen naasten)
/// - `gedeeld.sqlite` ↔ de gedeelde database (naasten die iemand anders met jou deelt)
///
/// Er is geen eigen server: alle gegevens staan op het toestel en in iCloud van de gebruikers.
final class PersistenceController {
    static let shared = PersistenceController()
    static let cloudKitContainerID = "iCloud.nl.naaste.app"

    /// `true` in de configuratie "Lokaal" (testversie voor een gratis Apple ID, zonder iCloud-rechten).
    static var zonderICloud: Bool {
        #if LOKAAL
        true
        #else
        false
        #endif
    }

    /// Het model wordt één keer geladen. Meerdere modellen met dezelfde klassen
    /// (bijv. in tests) geven anders "ambiguous entity"-fouten.
    static let model: NSManagedObjectModel = {
        guard let url = Bundle.main.url(forResource: "Naaste", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Datamodel Naaste.momd ontbreekt in de app-bundel.")
        }
        return model
    }()

    let container: NSPersistentCloudKitContainer
    let isInMemory: Bool
    private(set) var privateStore: NSPersistentStore?
    private(set) var sharedStore: NSPersistentStore?
    /// Gevuld als een opslag niet geladen kon worden; de app toont dan een foutscherm.
    private(set) var laadFout: Error?

    private let log = Logger(subsystem: "nl.naaste.app", category: "Opslag")

    var viewContext: NSManagedObjectContext { container.viewContext }

    /// - Parameter inMemory: voor tests en previews. Synchroniseert niet met iCloud.
    init(inMemory: Bool = false) {
        isInMemory = inMemory
        container = NSPersistentCloudKitContainer(name: "Naaste", managedObjectModel: Self.model)

        if inMemory {
            let beschrijving = NSPersistentStoreDescription()
            beschrijving.type = NSInMemoryStoreType
            beschrijving.url = URL(fileURLWithPath: "/dev/null")
            beschrijving.cloudKitContainerOptions = nil
            container.persistentStoreDescriptions = [beschrijving]
        } else if Self.zonderICloud {
            // Testversie zonder iCloud (gratis Apple ID): alleen lokale opslag, geen synchronisatie.
            let beschrijving = NSPersistentStoreDescription(url: NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("prive.sqlite"))
            beschrijving.cloudKitContainerOptions = nil
            beschrijving.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            beschrijving.shouldMigrateStoreAutomatically = true
            beschrijving.shouldInferMappingModelAutomatically = true
            container.persistentStoreDescriptions = [beschrijving]
        } else {
            let map = NSPersistentContainer.defaultDirectoryURL()
            container.persistentStoreDescriptions = [
                Self.beschrijving(url: map.appendingPathComponent("prive.sqlite"), scope: .private),
                Self.beschrijving(url: map.appendingPathComponent("gedeeld.sqlite"), scope: .shared)
            ]
        }

        container.loadPersistentStores { [weak self] beschrijving, fout in
            guard let self else { return }
            if let fout {
                self.log.error("Opslag laden mislukt: \(fout.localizedDescription, privacy: .public)")
                self.laadFout = fout
                return
            }
            guard let url = beschrijving.url,
                  let store = self.container.persistentStoreCoordinator.persistentStore(for: url) else { return }
            if beschrijving.cloudKitContainerOptions?.databaseScope == .shared {
                self.sharedStore = store
            } else {
                self.privateStore = store
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = "app"
        container.viewContext.name = "viewContext"
    }

    private static func beschrijving(url: URL, scope: CKDatabase.Scope) -> NSPersistentStoreDescription {
        let beschrijving = NSPersistentStoreDescription(url: url)
        let opties = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerID)
        opties.databaseScope = scope
        beschrijving.cloudKitContainerOptions = opties
        beschrijving.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        beschrijving.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        beschrijving.shouldMigrateStoreAutomatically = true
        beschrijving.shouldInferMappingModelAutomatically = true
        return beschrijving
    }

    #if DEBUG
    /// Zet alle recordtypen en velden uit het datamodel in de Development-omgeving van CloudKit.
    /// Zonder dit kent CloudKit alleen velden die ooit zijn ingevuld. Start met `-maakICloudSchema`
    /// op een toestel met iCloud; daarna in de CloudKit Console naar Production zetten.
    func maakICloudSchema() {
        guard !isInMemory, !Self.zonderICloud else { return }
        let container = container
        Task.detached {
            print("ICLOUDSCHEMA start")
            do {
                try container.initializeCloudKitSchema(options: [])
                print("ICLOUDSCHEMA klaar")
                await Self.controleerICloudSchema()
            } catch {
                print("ICLOUDSCHEMA fout: \(error)")
            }
        }
    }

    /// Vraagt CloudKit per recordtype of het bestaat. "Not queryable" betekent: bestaat, zonder index.
    private static func controleerICloudSchema() async {
        let ck = CKContainer(identifier: cloudKitContainerID)
        do { print("ICLOUDSCHEMA account \(try await ck.accountStatus().rawValue) (1 = beschikbaar)") } catch { print("ICLOUDSCHEMA account fout \(error)") }
        do {
            let zones = try await ck.privateCloudDatabase.allRecordZones()
            print("ICLOUDSCHEMA zones \(zones.map(\.zoneID.zoneName))")
        } catch { print("ICLOUDSCHEMA zones fout \(error)") }
        let zone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        for naam in model.entities.compactMap(\.name).sorted() + ["Bestaat_Niet"] {
            let type = naam == "Bestaat_Niet" ? naam : "CD_\(naam)"
            do {
                let (treffers, _) = try await ck.privateCloudDatabase.records(matching: CKQuery(recordType: type, predicate: NSPredicate(value: true)), inZoneWith: zone, resultsLimit: 1)
                print("ICLOUDSCHEMA \(type): bestaat (\(treffers.count) gevonden)")
            } catch let fout as CKError {
                print("ICLOUDSCHEMA \(type): code \(fout.code.rawValue) \(fout.localizedDescription)")
            } catch { print("ICLOUDSCHEMA \(type): \(error)") }
        }
        print("ICLOUDSCHEMA controle klaar")
    }
    #endif

    // MARK: - Opslaan

    /// Slaat wijzigingen op; bij een fout worden de wijzigingen teruggedraaid.
    func bewaar(_ context: NSManagedObjectContext? = nil) throws {
        let context = context ?? viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            log.error("Opslaan mislukt: \(error.localizedDescription, privacy: .public)")
            context.rollback()
            throw error
        }
    }

    // MARK: - Opslagen

    /// `true` als het object in de gedeelde opslag staat (iemand anders is eigenaar).
    func staatInGedeeldeOpslag(_ object: NSManagedObject) -> Bool {
        guard let sharedStore, let store = object.objectID.persistentStore else { return false }
        return store == sharedStore
    }
}

extension NSManagedObjectContext {
    /// Maakt een nieuw object in dezelfde opslag als `ouder` (bijv. de naaste).
    /// Nodig voor gedeelde naasten: nieuwe documenten, taken enz. moeten in de gedeelde
    /// opslag komen, anders ziet de rest van de familie ze niet.
    func maak<T: NSManagedObject>(_ type: T.Type, bij ouder: NSManagedObject?) -> T {
        let entiteit = T.entity().name ?? String(describing: T.self)
        guard let object = NSEntityDescription.insertNewObject(forEntityName: entiteit, into: self) as? T else {
            fatalError("Entiteit \(entiteit) hoort bij klasse \(T.self).")
        }
        if let store = ouder?.objectID.persistentStore, !(ouder?.objectID.isTemporaryID ?? true) {
            assign(object, to: store)
        }
        return object
    }
}
