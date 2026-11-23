import CoreData
import Foundation

// Fetch requests op één plek, zodat views en tests dezelfde definitie gebruiken.

extension Naaste {
    static func alle() -> NSFetchRequest<Naaste> {
        let request = Naaste.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "isVoorbeeld", ascending: true),
            NSSortDescriptor(key: "aangemaakt", ascending: true)
        ]
        return request
    }
}

extension Herinnering {
    static func open(voor naaste: Naaste) -> NSFetchRequest<Herinnering> {
        let request = Herinnering.fetchRequest()
        request.predicate = NSPredicate(format: "naaste == %@ AND afgerond == NO", naaste)
        request.sortDescriptors = [NSSortDescriptor(key: "datum", ascending: true)]
        return request
    }

    static func alleOpen() -> NSFetchRequest<Herinnering> {
        let request = Herinnering.fetchRequest()
        request.predicate = NSPredicate(format: "afgerond == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "datum", ascending: true)]
        return request
    }
}

extension Zaak {
    static func alle(voor naaste: Naaste) -> NSFetchRequest<Zaak> {
        let request = Zaak.fetchRequest()
        request.predicate = NSPredicate(format: "naaste == %@", naaste)
        request.sortDescriptors = [NSSortDescriptor(key: "aangemaakt", ascending: false)]
        return request
    }

    static func metVervolgHerinnering() -> NSFetchRequest<Zaak> {
        let request = Zaak.fetchRequest()
        request.predicate = NSPredicate(format: "vervolgHerinneren == YES AND vervolgdatum != nil AND status != %@", "afgerond")
        return request
    }
}

extension Taak {
    static func alle(voor naaste: Naaste) -> NSFetchRequest<Taak> {
        let request = Taak.fetchRequest()
        request.predicate = NSPredicate(format: "naaste == %@", naaste)
        request.sortDescriptors = [
            NSSortDescriptor(key: "afgerond", ascending: true),
            NSSortDescriptor(key: "aangemaakt", ascending: true)
        ]
        return request
    }
}

extension Document {
    static func alle(voor naaste: Naaste) -> NSFetchRequest<Document> {
        let request = Document.fetchRequest()
        request.predicate = NSPredicate(format: "naaste == %@", naaste)
        request.sortDescriptors = [
            NSSortDescriptor(key: "documentDatum", ascending: false),
            NSSortDescriptor(key: "aangemaakt", ascending: false)
        ]
        return request
    }
}

extension Urenregel {
    static func alle(voor naaste: Naaste) -> NSFetchRequest<Urenregel> {
        let request = Urenregel.fetchRequest()
        request.predicate = NSPredicate(format: "naaste == %@", naaste)
        request.sortDescriptors = [NSSortDescriptor(key: "datum", ascending: false)]
        return request
    }
}

extension PersistenceController {
    /// Eigen naasten (privé-opslag), zonder de voorbeeld-naaste. Telt voor de gratis limiet.
    func aantalEigenNaasten(in context: NSManagedObjectContext? = nil) -> Int {
        let request = Naaste.fetchRequest()
        request.predicate = NSPredicate(format: "isVoorbeeld == NO")
        if let privateStore { request.affectedStores = [privateStore] }
        return (try? (context ?? viewContext).count(for: request)) ?? 0
    }

    /// Documenten bij eigen naasten (privé-opslag), zonder voorbeeld. Telt voor de gratis limiet.
    func aantalEigenDocumenten(in context: NSManagedObjectContext? = nil) -> Int {
        let request = Document.fetchRequest()
        request.predicate = NSPredicate(format: "naaste.isVoorbeeld == NO")
        if let privateStore { request.affectedStores = [privateStore] }
        return (try? (context ?? viewContext).count(for: request)) ?? 0
    }

    func aantalDocumenten(van naaste: Naaste) -> Int {
        let request = Document.fetchRequest()
        request.predicate = NSPredicate(format: "naaste == %@", naaste)
        return (try? viewContext.count(for: request)) ?? 0
    }

    func voorbeeldNaasten(in context: NSManagedObjectContext? = nil) -> [Naaste] {
        let request = Naaste.fetchRequest()
        request.predicate = NSPredicate(format: "isVoorbeeld == YES")
        return (try? (context ?? viewContext).fetch(request)) ?? []
    }
}

extension Zaak {
    static func lopend(voor naaste: Naaste) -> NSFetchRequest<Zaak> {
        let request = Zaak.fetchRequest()
        request.predicate = NSPredicate(format: "naaste == %@ AND status != %@", naaste, "afgerond")
        request.sortDescriptors = [NSSortDescriptor(key: "vervolgdatum", ascending: true)]
        return request
    }
}

extension Taak {
    static func open(voor naaste: Naaste) -> NSFetchRequest<Taak> {
        let request = Taak.fetchRequest()
        request.predicate = NSPredicate(format: "naaste == %@ AND afgerond == NO", naaste)
        request.sortDescriptors = [NSSortDescriptor(key: "aangemaakt", ascending: true)]
        return request
    }
}

extension Contactpersoon {
    static func alle(voor naaste: Naaste) -> NSFetchRequest<Contactpersoon> {
        let request = Contactpersoon.fetchRequest()
        request.predicate = NSPredicate(format: "naaste == %@", naaste)
        request.sortDescriptors = [NSSortDescriptor(key: "naam", ascending: true)]
        return request
    }
}

extension Familielid {
    static func alle(voor naaste: Naaste) -> NSFetchRequest<Familielid> {
        let request = Familielid.fetchRequest()
        request.predicate = NSPredicate(format: "naaste == %@", naaste)
        request.sortDescriptors = [NSSortDescriptor(key: "naam", ascending: true)]
        return request
    }
}
