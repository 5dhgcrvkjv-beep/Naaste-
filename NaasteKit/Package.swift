// swift-tools-version: 6.0
import PackageDescription

// Platformonafhankelijke logica van Naaste: limieten, abonnementsstatus,
// herinneringsplanning, zoeken en urenberekening. Geen UI, geen Core Data,
// zodat alles ook buiten Xcode (bijv. op Linux in CI) getest kan worden.
let package = Package(
    name: "NaasteKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "NaasteKit", targets: ["NaasteKit"])
    ],
    targets: [
        .target(name: "NaasteKit"),
        .testTarget(name: "NaasteKitTests", dependencies: ["NaasteKit"])
    ]
)
