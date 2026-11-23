// Gegenereerd uit het datamodel (Naaste.xcdatamodeld). Houd attributen en relaties gelijk aan het model.
import CoreData

/// De persoon voor wie de familie zorgt.
@objc(Naaste)
final class Naaste: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Naaste> {
        NSFetchRequest<Naaste>(entityName: "Naaste")
    }

    @NSManaged var uuid: UUID?
    @NSManaged var aangemaakt: Date?
    @NSManaged var gewijzigd: Date?
    @NSManaged var naam: String?
    @NSManaged var geboortedatum: Date?
    @NSManaged var straat: String?
    @NSManaged var postcode: String?
    @NSManaged var plaats: String?
    @NSManaged var telefoon: String?
    @NSManaged var huisartsNaam: String?
    @NSManaged var huisartsTelefoon: String?
    @NSManaged var zorgverzekeraar: String?
    @NSManaged var polisnummer: String?
    @NSManaged var verzekeraarTelefoon: String?
    @NSManaged var medicatieNotitie: String?
    @NSManaged var notities: String?
    @NSManaged var isVoorbeeld: Bool
    @NSManaged var eigenaarHeeftPlus: Bool

    @NSManaged var contacten: NSSet?
    @NSManaged var documenten: NSSet?
    @NSManaged var zaken: NSSet?
    @NSManaged var taken: NSSet?
    @NSManaged var urenregels: NSSet?
    @NSManaged var herinneringen: NSSet?
    @NSManaged var familieleden: NSSet?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        let nu = Date()
        setPrimitiveValue(UUID(), forKey: "uuid")
        setPrimitiveValue(nu, forKey: "aangemaakt")
        setPrimitiveValue(nu, forKey: "gewijzigd")
    }
}

extension Naaste {
    var contactenLijst: [Contactpersoon] { (contacten as? Set<Contactpersoon>).map(Array.init) ?? [] }
    var documentenLijst: [Document] { (documenten as? Set<Document>).map(Array.init) ?? [] }
    var zakenLijst: [Zaak] { (zaken as? Set<Zaak>).map(Array.init) ?? [] }
    var takenLijst: [Taak] { (taken as? Set<Taak>).map(Array.init) ?? [] }
    var urenregelsLijst: [Urenregel] { (urenregels as? Set<Urenregel>).map(Array.init) ?? [] }
    var herinneringenLijst: [Herinnering] { (herinneringen as? Set<Herinnering>).map(Array.init) ?? [] }
    var familieledenLijst: [Familielid] { (familieleden as? Set<Familielid>).map(Array.init) ?? [] }
}

// Expliciet nodig: met de huidige SDK conformeert NSManagedObject niet zelf aan Identifiable (id = ObjectIdentifier).
extension Naaste: Identifiable {}
