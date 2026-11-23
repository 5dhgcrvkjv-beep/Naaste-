import SwiftUI
import VisionKit

/// De documentscanner van iOS (randen herkennen, recht zetten, meerdere pagina's).
/// Niet beschikbaar in de simulator: controleer eerst `DocumentScanner.isBeschikbaar`.
struct DocumentScanner: UIViewControllerRepresentable {
    static var isBeschikbaar: Bool { VNDocumentCameraViewController.isSupported }

    /// Gescande pagina's; leeg als de gebruiker annuleert.
    let klaar: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(klaar: klaar) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let klaar: ([UIImage]) -> Void

        init(klaar: @escaping ([UIImage]) -> Void) {
            self.klaar = klaar
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            klaar((0..<scan.pageCount).map(scan.imageOfPage(at:)))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            klaar([])
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            klaar([])
        }
    }
}
