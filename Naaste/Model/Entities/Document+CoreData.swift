// Gegenereerd uit het datamodel (Naaste.xcdatamodeld). Houd attributen en relaties gelijk aan het model.
import CoreData

/// Een gescand of geïmporteerd document (PDF) in de kluis.
@objc(Document)
final class Document: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Document> {
        NSFetchRequest<Document>(entityName: "Document")
    }

    @NSManaged var uuid: UUID?
    @NSManaged var aangemaakt: Date?
    @NSManaged var gewijzigd: Date?
    @NSManaged var titel: String?
    @NSManaged var categorie: String?
    @NSManaged var documentDatum: Date?
    @NSManaged var bestand: Data?
    @NSManaged var bestandsnaam: String?
    @NSManaged var paginas: Int16
    @NSManaged var ocrTekst: String?
    @NSManaged var ocrStatus: String?
    @NSManaged var miniatuur: Data?

    @NSManaged var naaste: Naaste?
    @NSManaged var zaken: NSSet?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        let nu = Date()
        setPrimitiveValue(UUID(), forKey: "uuid")
        setPrimitiveValue(nu, forKey: "aangemaakt")
        setPrimitiveValue(nu, forKey: "gewijzigd")
    }
}

extension Document {
    var zakenLijst: [Zaak] { (zaken as? Set<Zaak>).map(Array.init) ?? [] }
}
