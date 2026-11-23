// Gegenereerd uit het datamodel (Naaste.xcdatamodeld). Houd attributen en relaties gelijk aan het model.
import CoreData

/// Een taak, eventueel toegewezen aan een familielid.
@objc(Taak)
final class Taak: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Taak> {
        NSFetchRequest<Taak>(entityName: "Taak")
    }

    @NSManaged var uuid: UUID?
    @NSManaged var aangemaakt: Date?
    @NSManaged var gewijzigd: Date?
    @NSManaged var titel: String?
    @NSManaged var notitie: String?
    @NSManaged var deadline: Date?
    @NSManaged var afgerond: Bool
    @NSManaged var afgerondOp: Date?
    @NSManaged var volgorde: Double

    @NSManaged var naaste: Naaste?
    @NSManaged var toegewezenAan: Familielid?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        let nu = Date()
        setPrimitiveValue(UUID(), forKey: "uuid")
        setPrimitiveValue(nu, forKey: "aangemaakt")
        setPrimitiveValue(nu, forKey: "gewijzigd")
    }
}

// Expliciet nodig: met de huidige SDK conformeert NSManagedObject niet zelf aan Identifiable (id = ObjectIdentifier).
extension Taak: Identifiable {}
