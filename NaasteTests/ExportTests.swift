import CoreData
import NaasteKit
import PDFKit
import Testing
@testable import NaasteApp

/// PDF-exports: overdrachtsoverzicht (gratis) en urenoverzicht (Plus).
@MainActor
@Suite("Exports")
struct ExportTests {
    let persistence = PersistenceController(inMemory: true)

    private func maakApp() throws -> AppModel {
        let defaults = try #require(UserDefaults(suiteName: "ExportTests-\(UUID())"))
        return AppModel(persistence: persistence, entitlements: EntitlementStore(defaults: defaults))
    }

    /// Tekst uit de PDF, met witruimte samengevoegd (regels kunnen afbreken).
    private func tekst(_ data: Data) throws -> String {
        let pdf = try #require(PDFDocument(data: data))
        return (pdf.string ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    @Test func overdrachtBevatDeBelangrijksteOnderdelen() throws {
        let app = try maakApp()
        let naaste = try #require(app.laadVoorbeeld())
        let t = try tekst(Exports.overdracht(naaste))

        #expect(t.contains(naaste.weergaveNaam))
        #expect(t.contains("Contactpersonen"))
        #expect(t.contains("Lopende zaken"))
        #expect(t.contains("Wmo-aanvraag huishoudelijke hulp"))
        #expect(t.contains("Open taken"))
        #expect(t.contains("Thuiszorg bellen over nieuwe tijden"))
        #expect(t.contains("Documenten in Naaste"))
        // Afgeronde zaken horen niet bij "lopend".
        #expect(!t.contains("Volmacht bank regelen"))
    }

    @Test func onderdelenWeglaten() throws {
        let app = try maakApp()
        let naaste = try #require(app.laadVoorbeeld())
        naaste.medicatieNotitie = "Metoprolol 50 mg"
        var opties = OverdrachtOpties()
        #expect(try tekst(Exports.overdracht(naaste, opties: opties)).contains("Metoprolol"))

        opties.medicatie = false
        opties.documenten = false
        let t = try tekst(Exports.overdracht(naaste, opties: opties))
        #expect(!t.contains("Metoprolol"))
        #expect(!t.contains("Documenten in Naaste"))
        #expect(t.contains("Lopende zaken"))
    }

    @Test func urenOverzicht() throws {
        let app = try maakApp()
        let naaste = try #require(app.laadVoorbeeld())
        let data = Exports.uren(naaste, periode: .alles)
        let t = try tekst(data)
        #expect(t.contains("Urenoverzicht mantelzorg"))
        #expect(t.contains("Per persoon"))
        for lid in naaste.familieledenLijst where !lid.urenregelsLijst.isEmpty {
            #expect(t.contains(lid.weergaveNaam))
        }
        let totaal = UrenRekenaar.totaal(naaste.urenregelsLijst.map(\.data))
        #expect(t.contains(Duur.tekst(minuten: totaal, kort: false).split(whereSeparator: \.isWhitespace).joined(separator: " ")))
    }

    @Test func langeLijstGeeftMeerderePaginas() throws {
        let app = try maakApp()
        let naaste = try #require(app.laadVoorbeeld())
        let lid = try #require(naaste.familieledenLijst.first)
        for i in 0..<120 {
            let regel = Urenregel(context: persistence.viewContext)
            regel.naaste = naaste
            regel.familielid = lid
            regel.minuten = 30
            regel.datum = Date().addingTimeInterval(-Double(i) * 3600)
            regel.omschrijving = "Regel \(i)"
        }
        let pdf = try #require(PDFDocument(data: Exports.uren(naaste, periode: .alles)))
        #expect(pdf.pageCount >= 3)
    }

    @Test func urenExportIsPlusOverdrachtNiet() throws {
        let app = try maakApp()
        let naaste = Naaste(context: persistence.viewContext)
        try persistence.bewaar()
        #expect(!app.heeftToegang(tot: .urenExport, bij: naaste))
        // Het overdrachtsoverzicht heeft geen Plus-functie: het is er voor iedereen.
        #expect(!PlusFunctie.allCases.map(\.rawValue).contains { $0.lowercased().contains("overdracht") })
    }
}
