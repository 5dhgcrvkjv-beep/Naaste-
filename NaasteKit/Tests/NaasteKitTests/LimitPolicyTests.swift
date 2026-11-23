import Testing
@testable import NaasteKit

@Suite("Gratis vs. Plus")
struct LimitPolicyTests {
    let gratis = LimitPolicy(isPlus: false)
    let plus = LimitPolicy(isPlus: true)

    @Test func gratisMagEenNaaste() {
        #expect(gratis.naasteToevoegen(huidigAantalEigen: 0) == .toegestaan)
        #expect(gratis.naasteToevoegen(huidigAantalEigen: 1) == .limietBereikt(.naasten(max: 1)))
    }

    @Test func plusOnbeperktNaasten() {
        #expect(plus.naasteToevoegen(huidigAantalEigen: 25) == .toegestaan)
    }

    @Test("15e document mag, 16e niet", arguments: [(0, true), (14, true), (15, false), (40, false)])
    func documentgrens(huidig: Int, mag: Bool) {
        #expect(gratis.documentToevoegen(huidigAantal: huidig).isToegestaan == mag)
    }

    @Test func meerdereDocumentenTegelijk() {
        #expect(gratis.documentToevoegen(huidigAantal: 13, extra: 2) == .toegestaan)
        #expect(gratis.documentToevoegen(huidigAantal: 13, extra: 3) == .limietBereikt(.documenten(max: 15)))
        // extra = 0 telt als 1
        #expect(gratis.documentToevoegen(huidigAantal: 15, extra: 0).isToegestaan == false)
    }

    @Test func resterend() {
        #expect(gratis.resterendeDocumenten(huidigAantal: 10) == 5)
        #expect(gratis.resterendeDocumenten(huidigAantal: 20) == 0)
        #expect(plus.resterendeDocumenten(huidigAantal: 20) == nil)
    }

    @Test func delen() {
        #expect(gratis.deelnemerToevoegen(huidigAantalDeelnemers: 0) == .toegestaan)
        #expect(gratis.deelnemerToevoegen(huidigAantalDeelnemers: 1) == .limietBereikt(.deelnemers(max: 1)))
        #expect(plus.deelnemerToevoegen(huidigAantalDeelnemers: 8) == .toegestaan)
    }

    @Test func plusFuncties() {
        for functie in PlusFunctie.allCases {
            #expect(gratis.heeftToegang(tot: functie) == false)
            #expect(plus.heeftToegang(tot: functie))
        }
    }
}
