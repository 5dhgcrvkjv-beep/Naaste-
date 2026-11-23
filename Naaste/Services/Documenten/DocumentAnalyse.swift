import PDFKit
import UIKit
import Vision

/// Alles wat Naaste uit een PDF haalt: aantal pagina's, een miniatuur en de tekst.
///
/// Tekst komt bij voorkeur uit de PDF zelf (digitale brieven). Is er geen tekstlaag,
/// bijvoorbeeld bij een scan, dan herkent Vision de tekst op het toestel.
/// Er gaat niets naar een server.
enum DocumentAnalyse {
    struct Basis: Sendable {
        let paginas: Int
        let miniatuur: Data?
    }

    enum Fout: Error {
        case geenGeldigePDF
    }

    /// Hoeveel pagina's Vision maximaal leest. Lange stukken (polisvoorwaarden) zijn
    /// zelden nodig om op te zoeken en kosten veel batterij.
    static let maxPaginasHerkennen = 30

    // MARK: - Basis (snel, bij toevoegen)

    static func basis(van data: Data) throws -> Basis {
        guard let pdf = PDFDocument(data: data), pdf.pageCount > 0 else { throw Fout.geenGeldigePDF }
        return Basis(paginas: pdf.pageCount, miniatuur: miniatuur(van: pdf))
    }

    static func miniatuur(van pdf: PDFDocument, breedte: CGFloat = 240) -> Data? {
        guard let pagina = pdf.page(at: 0) else { return nil }
        let kader = pagina.bounds(for: .mediaBox)
        guard kader.width > 0 else { return nil }
        let grootte = CGSize(width: breedte, height: breedte * kader.height / kader.width)
        return pagina.thumbnail(of: grootte, for: .mediaBox).jpegData(compressionQuality: 0.7)
    }

    // MARK: - Tekst (langzaam, op de achtergrond)

    /// Herkent de tekst van alle pagina's. Draait niet op de hoofdthread.
    static func tekst(van data: Data) async throws -> String {
        try await Task.detached(priority: .utility) {
            guard let pdf = PDFDocument(data: data) else { throw Fout.geenGeldigePDF }
            if let ingebed = ingebeddeTekst(van: pdf) { return ingebed }

            var delen: [String] = []
            for index in 0..<min(pdf.pageCount, maxPaginasHerkennen) {
                try Task.checkCancellation()
                guard let pagina = pdf.page(at: index), let beeld = afbeelding(van: pagina) else { continue }
                let tekst = try await herken(beeld)
                if !tekst.isEmpty { delen.append(tekst) }
            }
            return delen.joined(separator: "\n\n")
        }.value
    }

    /// Tekstlaag van een digitale PDF; `nil` als die ontbreekt of vrijwel leeg is.
    static func ingebeddeTekst(van pdf: PDFDocument) -> String? {
        guard let tekst = pdf.string?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        // Sommige scans hebben een paar losse tekens als "tekstlaag"; dat telt niet.
        return tekst.filter(\.isLetter).count >= 20 ? tekst : nil
    }

    /// Herkent tekst op één afbeelding (Nederlands en Engels).
    static func herken(_ beeld: CGImage) async throws -> String {
        var verzoek = RecognizeTextRequest()
        verzoek.recognitionLevel = .accurate
        verzoek.usesLanguageCorrection = true
        verzoek.recognitionLanguages = [Locale.Language(identifier: "nl-NL"), Locale.Language(identifier: "en-US")]
        let regels = try await verzoek.perform(on: beeld)
        return regels
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    /// Een pagina als afbeelding van ±2000 pixels breed: scherp genoeg voor kleine letters.
    static func afbeelding(van pagina: PDFPage, breedte: CGFloat = 2000) -> CGImage? {
        let kader = pagina.bounds(for: .mediaBox)
        guard kader.width > 0 else { return nil }
        let grootte = CGSize(width: breedte, height: breedte * kader.height / kader.width)
        return pagina.thumbnail(of: grootte, for: .mediaBox).cgImage
    }

    // MARK: - Scan → PDF

    /// Zet gescande pagina's om naar één PDF. Pagina's worden verkleind en als JPEG
    /// opgeslagen, zodat een brief van drie kantjes geen tientallen MB's iCloud kost.
    static func pdf(van paginas: [UIImage]) -> Data? {
        let pdf = PDFDocument()
        for (index, origineel) in paginas.enumerated() {
            let beeld = verklein(origineel, maxZijde: 2200)
            // A4-breedte in punten; hoogte volgt de verhouding van de scan.
            let breedte: CGFloat = 595.2
            let hoogte = breedte * beeld.size.height / max(beeld.size.width, 1)
            let opties: [PDFPage.ImageInitializationOption: Any] = [
                .mediaBox: NSValue(cgRect: CGRect(x: 0, y: 0, width: breedte, height: hoogte)),
                .compressionQuality: 0.6
            ]
            guard let pagina = PDFPage(image: beeld, options: opties) else { continue }
            pdf.insert(pagina, at: index)
        }
        guard pdf.pageCount > 0 else { return nil }
        return pdf.dataRepresentation()
    }

    static func verklein(_ beeld: UIImage, maxZijde: CGFloat) -> UIImage {
        let langste = max(beeld.size.width, beeld.size.height)
        guard langste > maxZijde else { return beeld }
        let factor = maxZijde / langste
        let grootte = CGSize(width: beeld.size.width * factor, height: beeld.size.height * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: grootte, format: format).image { _ in
            beeld.draw(in: CGRect(origin: .zero, size: grootte))
        }
    }
}
