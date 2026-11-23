import CloudKit
import UIKit

/// Toont het deelscherm van iOS (`UICloudSharingController`): uitnodigen via Berichten
/// of Mail, rechten instellen, iemand verwijderen of stoppen met delen.
///
/// Wordt bovenop het huidige scherm gepresenteerd; in een SwiftUI-sheet werkt deze
/// controller niet betrouwbaar.
@MainActor
final class DeelScherm: NSObject, UICloudSharingControllerDelegate {
    private let titel: String
    private let klaar: (_ gestopt: Bool, _ fout: Error?) -> Void
    /// Zichzelf vasthouden zolang het scherm open is (de controller houdt de delegate zwak vast).
    private var zelf: DeelScherm?

    private init(titel: String, klaar: @escaping (Bool, Error?) -> Void) {
        self.titel = titel
        self.klaar = klaar
    }

    static func toon(share: CKShare, container: CKContainer, titel: String, klaar: @escaping (_ gestopt: Bool, _ fout: Error?) -> Void) {
        let scherm = DeelScherm(titel: titel, klaar: klaar)
        scherm.zelf = scherm
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = scherm
        controller.availablePermissions = [.allowPrivate, .allowReadWrite, .allowReadOnly]
        controller.modalPresentationStyle = .formSheet
        guard let bovenste = Self.bovensteScherm() else {
            scherm.zelf = nil
            return
        }
        bovenste.present(controller, animated: true)
    }

    private static func bovensteScherm() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var scherm = scene?.keyWindow?.rootViewController
        while let volgend = scherm?.presentedViewController { scherm = volgend }
        return scherm
    }

    // MARK: UICloudSharingControllerDelegate

    nonisolated func itemTitle(for csc: UICloudSharingController) -> String? {
        MainActor.assumeIsolated { titel }
    }

    nonisolated func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        MainActor.assumeIsolated {
            klaar(false, error)
        }
    }

    nonisolated func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        MainActor.assumeIsolated {
            klaar(false, nil)
            zelf = nil
        }
    }

    nonisolated func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        MainActor.assumeIsolated {
            klaar(true, nil)
            zelf = nil
        }
    }
}
