// Gegenereerd uit het datamodel (Naaste.xcdatamodeld). Houd attributen en relaties gelijk aan het model.
import CoreData

/// Een dossier/aanvraag, bijv. "Wmo-aanvraag huishoudelijke hulp".
@objc(Zaak)
final class Zaak: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Zaak> {
        NSFetchRequest<Zaak>(entityName: "Zaak")
    }

    @NSManaged var uuid: UUID?
    @NSManaged var aangemaakt: Date?
    @NSManaged var gewijzigd: Date?
    @NSManaged var titel: String?
    @NSManaged var categorie: String?
    @NSManaged var status: String?
    @NSManaged var datumAangevraagd: Date?
    @NSManaged var vervolgdatum: Date?
    @NSManaged var vervolgHerinneren: Bool
    @NSManaged var notities: String?

    @NSManaged var naaste: Naaste?
    @NSManaged var opgepaktDoor: Familielid?
    @NSManaged var documenten: NSSet?
    @NSManaged var gebeurtenissen: NSSet?
    @NSManaged var herinneringen: NSSet?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        let nu = Date()
        setPrimitiveValue(UUID(), forKey: "uuid")
        setPrimitiveValue(nu, forKey: "aangemaakt")
        setPrimitiveValue(nu, forKey: "gewijzigd")
    }
}

extension Zaak {
    var documentenLijst: [Document] { (documenten as? Set<Document>).map(Array.init) ?? [] }
    var gebeurtenissenLijst: [ZaakGebeurtenis] { (gebeurtenissen as? Set<ZaakGebeurtenis>).map(Array.init) ?? [] }
    var herinneringenLijst: [Herinnering] { (herinneringen as? Set<Herinnering>).map(Array.init) ?? [] }
}

// Expliciet nodig: met de huidige SDK conformeert NSManagedObject niet zelf aan Identifiable (id = ObjectIdentifier).
extension Zaak: Identifiable {}
