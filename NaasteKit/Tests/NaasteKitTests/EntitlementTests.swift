import Foundation
import Testing
@testable import NaasteKit

@Suite("Abonnementsstatus")
struct EntitlementTests {
    let nu = Date(timeIntervalSince1970: 1_800_000_000)
    var morgen: Date { nu.addingTimeInterval(86_400) }
    var gisteren: Date { nu.addingTimeInterval(-86_400) }

    @Test func geenRechtenIsGratis() {
        #expect(EntitlementResolver.status(uit: [], nu: nu) == .gratis)
    }

    @Test func actiefMaandabonnement() {
        let status = EntitlementResolver.status(uit: [.init(productID: PlusProduct.maand, verloopDatum: morgen)], nu: nu)
        #expect(status == .plus(productID: PlusProduct.maand, verlooptOp: morgen, viaGezin: false))
        #expect(status.isPlus)
    }

    @Test func verlopenTeltNiet() {
        #expect(EntitlementResolver.status(uit: [.init(productID: PlusProduct.jaar, verloopDatum: gisteren)], nu: nu) == .gratis)
    }

    @Test func terugbetaaldTeltNiet() {
        let info = EntitlementInfo(productID: PlusProduct.jaar, verloopDatum: morgen, intrekDatum: gisteren)
        #expect(EntitlementResolver.status(uit: [info], nu: nu) == .gratis)
    }

    @Test func upgradeTeltNiet() {
        let oud = EntitlementInfo(productID: PlusProduct.maand, verloopDatum: morgen, isUpgraded: true)
        #expect(EntitlementResolver.status(uit: [oud], nu: nu) == .gratis)
    }

    @Test func onbekendProductTeltNiet() {
        #expect(EntitlementResolver.status(uit: [.init(productID: "iets.anders", verloopDatum: morgen)], nu: nu) == .gratis)
    }

    @Test func gezinsdelingTeltWel() {
        let info = EntitlementInfo(productID: PlusProduct.jaar, verloopDatum: morgen, eigendom: .gezinsdeling)
        #expect(EntitlementResolver.status(uit: [info], nu: nu) == .plus(productID: PlusProduct.jaar, verlooptOp: morgen, viaGezin: true))
    }

    @Test func langstLopendeWint() {
        let later = nu.addingTimeInterval(86_400 * 300)
        let status = EntitlementResolver.status(uit: [
            .init(productID: PlusProduct.maand, verloopDatum: morgen, eigendom: .gezinsdeling),
            .init(productID: PlusProduct.jaar, verloopDatum: later)
        ], nu: nu)
        #expect(status.productID == PlusProduct.jaar)
    }

    @Test func cache() throws {
        #expect(EntitlementResolver.gecachteStatus(nil, nu: nu) == .gratis)
        let verlopen = PlusStatus.plus(productID: PlusProduct.maand, verlooptOp: gisteren, viaGezin: false)
        #expect(EntitlementResolver.gecachteStatus(verlopen, nu: nu) == .gratis)
        let geldig = PlusStatus.plus(productID: PlusProduct.maand, verlooptOp: morgen, viaGezin: false)
        #expect(EntitlementResolver.gecachteStatus(geldig, nu: nu) == geldig)

        // Codable rondreis (zo staat de cache in UserDefaults)
        let data = try JSONEncoder().encode(geldig)
        #expect(try JSONDecoder().decode(PlusStatus.self, from: data) == geldig)
    }
}
