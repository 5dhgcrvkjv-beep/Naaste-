// Gegenereerd uit het datamodel (Naaste.xcdatamodeld). Houd attributen en relaties gelijk aan het model.
import CoreData

/// Bestede mantelzorg-tijd.
@objc(Urenregel)
final class Urenregel: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Urenregel> {
        NSFetchRequest<Urenregel>(entityName: "Urenregel")
    }

    @NSManaged var uuid: UUID?
    @NSManaged var aangemaakt: Date?
    @NSManaged var gewijzigd: Date?
    @NSManaged var datum: Date?
    @NSManaged var minuten: Int32
    @NSManaged var categorie: String?
    @NSManaged var omschrijving: String?

    @NSManaged var naaste: Naaste?
    @NSManaged var familielid: Familielid?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        let nu = Date()
        setPrimitiveValue(UUID(), forKey: "uuid")
        setPrimitiveValue(nu, forKey: "aangemaakt")
        setPrimitiveValue(nu, forKey: "gewijzigd")
    }
}

// Expliciet nodig: met de huidige SDK conformeert NSManagedObject niet zelf aan Identifiable (id = ObjectIdentifier).
extension Urenregel: Identifiable {}
