import CoreData
import CoreSpotlight
import UniformTypeIdentifiers

/// Documenten, zaken en open taken vindbaar via Spotlight (zoeken op het beginscherm).
///
/// De index staat alleen op deze iPhone. De voorbeeld-naaste doet niet mee. Staat de
/// Face ID-vergrendeling aan, dan wordt niets geïndexeerd: anders zou je titels en
/// tekst kunnen zien zonder te ontgrendelen.
extension AppModel {
    static let spotlightDomein = "nl.naaste"

    /// Bouwt de index opnieuw op, even na de laatste wijziging (zodat snel typen niet steeds indexeert).
    func werkSpotlightBij() {
        guard !persistence.isInMemory else { return }
        spotlightTaak?.cancel()
        spotlightTaak = Task { [self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            let items = Vergrendeling.shared.aan ? [] : spotlightItems()
            let index = CSSearchableIndex.default()
            try? await index.deleteSearchableItems(withDomainIdentifiers: [Self.spotlightDomein])
            guard !items.isEmpty, !Task.isCancelled else { return }
            try? await index.indexSearchableItems(items)
        }
    }

    func spotlightItems() -> [CSSearchableItem] {
        let echt = NSPredicate(format: "naaste != nil AND naaste.isVoorbeeld == NO")
        var items: [CSSearchableItem] = []

        let documenten = NSFetchRequest<Document>(entityName: "Document")
        documenten.predicate = echt
        for document in (try? context.fetch(documenten)) ?? [] {
            guard let uuid = document.uuid else { continue }
            let set = CSSearchableItemAttributeSet(contentType: .pdf)
            set.title = document.weergaveTitel
            set.contentDescription = [
                document.categorieWaarde.titel,
                document.naaste?.weergaveNaam,
                document.documentDatum?.formatted(date: .long, time: .omitted)
            ].compactMap { $0 }.joined(separator: " · ")
            set.textContent = document.ocrTekst
            set.thumbnailData = document.miniatuur
            set.contentCreationDate = document.documentDatum ?? document.aangemaakt
            items.append(item("document", uuid, set))
        }

        let zaken = NSFetchRequest<Zaak>(entityName: "Zaak")
        zaken.predicate = echt
        for zaak in (try? context.fetch(zaken)) ?? [] {
            guard let uuid = zaak.uuid else { continue }
            let set = CSSearchableItemAttributeSet(contentType: .text)
            set.title = zaak.weergaveTitel
            set.contentDescription = [
                String(localized: "Zaak"),
                zaak.statusWaarde.titel,
                zaak.naaste?.weergaveNaam
            ].compactMap { $0 }.joined(separator: " · ")
            set.textContent = zaak.notities
            items.append(item("zaak", uuid, set))
        }

        let taken = NSFetchRequest<Taak>(entityName: "Taak")
        taken.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [echt, NSPredicate(format: "afgerond == NO")])
        for taak in (try? context.fetch(taken)) ?? [] {
            guard let uuid = taak.uuid else { continue }
            let set = CSSearchableItemAttributeSet(contentType: .text)
            set.title = taak.weergaveTitel
            set.contentDescription = [
                String(localized: "Taak"),
                taak.naaste?.weergaveNaam,
                taak.deadline.map { String(localized: "uiterlijk \($0.formatted(date: .abbreviated, time: .omitted))") }
            ].compactMap { $0 }.joined(separator: " · ")
            set.textContent = taak.notitie
            items.append(item("taak", uuid, set))
        }
        return items
    }

    private func item(_ soort: String, _ uuid: UUID, _ set: CSSearchableItemAttributeSet) -> CSSearchableItem {
        CSSearchableItem(uniqueIdentifier: "\(soort)/\(uuid.uuidString)", domainIdentifier: Self.spotlightDomein, attributeSet: set)
    }
}
