// Gegenereerd uit het datamodel (Naaste.xcdatamodeld). Houd attributen en relaties gelijk aan het model.
import CoreData

/// Iemand uit de familie die meehelpt. Alleen een naamkaartje, geen account.
@objc(Familielid)
final class Familielid: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Familielid> {
        NSFetchRequest<Familielid>(entityName: "Familielid")
    }

    @NSManaged var uuid: UUID?
    @NSManaged var aangemaakt: Date?
    @NSManaged var gewijzigd: Date?
    @NSManaged var naam: String?
    @NSManaged var kleur: String?

    @NSManaged var naaste: Naaste?
    @NSManaged var taken: NSSet?
    @NSManaged var urenregels: NSSet?
    @NSManaged var zaken: NSSet?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        let nu = Date()
        setPrimitiveValue(UUID(), forKey: "uuid")
        setPrimitiveValue(nu, forKey: "aangemaakt")
        setPrimitiveValue(nu, forKey: "gewijzigd")
    }
}

extension Familielid {
    var takenLijst: [Taak] { (taken as? Set<Taak>).map(Array.init) ?? [] }
    var urenregelsLijst: [Urenregel] { (urenregels as? Set<Urenregel>).map(Array.init) ?? [] }
    var zakenLijst: [Zaak] { (zaken as? Set<Zaak>).map(Array.init) ?? [] }
}

// Expliciet nodig: met de huidige SDK conformeert NSManagedObject niet zelf aan Identifiable (id = ObjectIdentifier).
extension Familielid: Identifiable {}
