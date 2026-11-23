import Foundation

/// Enum die als `String` in Core Data/CloudKit wordt opgeslagen.
/// Onbekende of lege waarden (bijv. van een nieuwere app-versie op een ander toestel)
/// vallen terug op `fallback`, zodat de app nooit crasht op onverwachte data.
public protocol OpgeslagenEnum: RawRepresentable, CaseIterable, Hashable, Sendable, Identifiable where RawValue == String {
    static var fallback: Self { get }
}

public extension OpgeslagenEnum {
    init(opgeslagen raw: String?) {
        self = raw.flatMap(Self.init(rawValue:)) ?? Self.fallback
    }

    var id: String { rawValue }
}

/// Mappen in de documentenkluis.
public enum DocumentCategorie: String, OpgeslagenEnum {
    case wmo
    case wlzCiz
    case pgb
    case cak
    case verzekering
    case wonen
    case juridisch
    case financien
    case overig

    public static let fallback: DocumentCategorie = .overig
}

/// Status van een dossier/aanvraag ("zaak").
public enum ZaakStatus: String, OpgeslagenEnum {
    case voorbereiden
    case aangevraagd
    case inBehandeling
    case toegekend
    case afgewezen
    case bezwaar
    case afgerond

    public static let fallback: ZaakStatus = .voorbereiden

    /// Een zaak is lopend zolang hij niet is afgerond.
    public var isLopend: Bool { self != .afgerond }

    /// Een zaak vraagt actie van de familie (in tegenstelling tot wachten op de instantie).
    public var vraagtActie: Bool {
        switch self {
        case .voorbereiden, .afgewezen, .bezwaar: true
        case .aangevraagd, .inBehandeling, .toegekend, .afgerond: false
        }
    }

    /// Logische vervolgstappen, voor de snelle statusknoppen in de tijdlijn.
    public var vervolgStatussen: [ZaakStatus] {
        switch self {
        case .voorbereiden: [.aangevraagd]
        case .aangevraagd: [.inBehandeling, .toegekend, .afgewezen]
        case .inBehandeling: [.toegekend, .afgewezen]
        case .toegekend: [.afgerond]
        case .afgewezen: [.bezwaar, .afgerond]
        case .bezwaar: [.toegekend, .afgewezen, .afgerond]
        case .afgerond: []
        }
    }
}

/// Rol van een contactpersoon rond de naaste.
public enum ContactRol: String, OpgeslagenEnum {
    case huisarts
    case thuiszorg
    case wijkverpleging
    case casemanager
    case gemeente
    case zorgverzekeraar
    case notaris
    case bank
    case familie
    case overig

    public static let fallback: ContactRol = .overig
}

/// Soort herinnering/deadline.
public enum HerinneringSoort: String, OpgeslagenEnum {
    case herindicatie
    case verlenging
    case betaling
    case afspraak
    case vervolg
    case overig

    public static let fallback: HerinneringSoort = .overig
}

/// Herhaling van een herinnering.
public enum Herhaling: String, OpgeslagenEnum {
    case geen
    case wekelijks
    case maandelijks
    case perKwartaal
    case jaarlijks

    public static let fallback: Herhaling = .geen

    /// Kalendercomponent + aantal voor één herhaling.
    public var stap: (component: Calendar.Component, aantal: Int)? {
        switch self {
        case .geen: nil
        case .wekelijks: (.weekOfYear, 1)
        case .maandelijks: (.month, 1)
        case .perKwartaal: (.month, 3)
        case .jaarlijks: (.year, 1)
        }
    }
}

/// Categorie van bestede mantelzorg-tijd.
public enum UrenCategorie: String, OpgeslagenEnum {
    case administratie
    case vervoer
    case persoonlijkeZorg
    case huishouden
    case gezelschap
    case overig

    public static let fallback: UrenCategorie = .overig
}

/// Soort regel in de tijdlijn van een zaak.
public enum GebeurtenisSoort: String, OpgeslagenEnum {
    case status
    case notitie
    case contact
    case document

    public static let fallback: GebeurtenisSoort = .notitie
}

/// Voortgang van de tekstherkenning van een document.
public enum OCRStatus: String, OpgeslagenEnum {
    case wachtend
    case bezig
    case klaar
    case mislukt
    case nietNodig

    public static let fallback: OCRStatus = .wachtend
}
