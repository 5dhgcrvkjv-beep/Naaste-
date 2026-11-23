import Foundation
import NaasteKit
import os
import StoreKit

/// Houdt bij of de gebruiker "Naaste Plus" heeft.
///
/// - Bij de start: `Transaction.currentEntitlements` (ook abonnementen via Gezinsdeling).
/// - Daarna: luistert naar `Transaction.updates` (verlengingen, terugbetalingen, aankopen op een ander toestel).
/// - De laatste status wordt gecachet, zodat de app ook zonder internet direct goed start.
@MainActor
@Observable
final class EntitlementStore {
    private(set) var status: PlusStatus
    private(set) var producten: [Product] = []
    private(set) var productenLaden = false
    private(set) var productFout: String?
    /// Of de gebruiker nog recht heeft op de gratis proefperiode (per product-ID).
    private(set) var proefBeschikbaar: [String: Bool] = [:]

    @ObservationIgnored private var updatesTaak: Task<Void, Never>?
    private let defaults: UserDefaults
    private let log = Logger(subsystem: "nl.naaste.app", category: "Abonnement")

    static let cacheSleutel = "plusStatusCache"

    var isPlus: Bool { status.isPlus }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let gecachet = defaults.data(forKey: Self.cacheSleutel)
            .flatMap { try? JSONDecoder().decode(PlusStatus.self, from: $0) }
        status = EntitlementResolver.gecachteStatus(gecachet)
    }

    /// Start het luisteren; veilig om vaker aan te roepen.
    func start() {
        guard updatesTaak == nil else { return }
        updatesTaak = Task { [weak self] in
            for await update in Transaction.updates {
                if case let .verified(transactie) = update {
                    await transactie.finish()
                }
                await self?.vernieuw()
            }
        }
        Task {
            await vernieuw()
            await laadProducten()
        }
    }

    func vernieuw() async {
        var rechten: [EntitlementInfo] = []
        for await resultaat in Transaction.currentEntitlements {
            // Alleen door Apple geverifieerde transacties tellen.
            guard case let .verified(t) = resultaat, t.productType == .autoRenewable else { continue }
            rechten.append(EntitlementInfo(
                productID: t.productID,
                verloopDatum: t.expirationDate,
                intrekDatum: t.revocationDate,
                isUpgraded: t.isUpgraded,
                eigendom: t.ownershipType == .familyShared ? .gezinsdeling : .gekocht
            ))
        }
        zet(EntitlementResolver.status(uit: rechten))
    }

    func laadProducten() async {
        guard !productenLaden else { return }
        productenLaden = true
        defer { productenLaden = false }
        do {
            let geladen = try await Product.products(for: PlusProduct.alle)
            producten = geladen.sorted { ($0.subscription?.subscriptionPeriod.inDagen ?? 0) > ($1.subscription?.subscriptionPeriod.inDagen ?? 0) }
            productFout = producten.isEmpty ? String(localized: "De abonnementen zijn nu niet beschikbaar. Controleer je internetverbinding en probeer het later opnieuw.") : nil
            for product in producten {
                proefBeschikbaar[product.id] = await product.subscription?.isEligibleForIntroOffer ?? false
            }
        } catch {
            log.error("Producten laden mislukt: \(error.localizedDescription, privacy: .public)")
            productFout = String(localized: "De abonnementen konden niet worden geladen. Controleer je internetverbinding en probeer het opnieuw.")
        }
    }

    /// "Aankopen herstellen": synchroniseert met de App Store (kan om de Apple ID-login vragen).
    func herstel() async throws {
        try await AppStore.sync()
        await vernieuw()
    }

    private func zet(_ nieuw: PlusStatus) {
        status = nieuw
        if let data = try? JSONEncoder().encode(nieuw) {
            defaults.set(data, forKey: Self.cacheSleutel)
        }
    }
}

extension Product.SubscriptionPeriod {
    /// Benadering in dagen, om producten te sorteren (jaar vóór maand).
    var inDagen: Int {
        switch unit {
        case .day: value
        case .week: value * 7
        case .month: value * 30
        case .year: value * 365
        @unknown default: value
        }
    }

    /// "maand", "jaar", "2 weken" … voor zinnen als "€ 3,99 per maand".
    var leesbaar: String {
        let enkel = value == 1
        switch unit {
        case .day: return enkel ? String(localized: "dag") : String(localized: "\(value) dagen")
        case .week: return enkel ? String(localized: "week") : String(localized: "\(value) weken")
        case .month: return enkel ? String(localized: "maand") : String(localized: "\(value) maanden")
        case .year: return enkel ? String(localized: "jaar") : String(localized: "\(value) jaar")
        @unknown default: return String(localized: "periode")
        }
    }
}
