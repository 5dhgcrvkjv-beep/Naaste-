import UIKit

/// Eenvoudige, nette A4-PDF-opmaak met automatische pagina-overgangen.
/// Gebruikt voor het overdrachtsoverzicht, het urenrapport en de voorbeeld-documenten.
struct PDFOpmaak {
    enum Blok {
        case titel(String)
        case ondertitel(String)
        case kop(String)
        /// Vetgedrukte tussenkop; komt nooit los onderaan een pagina te staan.
        case subkop(String)
        case tekst(String)
        case kleineTekst(String)
        /// Label links, waarde rechts (bijv. "Telefoon   030 …").
        case veld(label: String, waarde: String)
        case opsomming([String])
        /// Tabel met kopregel; `breedtes` zijn relatieve kolombreedtes.
        case tabel(kop: [String], rijen: [[String]], breedtes: [CGFloat])
        case lijn
        case ruimte(CGFloat)
    }

    var blokken: [Blok] = []
    /// Klein grijs regeltje onderaan elke pagina.
    var voettekst: String = ""

    static let pagina = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 in punten
    static let marge: CGFloat = 48

    mutating func voegToe(_ blok: Blok) { blokken.append(blok) }

    func maakPDF(titelMetadata: String) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: titelMetadata,
            kCGPDFContextCreator as String: "Naaste"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: Self.pagina, format: format)
        return renderer.pdfData { context in
            var tekenaar = Tekenaar(context: context, voettekst: voettekst)
            tekenaar.nieuwePagina()
            for blok in blokken {
                tekenaar.teken(blok)
            }
            tekenaar.sluitPagina()
        }
    }

    // MARK: - Tekenen

    private struct Tekenaar {
        let context: UIGraphicsPDFRendererContext
        let voettekst: String
        var y: CGFloat = 0
        var paginaNummer = 0

        let breedte = PDFOpmaak.pagina.width - 2 * PDFOpmaak.marge
        let maxY = PDFOpmaak.pagina.height - PDFOpmaak.marge - 24
        let accent = UIColor(red: 0.18, green: 0.47, blue: 0.34, alpha: 1)

        init(context: UIGraphicsPDFRendererContext, voettekst: String) {
            self.context = context
            self.voettekst = voettekst
        }

        mutating func nieuwePagina() {
            context.beginPage()
            paginaNummer += 1
            y = PDFOpmaak.marge
        }

        func sluitPagina() {
            let stijl = attributen(grootte: 8.5, kleur: .gray)
            let links = NSAttributedString(string: voettekst, attributes: stijl)
            let rechts = NSAttributedString(string: String(localized: "Pagina \(paginaNummer)"), attributes: stijl)
            let voetY = PDFOpmaak.pagina.height - PDFOpmaak.marge + 8
            links.draw(with: CGRect(x: PDFOpmaak.marge, y: voetY, width: breedte - 80, height: 14), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
            let rechtsBreedte = rechts.size().width
            rechts.draw(at: CGPoint(x: PDFOpmaak.marge + breedte - rechtsBreedte, y: voetY))
        }

        mutating func ruimteNodig(_ hoogte: CGFloat) {
            if y + hoogte > maxY {
                sluitPagina()
                nieuwePagina()
            }
        }

        func attributen(grootte: CGFloat, gewicht: UIFont.Weight = .regular, kleur: UIColor = .black) -> [NSAttributedString.Key: Any] {
            let alinea = NSMutableParagraphStyle()
            alinea.lineBreakMode = .byWordWrapping
            alinea.lineSpacing = 2
            return [
                .font: UIFont.systemFont(ofSize: grootte, weight: gewicht),
                .foregroundColor: kleur,
                .paragraphStyle: alinea
            ]
        }

        func hoogte(_ tekst: NSAttributedString, breedte: CGFloat) -> CGFloat {
            ceil(tekst.boundingRect(with: CGSize(width: breedte, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
        }

        mutating func tekenTekst(_ tekst: NSAttributedString, x: CGFloat = PDFOpmaak.marge, breedte: CGFloat? = nil, naRuimte: CGFloat) {
            let b = breedte ?? self.breedte
            let h = hoogte(tekst, breedte: b)
            ruimteNodig(h)
            tekst.draw(with: CGRect(x: x, y: y, width: b, height: h), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            y += h + naRuimte
        }

        mutating func teken(_ blok: Blok) {
            switch blok {
            case let .titel(tekst):
                tekenTekst(NSAttributedString(string: tekst, attributes: attributen(grootte: 22, gewicht: .bold, kleur: accent)), naRuimte: 4)
            case let .ondertitel(tekst):
                tekenTekst(NSAttributedString(string: tekst, attributes: attributen(grootte: 11, kleur: .darkGray)), naRuimte: 14)
            case let .kop(tekst):
                ruimteNodig(110) // kop met minstens een tussenkop en een paar regels erna, niet los onderaan
                y += 8
                tekenTekst(NSAttributedString(string: tekst, attributes: attributen(grootte: 14, gewicht: .semibold, kleur: accent)), naRuimte: 6)
            case let .subkop(tekst):
                ruimteNodig(56)
                y += 4
                tekenTekst(NSAttributedString(string: tekst, attributes: attributen(grootte: 11.5, gewicht: .semibold)), naRuimte: 4)
            case let .tekst(tekst):
                tekenTekst(NSAttributedString(string: tekst, attributes: attributen(grootte: 10.5)), naRuimte: 8)
            case let .kleineTekst(tekst):
                tekenTekst(NSAttributedString(string: tekst, attributes: attributen(grootte: 8.5, kleur: .darkGray)), naRuimte: 6)
            case let .veld(label, waarde):
                let labelBreedte: CGFloat = 150
                let l = NSAttributedString(string: label, attributes: attributen(grootte: 10, kleur: .darkGray))
                let w = NSAttributedString(string: waarde, attributes: attributen(grootte: 10.5))
                let h = max(hoogte(l, breedte: labelBreedte - 8), hoogte(w, breedte: breedte - labelBreedte))
                ruimteNodig(h)
                l.draw(with: CGRect(x: PDFOpmaak.marge, y: y, width: labelBreedte - 8, height: h), options: [.usesLineFragmentOrigin], context: nil)
                w.draw(with: CGRect(x: PDFOpmaak.marge + labelBreedte, y: y, width: breedte - labelBreedte, height: h), options: [.usesLineFragmentOrigin], context: nil)
                y += h + 4
            case let .opsomming(items):
                for item in items {
                    let bullet = NSAttributedString(string: "•", attributes: attributen(grootte: 10.5, kleur: accent))
                    let t = NSAttributedString(string: item, attributes: attributen(grootte: 10.5))
                    let h = hoogte(t, breedte: breedte - 14)
                    ruimteNodig(h)
                    bullet.draw(at: CGPoint(x: PDFOpmaak.marge, y: y))
                    t.draw(with: CGRect(x: PDFOpmaak.marge + 14, y: y, width: breedte - 14, height: h), options: [.usesLineFragmentOrigin], context: nil)
                    y += h + 4
                }
                y += 4
            case let .tabel(kop, rijen, breedtes):
                let totaal = breedtes.reduce(0, +)
                let kolommen = breedtes.map { $0 / max(totaal, 1) * breedte }
                tekenRij(kop, kolommen: kolommen, vet: true)
                lijn(dikte: 0.8)
                for rij in rijen {
                    tekenRij(rij, kolommen: kolommen, vet: false)
                }
                y += 6
            case .lijn:
                lijn(dikte: 0.5)
                y += 6
            case let .ruimte(h):
                y += h
            }
        }

        mutating func tekenRij(_ cellen: [String], kolommen: [CGFloat], vet: Bool) {
            let stijl = attributen(grootte: vet ? 9.5 : 10, gewicht: vet ? .semibold : .regular, kleur: vet ? .darkGray : .black)
            let teksten = cellen.map { NSAttributedString(string: $0, attributes: stijl) }
            let h = zip(teksten, kolommen).map { hoogte($0, breedte: $1 - 6) }.max() ?? 12
            ruimteNodig(h + 6)
            var x = PDFOpmaak.marge
            for (tekst, kolom) in zip(teksten, kolommen) {
                tekst.draw(with: CGRect(x: x, y: y + 3, width: kolom - 6, height: h), options: [.usesLineFragmentOrigin], context: nil)
                x += kolom
            }
            y += h + 6
        }

        mutating func lijn(dikte: CGFloat) {
            let pad = UIBezierPath()
            pad.move(to: CGPoint(x: PDFOpmaak.marge, y: y))
            pad.addLine(to: CGPoint(x: PDFOpmaak.marge + breedte, y: y))
            pad.lineWidth = dikte
            UIColor.lightGray.setStroke()
            pad.stroke()
            y += 2
        }
    }
}
