import NaasteKit
import SwiftUI

// Nederlandse namen en SF Symbols voor de enums uit NaasteKit.
// Alle teksten gaan via de String Catalog (Localizable.xcstrings), zodat Engels later kan.

extension DocumentCategorie {
    var titel: String {
        switch self {
        case .wmo: String(localized: "Wmo")
        case .wlzCiz: String(localized: "Wlz / CIZ")
        case .pgb: String(localized: "Pgb")
        case .cak: String(localized: "CAK")
        case .verzekering: String(localized: "Verzekering")
        case .wonen: String(localized: "Wonen")
        case .juridisch: String(localized: "Juridisch en volmachten")
        case .financien: String(localized: "Financiën")
        case .overig: String(localized: "Overig")
        }
    }

    var uitleg: String {
        switch self {
        case .wmo: String(localized: "Gemeente: hulp in huis, hulpmiddelen, vervoer")
        case .wlzCiz: String(localized: "Langdurige zorg en indicatie van het CIZ")
        case .pgb: String(localized: "Persoonsgebonden budget")
        case .cak: String(localized: "Eigen bijdrage")
        case .verzekering: String(localized: "Zorgverzekering en andere polissen")
        case .wonen: String(localized: "Huur, aanpassingen, verhuizing")
        case .juridisch: String(localized: "Volmachten, mentorschap, testament")
        case .financien: String(localized: "Bank, belasting, toeslagen")
        case .overig: String(localized: "Alles wat nergens anders past")
        }
    }

    var symbool: String {
        switch self {
        case .wmo: "building.2"
        case .wlzCiz: "checkmark.seal"
        case .pgb: "eurosign.circle"
        case .cak: "creditcard"
        case .verzekering: "shield.lefthalf.filled"
        case .wonen: "house"
        case .juridisch: "signature"
        case .financien: "banknote"
        case .overig: "folder"
        }
    }
}

extension ZaakStatus {
    var titel: String {
        switch self {
        case .voorbereiden: String(localized: "Voorbereiden")
        case .aangevraagd: String(localized: "Aangevraagd")
        case .inBehandeling: String(localized: "In behandeling")
        case .toegekend: String(localized: "Toegekend")
        case .afgewezen: String(localized: "Afgewezen")
        case .bezwaar: String(localized: "Bezwaar")
        case .afgerond: String(localized: "Afgerond")
        }
    }

    var symbool: String {
        switch self {
        case .voorbereiden: "pencil.and.list.clipboard"
        case .aangevraagd: "paperplane"
        case .inBehandeling: "hourglass"
        case .toegekend: "checkmark.circle"
        case .afgewezen: "xmark.circle"
        case .bezwaar: "exclamationmark.bubble"
        case .afgerond: "archivebox"
        }
    }

    var kleur: Color {
        switch self {
        case .voorbereiden: .secondary
        case .aangevraagd, .inBehandeling: .blue
        case .toegekend, .afgerond: .accentColor
        case .afgewezen: .red
        case .bezwaar: .orange
        }
    }
}

extension ContactRol {
    var titel: String {
        switch self {
        case .huisarts: String(localized: "Huisarts")
        case .thuiszorg: String(localized: "Thuiszorg")
        case .wijkverpleging: String(localized: "Wijkverpleging")
        case .casemanager: String(localized: "Casemanager")
        case .gemeente: String(localized: "Gemeente / Wmo-loket")
        case .zorgverzekeraar: String(localized: "Zorgverzekeraar")
        case .notaris: String(localized: "Notaris")
        case .bank: String(localized: "Bank")
        case .familie: String(localized: "Familie of buren")
        case .overig: String(localized: "Overig")
        }
    }

    var symbool: String {
        switch self {
        case .huisarts: "stethoscope"
        case .thuiszorg: "house"
        case .wijkverpleging: "cross.case"
        case .casemanager: "person.crop.circle.badge.checkmark"
        case .gemeente: "building.columns"
        case .zorgverzekeraar: "shield.lefthalf.filled"
        case .notaris: "signature"
        case .bank: "banknote"
        case .familie: "person.2"
        case .overig: "person"
        }
    }
}

extension HerinneringSoort {
    var titel: String {
        switch self {
        case .herindicatie: String(localized: "Herindicatie")
        case .verlenging: String(localized: "Verlenging")
        case .betaling: String(localized: "Betaling")
        case .afspraak: String(localized: "Afspraak")
        case .vervolg: String(localized: "Vervolgactie")
        case .overig: String(localized: "Herinnering")
        }
    }

    var symbool: String {
        switch self {
        case .herindicatie: "arrow.clockwise"
        case .verlenging: "calendar.badge.plus"
        case .betaling: "eurosign"
        case .afspraak: "calendar"
        case .vervolg: "arrow.turn.down.right"
        case .overig: "bell"
        }
    }
}

extension Herhaling {
    var titel: String {
        switch self {
        case .geen: String(localized: "Niet herhalen")
        case .wekelijks: String(localized: "Elke week")
        case .maandelijks: String(localized: "Elke maand")
        case .perKwartaal: String(localized: "Elk kwartaal")
        case .jaarlijks: String(localized: "Elk jaar")
        }
    }
}

extension UrenCategorie {
    var titel: String {
        switch self {
        case .administratie: String(localized: "Administratie")
        case .vervoer: String(localized: "Vervoer en begeleiding")
        case .persoonlijkeZorg: String(localized: "Persoonlijke verzorging")
        case .huishouden: String(localized: "Huishouden")
        case .gezelschap: String(localized: "Gezelschap")
        case .overig: String(localized: "Overig")
        }
    }

    var symbool: String {
        switch self {
        case .administratie: "doc.text"
        case .vervoer: "car"
        case .persoonlijkeZorg: "hands.and.sparkles"
        case .huishouden: "house"
        case .gezelschap: "cup.and.saucer"
        case .overig: "ellipsis.circle"
        }
    }
}

extension FamilieKleur {
    var kleur: Color {
        switch self {
        case .groen: .green
        case .blauw: .blue
        case .oranje: .orange
        case .paars: .purple
        case .roze: .pink
        case .bruin: .brown
        case .grijs: .gray
        }
    }

    var titel: String {
        switch self {
        case .groen: String(localized: "Groen")
        case .blauw: String(localized: "Blauw")
        case .oranje: String(localized: "Oranje")
        case .paars: String(localized: "Paars")
        case .roze: String(localized: "Roze")
        case .bruin: String(localized: "Bruin")
        case .grijs: String(localized: "Grijs")
        }
    }
}

enum Duur {
    /// "2 uur en 15 minuten" (voluit, ook voor VoiceOver) of kort "2 u 15 min".
    static func tekst(minuten: Int, kort: Bool = true) -> String {
        let (u, m) = UrenRekenaar.urenEnMinuten(minuten)
        if kort {
            switch (u, m) {
            case (0, _): return String(localized: "\(m) min")
            case (_, 0): return String(localized: "\(u) u")
            default: return String(localized: "\(u) u \(m) min")
            }
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        return formatter.string(from: TimeInterval(max(minuten, 0) * 60)) ?? String(localized: "\(u) u \(m) min")
    }
}
