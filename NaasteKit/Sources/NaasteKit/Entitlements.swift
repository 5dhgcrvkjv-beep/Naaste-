import Foundation

/// Product-ID's in App Store Connect en in `Naaste.storekit`. Moeten exact overeenkomen.
public enum PlusProduct {
    public static let maand = "nl.naaste.app.plus.maand"
    public static let jaar = "nl.naaste.app.plus.jaar"
    public static let alle: [String] = [jaar, maand]
    public static let alleSet: Set<String> = Set(alle)
}

/// Platformonafhankelijke weergave van een StoreKit-`Transaction`,
/// zodat de beslislogica zonder StoreKit te testen is.
public struct EntitlementInfo: Equatable, Sendable {
    public enum Eigendom: String, Codable, Sendable {
        case gekocht
        case gezinsdeling
    }

    public let productID: String
    public let verloopDatum: Date?
    public let intrekDatum: Date?
    public let isUpgraded: Bool
    public let eigendom: Eigendom

    public init(productID: String, verloopDatum: Date?, intrekDatum: Date? = nil, isUpgraded: Bool = false, eigendom: Eigendom = .gekocht) {
        self.productID = productID
        self.verloopDatum = verloopDatum
        self.intrekDatum = intrekDatum
        self.isUpgraded = isUpgraded
        self.eigendom = eigendom
    }
}

public enum PlusStatus: Equatable, Codable, Sendable {
    case gratis
    case plus(productID: String, verlooptOp: Date?, viaGezin: Bool)

    public var isPlus: Bool {
        if case .plus = self { return true }
        return false
    }

    public var productID: String? {
        if case let .plus(id, _, _) = self { return id }
        return nil
    }
}

public enum EntitlementResolver {
    /// Bepaalt de status uit de huidige rechten (`Transaction.currentEntitlements`).
    /// Ingetrokken (terugbetaalde), vervangen (upgrade) en verlopen transacties tellen niet.
    /// Abonnementen via Gezinsdeling tellen wel.
    public static func status(uit rechten: [EntitlementInfo], nu: Date = Date(), bekendeProducten: Set<String> = PlusProduct.alleSet) -> PlusStatus {
        let geldig = rechten.filter { info in
            bekendeProducten.contains(info.productID)
                && info.intrekDatum == nil
                && !info.isUpgraded
                && (info.verloopDatum.map { $0 > nu } ?? true)
        }
        guard let beste = geldig.max(by: { ($0.verloopDatum ?? .distantFuture) < ($1.verloopDatum ?? .distantFuture) }) else {
            return .gratis
        }
        return .plus(productID: beste.productID, verlooptOp: beste.verloopDatum, viaGezin: beste.eigendom == .gezinsdeling)
    }

    /// Gecachte status bij een koude start (offline). Een verlopen cache telt als gratis.
    public static func gecachteStatus(_ status: PlusStatus?, nu: Date = Date()) -> PlusStatus {
        guard let status else { return .gratis }
        if case let .plus(_, verlooptOp, _) = status, let verlooptOp, verlooptOp <= nu {
            return .gratis
        }
        return status
    }
}
