import CoreData
import NaasteKit
import UIKit

/// Documenten toevoegen en tekst laten herkennen.
extension AppModel {
    /// Een te importeren bestand: de PDF-gegevens en de oorspronkelijke naam.
    struct NieuwBestand {
        let data: Data
        let bestandsnaam: String
        let titel: String
    }

    /// Maakt een PDF van gescande pagina's.
    func bestand(vanScan paginas: [UIImage]) -> NieuwBestand? {
        guard let data = DocumentAnalyse.pdf(van: paginas) else {
            foutmelding = String(localized: "De scan kon niet worden opgeslagen. Probeer het opnieuw.")
            return nil
        }
        let titel = DocumentNamen.scanTitel(op: .now)
        return NieuwBestand(data: data, bestandsnaam: DocumentNamen.bestandsnaam(voorTitel: titel), titel: titel)
    }

    /// Leest PDF's uit Bestanden. Bestanden die geen PDF zijn worden overgeslagen.
    func bestanden(vanImport urls: [URL]) -> [NieuwBestand] {
        var resultaat: [NieuwBestand] = []
        var mislukt: [String] = []
        for url in urls {
            let toegang = url.startAccessingSecurityScopedResource()
            defer { if toegang { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), (try? DocumentAnalyse.basis(van: data)) != nil {
                resultaat.append(NieuwBestand(
                    data: data,
                    bestandsnaam: url.lastPathComponent,
                    titel: DocumentNamen.titel(uitBestandsnaam: url.lastPathComponent)
                ))
            } else {
                mislukt.append(url.lastPathComponent)
            }
        }
        if !mislukt.isEmpty {
            foutmelding = String(localized: "Deze bestanden konden niet worden geopend als PDF: \(mislukt.formatted(.list(type: .and))).")
        }
        return resultaat
    }

    /// Voegt documenten toe aan een naaste (na controle van de limiet) en start de tekstherkenning.
    /// - Returns: de nieuwe documenten, of een lege lijst als het niet mocht of mislukte.
    @discardableResult
    func voegDocumentenToe(_ bestanden: [NieuwBestand], aan naaste: Naaste, categorie: DocumentCategorie) -> [Document] {
        guard !bestanden.isEmpty, magDocumentToevoegen(bij: naaste, extra: bestanden.count) else { return [] }

        let nieuw = bestanden.map { bestand in
            let document = context.maak(Document.self, bij: naaste)
            document.naaste = naaste
            document.titel = bestand.titel
            document.categorieWaarde = categorie
            document.documentDatum = .now
            document.bestand = bestand.data
            document.bestandsnaam = bestand.bestandsnaam
            if let basis = try? DocumentAnalyse.basis(van: bestand.data) {
                document.paginas = Int16(clamping: basis.paginas)
                document.miniatuur = basis.miniatuur
            }
            document.ocrStatusWaarde = .wachtend
            return document
        }
        guard bewaar() else { return [] }
        nieuw.forEach(herkenTekst)
        return nieuw
    }

    /// Herkent de tekst van een document op de achtergrond en slaat die op.
    func herkenTekst(in document: Document) {
        guard let data = document.bestand, document.ocrStatusWaarde != .bezig else { return }
        document.ocrStatusWaarde = .bezig
        let objectID = document.objectID
        Task {
            let status: OCRStatus
            var tekst: String?
            do {
                tekst = try await DocumentAnalyse.tekst(van: data)
                status = .klaar
            } catch {
                status = .mislukt
            }
            // Het document kan inmiddels verwijderd zijn.
            guard let document = try? context.existingObject(with: objectID) as? Document, !document.isDeleted else { return }
            document.ocrTekst = tekst
            document.ocrStatusWaarde = status
            bewaar()
        }
    }

    /// Pakt documenten op die nog wachten, bijvoorbeeld omdat de app werd afgesloten
    /// tijdens het herkennen, of omdat ze op een ander toestel zijn toegevoegd.
    func herkenOpenstaandeDocumenten() {
        let request = Document.fetchRequest()
        request.predicate = NSPredicate(format: "ocrStatus == %@ OR ocrStatus == %@ OR ocrStatus == nil", OCRStatus.wachtend.rawValue, OCRStatus.bezig.rawValue)
        guard let documenten = try? context.fetch(request) else { return }
        for document in documenten where document.bestand != nil {
            // "bezig" uit een vorige sessie is blijven hangen: opnieuw beginnen.
            document.ocrStatusWaarde = .wachtend
            herkenTekst(in: document)
        }
    }
}
