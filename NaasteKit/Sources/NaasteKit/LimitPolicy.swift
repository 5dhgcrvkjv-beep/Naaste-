import Foundation

/// Functies die bij "Naaste Plus" horen.
public enum PlusFunctie: String, CaseIterable, Sendable {
    case onbeperktNaasten
    case onbeperktDocumenten
    case delenMetFamilie
    case urenlogboek
    case urenExport
}

/// Welke gratis limiet is bereikt.
public enum Limiet: Equatable, Sendable {
    case naasten(max: Int)
    case documenten(max: Int)
    case deelnemers(max: Int)
}

public enum LimietUitkomst: Equatable, Sendable {
    case toegestaan
    case limietBereikt(Limiet)

    public var isToegestaan: Bool { self == .toegestaan }
}

/// Alle regels voor gratis vs. Plus op één plek.
///
/// Uitgangspunten:
/// - Gratis is echt bruikbaar: 1 eigen naaste, 15 documenten, delen met 1 persoon,
///   en het overdrachtsoverzicht (PDF) is altijd gratis.
/// - Limieten gelden alleen voor *toevoegen*. Wie Plus stopt, houdt toegang tot alles
///   wat er al staat (bekijken, bewerken, verwijderen, exporteren van het overzicht).
/// - De voorbeeld-naaste telt nergens mee.
public struct LimitPolicy: Equatable, Sendable {
    public static let gratisMaxNaasten = 1
    public static let gratisMaxDocumenten = 15
    /// Aantal andere personen (naast de eigenaar) waarmee je gratis deelt.
    public static let gratisMaxDeelnemers = 1

    public let isPlus: Bool

    public init(isPlus: Bool) {
        self.isPlus = isPlus
    }

    /// - Parameter huidigAantalEigen: eigen naasten, zonder voorbeeld en zonder met jou gedeelde naasten.
    public func naasteToevoegen(huidigAantalEigen: Int) -> LimietUitkomst {
        guard !isPlus else { return .toegestaan }
        return huidigAantalEigen < Self.gratisMaxNaasten
            ? .toegestaan
            : .limietBereikt(.naasten(max: Self.gratisMaxNaasten))
    }

    /// - Parameters:
    ///   - huidigAantal: documenten bij eigen naasten (zonder voorbeeld).
    ///   - extra: hoeveel documenten er tegelijk bij komen (bijv. meerdere PDF's importeren).
    public func documentToevoegen(huidigAantal: Int, extra: Int = 1) -> LimietUitkomst {
        guard !isPlus else { return .toegestaan }
        return huidigAantal + max(extra, 1) <= Self.gratisMaxDocumenten
            ? .toegestaan
            : .limietBereikt(.documenten(max: Self.gratisMaxDocumenten))
    }

    /// - Parameter huidigAantalDeelnemers: deelnemers zonder de eigenaar zelf
    ///   (ook nog niet geaccepteerde uitnodigingen tellen mee).
    public func deelnemerToevoegen(huidigAantalDeelnemers: Int) -> LimietUitkomst {
        guard !isPlus else { return .toegestaan }
        return huidigAantalDeelnemers < Self.gratisMaxDeelnemers
            ? .toegestaan
            : .limietBereikt(.deelnemers(max: Self.gratisMaxDeelnemers))
    }

    /// `nil` = onbeperkt.
    public func resterendeDocumenten(huidigAantal: Int) -> Int? {
        isPlus ? nil : max(Self.gratisMaxDocumenten - huidigAantal, 0)
    }

    public func heeftToegang(tot functie: PlusFunctie) -> Bool {
        isPlus
    }
}
