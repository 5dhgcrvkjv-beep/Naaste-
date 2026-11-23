import Foundation
import Testing
@testable import NaasteKit

@Suite("Documentnamen")
struct DocumentNamenTests {
    @Test func titelUitBestandsnaam() {
        #expect(DocumentNamen.titel(uitBestandsnaam: "beschikking_wmo-2026.pdf") == "Beschikking wmo 2026")
        #expect(DocumentNamen.titel(uitBestandsnaam: "Polis  2026.PDF") == "Polis 2026")
        #expect(DocumentNamen.titel(uitBestandsnaam: "brief.van.cak.pdf") == "Brief.van.cak")
        #expect(DocumentNamen.titel(uitBestandsnaam: ".pdf") == ".pdf")
        #expect(DocumentNamen.titel(uitBestandsnaam: "___.pdf") == "")
    }

    @Test func scanTitel() {
        var c = DateComponents()
        c.year = 2026; c.month = 11; c.day = 23; c.hour = 12
        let datum = Calendar(identifier: .gregorian).date(from: c)!
        #expect(DocumentNamen.scanTitel(op: datum) == "Scan 23 nov 2026")
    }

    @Test func veiligeBestandsnaam() {
        #expect(DocumentNamen.bestandsnaam(voorTitel: "Wmo: beschikking 1/2") == "Wmo beschikking 1 2.pdf")
        #expect(DocumentNamen.bestandsnaam(voorTitel: "  ") == "Document.pdf")
        #expect(DocumentNamen.bestandsnaam(voorTitel: String(repeating: "a", count: 300)).count == 104)
    }
}
