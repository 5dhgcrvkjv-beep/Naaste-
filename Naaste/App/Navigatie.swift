import CoreData
import SwiftUI
import UIKit

/// Waar de app naartoe moet springen, bijvoorbeeld na een tik op een Spotlight-resultaat
/// of een snelle actie op het app-icoon. Het scherm dat de bestemming afhandelt, zet
/// `open` daarna weer op `nil`.
@MainActor
@Observable
final class Navigatie {
    static let shared = Navigatie()

    enum Bestemming: Equatable {
        case document(UUID)
        case zaak(UUID)
        case taak(UUID)
        /// Snelle acties
        case scan
        case nieuweTaak
        case uren
    }

    var open: Bestemming?
    /// Bewaard zolang de app vergrendeld is; zo opent bijvoorbeeld de scanner pas na Face ID.
    private(set) var uitgesteld: Bestemming?
    /// Te vervangen in tests.
    @ObservationIgnored var isVergrendeld: () -> Bool = { Vergrendeling.shared.vergrendeld }

    func ga(naar bestemming: Bestemming) {
        if isVergrendeld() {
            uitgesteld = bestemming
        } else {
            open = bestemming
        }
    }

    /// Na ontgrendelen: alsnog naar de bewaarde bestemming.
    func gaVerderNaOntgrendelen() {
        guard let uitgesteld else { return }
        self.uitgesteld = nil
        open = uitgesteld
    }

    // MARK: Snelle acties (lang drukken op het app-icoon, zie Info.plist)

    enum Snelkoppeling: String {
        case scan = "nl.naaste.scan"
        case taak = "nl.naaste.taak"
        case uren = "nl.naaste.uren"

        var bestemming: Bestemming {
            switch self {
            case .scan: .scan
            case .taak: .nieuweTaak
            case .uren: .uren
            }
        }
    }

    /// `true` als het een snelle actie van Naaste was.
    @discardableResult
    func voerUit(_ item: UIApplicationShortcutItem) -> Bool {
        guard let snelkoppeling = Snelkoppeling(rawValue: item.type) else { return false }
        ga(naar: snelkoppeling.bestemming)
        return true
    }

    // MARK: Spotlight

    /// Spotlight-ID's hebben de vorm `document/<uuid>`, `zaak/<uuid>` of `taak/<uuid>`.
    func open(spotlightID: String) {
        let delen = spotlightID.split(separator: "/", maxSplits: 1).map(String.init)
        guard delen.count == 2, let uuid = UUID(uuidString: delen[1]) else { return }
        switch delen[0] {
        case "document": ga(naar: .document(uuid))
        case "zaak": ga(naar: .zaak(uuid))
        case "taak": ga(naar: .taak(uuid))
        default: break
        }
    }

    /// Zoekt het object bij een bestemming (alle opslagen, ook gedeeld).
    static func zoek<T: NSManagedObject>(_ type: T.Type, uuid: UUID, in context: NSManagedObjectContext) -> T? {
        let request = NSFetchRequest<T>(entityName: T.entity().name ?? String(describing: T.self))
        request.predicate = NSPredicate(format: "uuid == %@", uuid as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
