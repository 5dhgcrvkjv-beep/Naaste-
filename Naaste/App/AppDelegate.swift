import CloudKit
import UIKit

extension Notification.Name {
    /// Een uitnodiging om een naaste te delen is geaccepteerd. `object` is de titel van de share.
    static let deelUitnodigingGeaccepteerd = Notification.Name("deelUitnodigingGeaccepteerd")
    /// Accepteren mislukte. `object` is de fout.
    static let deelUitnodigingMislukt = Notification.Name("deelUitnodigingMislukt")
}

/// Nodig om CloudKit-uitnodigingen te ontvangen: iOS meldt die aan de scene-delegate.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuratie = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuratie.delegateClass = SceneDelegate.self
        return configuratie
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    /// Uitnodiging geopend terwijl de app nog niet draaide.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            MainActor.assumeIsolated { Vergrendeling.shared.koppel(windowScene) }
        }
        if let metadata = connectionOptions.cloudKitShareMetadata {
            accepteer(metadata)
        }
    }

    /// Uitnodiging geopend terwijl de app al draaide.
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        accepteer(cloudKitShareMetadata)
    }

    private func accepteer(_ metadata: CKShare.Metadata) {
        let titel = metadata.share[CKShare.SystemFieldKey.title] as? String
        Task { @MainActor in
            do {
                try await Delen(persistence: .shared).accepteer(metadata)
                NotificationCenter.default.post(name: .deelUitnodigingGeaccepteerd, object: titel)
            } catch {
                NotificationCenter.default.post(name: .deelUitnodigingMislukt, object: error)
            }
        }
    }
}
