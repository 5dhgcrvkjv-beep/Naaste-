import Foundation

/// Externe links. De pagina's staan in de map `site/` en worden gehost via GitHub Pages
/// (repo → Settings → Pages → Branch: main, map: /site). Dezelfde URL's vul je in App Store Connect in.
enum AppLinks {
    static let basis = URL(string: "https://5dhgcrvkjv-beep.github.io/Naaste-/")!
    static let privacybeleid = URL(string: "https://5dhgcrvkjv-beep.github.io/Naaste-/privacy.html")!
    static let gebruiksvoorwaarden = URL(string: "https://5dhgcrvkjv-beep.github.io/Naaste-/voorwaarden.html")!
    static let ondersteuning = URL(string: "https://5dhgcrvkjv-beep.github.io/Naaste-/support.html")!
}
