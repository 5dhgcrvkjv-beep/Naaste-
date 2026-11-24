import CoreData
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Reservekopie van Naaste (`.naaste`), een binaire property list.
    static let naasteReservekopie = UTType(exportedAs: "nl.naaste.reservekopie", conformingTo: .data)
}

/// Reservekopie van je eigen naasten met alles wat erbij hoort, als één bestand.
///
/// Het formaat volgt het datamodel: per object de entiteit, de `uuid`, alle attributen
/// en de relaties (als lijsten van `uuid`'s). Nieuwe velden in het model gaan zo vanzelf mee.
/// Terugzetten voegt alleen toe wat nog niet op deze iPhone staat (op `uuid`); bestaande
/// gegevens blijven ongewijzigd. Zo kun je een kopie zonder risico twee keer terugzetten.
enum Reservekopie {
    static let formaat = "nl.naaste.reservekopie"
    static let versie = 1

    enum Fout: LocalizedError {
        case onbekendBestand
        case nieuwereVersie

        var errorDescription: String? {
            switch self {
            case .onbekendBestand:
                String(localized: "Dit bestand is geen reservekopie van Naaste.")
            case .nieuwereVersie:
                String(localized: "Deze reservekopie is gemaakt met een nieuwere versie van Naaste. Werk de app bij en probeer het opnieuw.")
            }
        }
    }

    struct Samenvatting: Equatable {
        var naasten = 0
        var documenten = 0
        var overig = 0
        /// Objecten die al op deze iPhone stonden.
        var overgeslagen = 0
    }

    // MARK: Maken

    /// Maakt een reservekopie van alle eigen naasten (niet de voorbeeld-naaste en
    /// niet de naasten die iemand anders met jou deelt).
    static func maak(
        uit context: NSManagedObjectContext,
        opslag: NSPersistentStore?,
        datum: Date = .now
    ) throws -> (data: Data, samenvatting: Samenvatting) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Naaste")
        request.predicate = NSPredicate(format: "isVoorbeeld == NO")
        if let opslag { request.affectedStores = [opslag] }
        let naasten = try context.fetch(request)

        // Alles wat vanaf de naasten bereikbaar is.
        var gezien = Set<NSManagedObjectID>()
        var wachtrij: [NSManagedObject] = naasten
        var objecten: [NSManagedObject] = []
        while let object = wachtrij.popLast() {
            guard gezien.insert(object.objectID).inserted else { continue }
            objecten.append(object)
            for (naam, relatie) in object.entity.relationshipsByName {
                if relatie.isToMany {
                    let doelen = (object.value(forKey: naam) as? Set<NSManagedObject>) ?? []
                    wachtrij.append(contentsOf: doelen)
                } else if let doel = object.value(forKey: naam) as? NSManagedObject {
                    wachtrij.append(doel)
                }
            }
        }

        var samenvatting = Samenvatting()
        let lijst: [[String: Any]] = objecten.compactMap { object in
            guard let entiteit = object.entity.name, let uuid = object.value(forKey: "uuid") as? UUID else { return nil }
            switch entiteit {
            case "Naaste": samenvatting.naasten += 1
            case "Document": samenvatting.documenten += 1
            default: samenvatting.overig += 1
            }

            var attributen: [String: Any] = [:]
            for (naam, attribuut) in object.entity.attributesByName {
                guard let waarde = object.value(forKey: naam) else { continue }
                if attribuut.attributeType == .UUIDAttributeType, let id = waarde as? UUID {
                    attributen[naam] = id.uuidString
                } else if attribuut.attributeType == .URIAttributeType, let url = waarde as? URL {
                    attributen[naam] = url.absoluteString
                } else if PropertyListSerialization.propertyList(waarde, isValidFor: .binary) {
                    attributen[naam] = waarde
                }
            }

            var relaties: [String: [String]] = [:]
            for (naam, relatie) in object.entity.relationshipsByName {
                let doelen: [NSManagedObject] = relatie.isToMany
                    ? Array((object.value(forKey: naam) as? Set<NSManagedObject>) ?? [])
                    : [object.value(forKey: naam) as? NSManagedObject].compactMap { $0 }
                let ids = doelen.compactMap { ($0.value(forKey: "uuid") as? UUID)?.uuidString }
                if !ids.isEmpty { relaties[naam] = ids.sorted() }
            }

            return ["entiteit": entiteit, "uuid": uuid.uuidString, "attributen": attributen, "relaties": relaties]
        }

        let bestand: [String: Any] = ["formaat": formaat, "versie": versie, "gemaakt": datum, "objecten": lijst]
        let data = try PropertyListSerialization.data(fromPropertyList: bestand, format: .binary, options: 0)
        return (data, samenvatting)
    }

    static func bestandsnaam(datum: Date = .now) -> String {
        let dag = datum.formatted(.iso8601.year().month().day())
        return "Naaste-reservekopie-\(dag)"
    }

    // MARK: Terugzetten

    /// Zet een reservekopie terug in `opslag` (de eigen, privé-opslag). Slaat nog niet op.
    static func zetTerug(
        _ data: Data,
        in context: NSManagedObjectContext,
        opslag: NSPersistentStore?
    ) throws -> Samenvatting {
        guard let bestand = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              bestand["formaat"] as? String == formaat,
              let objecten = bestand["objecten"] as? [[String: Any]] else {
            throw Fout.onbekendBestand
        }
        guard (bestand["versie"] as? Int ?? 0) <= versie else { throw Fout.nieuwereVersie }
        let entiteiten = context.persistentStoreCoordinator?.managedObjectModel.entitiesByName ?? [:]

        // 1. Objecten maken (of de bestaande vinden).
        var samenvatting = Samenvatting()
        var perID: [String: NSManagedObject] = [:]
        var nieuw = Set<String>()
        for item in objecten {
            guard let naam = item["entiteit"] as? String, let beschrijving = entiteiten[naam],
                  let idTekst = item["uuid"] as? String, let uuid = UUID(uuidString: idTekst) else { continue }
            let sleutel = "\(naam)/\(idTekst)"

            let zoek = NSFetchRequest<NSManagedObject>(entityName: naam)
            zoek.predicate = NSPredicate(format: "uuid == %@", uuid as CVarArg)
            zoek.fetchLimit = 1
            if let opslag { zoek.affectedStores = [opslag] }
            if let bestaand = try context.fetch(zoek).first {
                perID[sleutel] = bestaand
                samenvatting.overgeslagen += 1
                continue
            }

            let object = NSManagedObject(entity: beschrijving, insertInto: context)
            if let opslag { context.assign(object, to: opslag) }
            let attributen = item["attributen"] as? [String: Any] ?? [:]
            for (attribuutNaam, attribuut) in beschrijving.attributesByName {
                guard let waarde = attributen[attribuutNaam] else { continue }
                switch attribuut.attributeType {
                case .UUIDAttributeType:
                    object.setValue((waarde as? String).flatMap(UUID.init(uuidString:)), forKey: attribuutNaam)
                case .URIAttributeType:
                    object.setValue((waarde as? String).flatMap(URL.init(string:)), forKey: attribuutNaam)
                default:
                    object.setValue(waarde, forKey: attribuutNaam)
                }
            }
            perID[sleutel] = object
            nieuw.insert(sleutel)
            switch naam {
            case "Naaste": samenvatting.naasten += 1
            case "Document": samenvatting.documenten += 1
            default: samenvatting.overig += 1
            }
        }

        // 2. Relaties leggen, alleen vanuit nieuwe objecten (bestaande blijven zoals ze zijn).
        for item in objecten {
            guard let naam = item["entiteit"] as? String, let idTekst = item["uuid"] as? String,
                  nieuw.contains("\(naam)/\(idTekst)"), let object = perID["\(naam)/\(idTekst)"] else { continue }
            let relaties = item["relaties"] as? [String: [String]] ?? [:]
            for (relatieNaam, relatie) in object.entity.relationshipsByName {
                guard let doelNaam = relatie.destinationEntity?.name, let ids = relaties[relatieNaam] else { continue }
                let doelen = ids.compactMap { perID["\(doelNaam)/\($0)"] }
                if relatie.isToMany {
                    object.mutableSetValue(forKey: relatieNaam).addObjects(from: doelen)
                } else {
                    object.setValue(doelen.first, forKey: relatieNaam)
                }
            }
        }
        return samenvatting
    }
}

/// Voor `fileExporter`.
struct ReservekopieBestand: FileDocument {
    static let readableContentTypes: [UTType] = [.naasteReservekopie]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
