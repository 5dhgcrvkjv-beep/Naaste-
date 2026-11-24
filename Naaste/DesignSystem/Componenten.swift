import NaasteKit
import SwiftUI

enum Opslagsleutel {
    static let geselecteerdeNaaste = "geselecteerdeNaaste"
    static let onboardingKlaar = "onboardingKlaar"
    static let meldingenUitgelegd = "meldingenUitgelegd"
    static let vergrendeling = "vergrendeling"

    /// Welk familielid "ik" ben op deze iPhone, per naaste (alleen lokaal opgeslagen).
    static func ikBen(_ naaste: Naaste) -> String {
        "ikBen-\(naaste.uuid?.uuidString ?? "onbekend")"
    }
}

/// Rondje met initialen in de kleur van het familielid.
struct Avatar: View {
    @ObservedObject var lid: Familielid
    var grootte: CGFloat = 32

    var body: some View {
        Text(lid.initialen)
            .font(.system(size: grootte * 0.42, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: grootte, height: grootte)
            .background(lid.kleurWaarde.kleur.opacity(0.22), in: Circle())
            .overlay(Circle().strokeBorder(lid.kleurWaarde.kleur, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

/// Klein label met status of categorie.
struct Etiket: View {
    let tekst: String
    var symbool: String?
    var kleur: Color = .secondary
    @Environment(\.dynamicTypeSize) private var tekstgrootte

    var body: some View {
        HStack(spacing: 4) {
            if let symbool {
                Image(systemName: symbool).accessibilityHidden(true)
            }
            Text(tekst)
                .lineLimit(tekstgrootte.isAccessibilitySize ? nil : 1)
        }
        // Normaal op één regel; bij heel grote letters mag het afbreken in plaats van buiten beeld te lopen.
        .fixedSize(horizontal: !tekstgrootte.isAccessibilitySize, vertical: false)
        .font(.caption.weight(.medium))
        .foregroundStyle(kleur)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(kleur.opacity(0.12), in: Capsule())
    }
}

/// Rij voor een lege sectie, met een korte uitleg.
struct LegeRij: View {
    let tekst: LocalizedStringKey

    var body: some View {
        Text(tekst)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }
}

/// Ronde actieknop (bellen, mailen) met een tikvlak van minimaal 44×44 pt.
struct RondeActie: View {
    let symbool: String
    let label: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            Image(systemName: symbool)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.14), in: Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }
}

/// Banner bovenaan bij de voorbeeld-naaste.
struct VoorbeeldBanner: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dit is een voorbeeld")
                    .font(.subheadline.weight(.semibold))
                Text("Probeer alles gerust uit. Voeg je eigen naaste toe via het menu rechtsboven; het voorbeeld verwijder je in Instellingen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, 4)
    }
}

extension Date {
    /// "vandaag", "morgen", "over 5 dagen", "3 dagen geleden".
    var relatief: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return String(localized: "vandaag") }
        if calendar.isDateInTomorrow(self) { return String(localized: "morgen") }
        if calendar.isDateInYesterday(self) { return String(localized: "gisteren") }
        let dagen = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: calendar.startOfDay(for: self)).day ?? 0
        return dagen > 0
            ? String(localized: "over \(dagen) dagen")
            : String(localized: "\(-dagen) dagen geleden")
    }

    var kort: String { formatted(.dateTime.day().month(.abbreviated).year()) }
}

extension Color {
    /// Vulling van hoofdknoppen. Donkerder dan de accentkleur in dark mode (#6FCF9F),
    /// zodat witte tekst erop leesbaar blijft: 5,2:1 (licht) en 4,8:1 (donker).
    static let knop = Color("KnopKleur")
}

extension View {
    /// Gevulde hoofdknop met voldoende contrast in licht en donker.
    func hoofdknop() -> some View {
        buttonStyle(.borderedProminent).tint(.knop)
    }
}
