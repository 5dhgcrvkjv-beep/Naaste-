// Gegenereerd uit het datamodel (Naaste.xcdatamodeld). Houd attributen en relaties gelijk aan het model.
import CoreData

/// Deadline of herinnering (herindicatie, verlenging, betaling, afspraak).
@objc(Herinnering)
final class Herinnering: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Herinnering> {
        NSFetchRequest<Herinnering>(entityName: "Herinnering")
    }

    @NSManaged var uuid: UUID?
    @NSManaged var aangemaakt: Date?
    @NSManaged var gewijzigd: Date?
    @NSManaged var titel: String?
    @NSManaged var datum: Date?
    @NSManaged var heeftTijd: Bool
    @NSManaged var soort: String?
    @NSManaged var herhaling: String?
    @NSManaged var dagenVooraf: Int16
    @NSManaged var afgerond: Bool
    @NSManaged var notitie: String?

    @NSManaged var naaste: Naaste?
    @NSManaged var zaak: Zaak?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        let nu = Date()
        setPrimitiveValue(UUID(), forKey: "uuid")
        setPrimitiveValue(nu, forKey: "aangemaakt")
        setPrimitiveValue(nu, forKey: "gewijzigd")
    }
}
