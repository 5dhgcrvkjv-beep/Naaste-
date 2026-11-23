// Gegenereerd uit het datamodel (Naaste.xcdatamodeld). Houd attributen en relaties gelijk aan het model.
import CoreData

/// Contactpersoon rond de naaste (thuiszorg, gemeente, notaris, …).
@objc(Contactpersoon)
final class Contactpersoon: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Contactpersoon> {
        NSFetchRequest<Contactpersoon>(entityName: "Contactpersoon")
    }

    @NSManaged var uuid: UUID?
    @NSManaged var aangemaakt: Date?
    @NSManaged var gewijzigd: Date?
    @NSManaged var rol: String?
    @NSManaged var naam: String?
    @NSManaged var organisatie: String?
    @NSManaged var telefoon: String?
    @NSManaged var email: String?
    @NSManaged var notitie: String?

    @NSManaged var naaste: Naaste?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        let nu = Date()
        setPrimitiveValue(UUID(), forKey: "uuid")
        setPrimitiveValue(nu, forKey: "aangemaakt")
        setPrimitiveValue(nu, forKey: "gewijzigd")
    }
}

// Expliciet nodig: met de huidige SDK conformeert NSManagedObject niet zelf aan Identifiable (id = ObjectIdentifier).
extension Contactpersoon: Identifiable {}
