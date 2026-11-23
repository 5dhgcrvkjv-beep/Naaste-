import CoreData
import NaasteKit
import PDFKit
import Testing
import UIKit
@testable import NaasteApp

/// Documenten: PDF-analyse, tekstherkenning en toevoegen met limieten.
@MainActor
@Suite("Documenten")
struct DocumentTests {
    let persistence = PersistenceController(inMemory: true)

    private func voorbeeldPDF(_ regels: [String]) -> Data {
        var opmaak = PDFOpmaak()
        opmaak.voegToe(.titel(regels.first ?? ""))
        regels.dropFirst().forEach { opmaak.voegToe(.tekst($0)) }
        return opmaak.maakPDF(titelMetadata: "Test")
    }

    /// Een "foto" van een brief: tekst getekend op een afbeelding, dus zonder tekstlaag.
    private func gescandePagina(_ tekst: String) -> UIImage {
        let grootte = CGSize(width: 1240, height: 1754)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: grootte, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: grootte))
            (tekst as NSString).draw(
                in: CGRect(x: 100, y: 150, width: 1040, height: 1400),
                withAttributes: [.font: UIFont.systemFont(ofSize: 48), .foregroundColor: UIColor.black]
            )
        }
    }

    @Test func basisVanPDF() throws {
        let basis = try DocumentAnalyse.basis(van: voorbeeldPDF(["Beschikking", "Huishoudelijke hulp"]))
        #expect(basis.paginas == 1)
        #expect(basis.miniatuur.flatMap(UIImage.init(data:)) != nil)
    }

    @Test func geenPDFWordtGeweigerd() {
        #expect(throws: DocumentAnalyse.Fout.self) {
            try DocumentAnalyse.basis(van: Data("geen pdf".utf8))
        }
    }

    @Test func tekstlaagVanDigitalePDF() async throws {
        let tekst = try await DocumentAnalyse.tekst(van: voorbeeldPDF(["Beschikking Wmo", "Gemeente Utrecht kent huishoudelijke hulp toe."]))
        #expect(Zoeken.past("utrecht huishoudelijke", in: [tekst]))
    }

    @Test func scanWordtPDFEnTekstWordtHerkend() async throws {
        let pagina = gescandePagina("Centraal Administratie Kantoor\nEigen bijdrage december")
        let data = try #require(DocumentAnalyse.pdf(van: [pagina, pagina]))
        let pdf = try #require(PDFDocument(data: data))
        #expect(pdf.pageCount == 2)
        // Geen tekstlaag: de tekst moet uit Vision komen.
        #expect(DocumentAnalyse.ingebeddeTekst(van: pdf) == nil)

        let tekst = try await DocumentAnalyse.tekst(van: data)
        #expect(Zoeken.past("administratie bijdrage", in: [tekst]), "Herkend: \(tekst)")
    }

    @Test func toevoegenStartHerkenningEnRespecteertLimiet() async throws {
        let defaults = try #require(UserDefaults(suiteName: "DocumentTests-\(UUID())"))
        let app = AppModel(persistence: persistence, entitlements: EntitlementStore(defaults: defaults))
        let naaste = Naaste(context: persistence.viewContext)
        naaste.naam = "Test"
        try persistence.bewaar()

        let bestand = AppModel.NieuwBestand(data: voorbeeldPDF(["Polis zorgverzekering 2026", "Polisnummer 123456789"]), bestandsnaam: "polis.pdf", titel: "Polis")
        let nieuw = app.voegDocumentenToe([bestand], aan: naaste, categorie: .verzekering)
        let document = try #require(nieuw.first)
        #expect(document.categorieWaarde == .verzekering)
        #expect(document.paginas == 1)
        #expect(document.miniatuur != nil)

        // Wacht tot de tekst gelezen is (in-memory, dus snel).
        for _ in 0..<50 where document.ocrStatusWaarde != .klaar {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(document.ocrStatusWaarde == .klaar)
        #expect(document.ocrTekst?.contains("123456789") == true)

        // Gratis: 15 documenten. Er staat er al 1, dus 15 extra mag niet in één keer.
        let teVeel = Array(repeating: bestand, count: LimitPolicy.gratisMaxDocumenten)
        #expect(app.voegDocumentenToe(teVeel, aan: naaste, categorie: .overig).isEmpty)
        #expect(app.paywall == .limiet(.documenten(max: LimitPolicy.gratisMaxDocumenten)))
    }
}
