// Gegenereerd uit het datamodel (Naaste.xcdatamodeld). Houd attributen en relaties gelijk aan het model.
import CoreData

/// Eén regel in de tijdlijn van een zaak.
@objc(ZaakGebeurtenis)
final class ZaakGebeurtenis: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ZaakGebeurtenis> {
        NSFetchRequest<ZaakGebeurtenis>(entityName: "ZaakGebeurtenis")
    }

    @NSManaged var uuid: UUID?
    @NSManaged var aangemaakt: Date?
    @NSManaged var gewijzigd: Date?
    @NSManaged var datum: Date?
    @NSManaged var soort: String?
    @NSManaged var tekst: String?
    @NSManaged var nieuweStatus: String?
    @NSManaged var auteur: String?

    @NSManaged var zaak: Zaak?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        let nu = Date()
        setPrimitiveValue(UUID(), forKey: "uuid")
        setPrimitiveValue(nu, forKey: "aangemaakt")
        setPrimitiveValue(nu, forKey: "gewijzigd")
    }
}

// Expliciet nodig: met de huidige SDK conformeert NSManagedObject niet zelf aan Identifiable (id = ObjectIdentifier).
extension ZaakGebeurtenis: Identifiable {}
