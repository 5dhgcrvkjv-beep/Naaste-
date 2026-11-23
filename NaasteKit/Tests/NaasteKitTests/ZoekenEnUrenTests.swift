import Foundation
import Testing
@testable import NaasteKit

@Suite("Zoeken")
struct ZoekenTests {
    @Test func hoofdlettersEnAccenten() {
        #expect(Zoeken.past("beschikking", in: ["BESCHIKKING Wmo"]))
        #expect(Zoeken.past("financien", in: [nil, "Financiën 2026"]))
        #expect(Zoeken.past("Café", in: ["cafe de hoek"]))
    }

    @Test func alleWoordenMoetenVoorkomen() {
        let velden = ["Beschikking", "huishoudelijke hulp gemeente Utrecht"]
        #expect(Zoeken.past("beschikking utrecht", in: velden))
        #expect(!Zoeken.past("beschikking amsterdam", in: velden))
        #expect(Zoeken.past("   ", in: velden))
    }

    @Test func fragment() {
        let tekst = "Geachte heer/mevrouw,\n\nHierbij ontvangt u de beschikking voor\nhuishoudelijke hulp, ingaande 1 januari."
        let f = Zoeken.fragment(voor: "beschikking", in: tekst, context: 10)
        #expect(f == "…u de beschikking voor…")
        #expect(Zoeken.fragment(voor: "niets", in: tekst) == nil)
        #expect(Zoeken.fragment(voor: "geachte", in: tekst, context: 6) == "Geachte…")
    }
}

@Suite("Bellen en mailen")
struct ContactLinksTests {
    @Test func telefoon() {
        #expect(ContactLinks.belURL("06 - 12 34 56 78")?.absoluteString == "tel:0612345678")
        #expect(ContactLinks.belURL("+31 (0)30 123 4567")?.absoluteString == "tel:+31301234567")
        #expect(ContactLinks.belURL("12") == nil)
        #expect(ContactLinks.belURL(nil) == nil)
        #expect(ContactLinks.belURL("") == nil)
    }

    @Test func mail() {
        #expect(ContactLinks.mailURL(" info@example.com ")?.absoluteString == "mailto:info@example.com")
        #expect(ContactLinks.mailURL("geen-adres") == nil)
        #expect(ContactLinks.mailURL("a@b") == nil)
        #expect(ContactLinks.mailURL("a b@c.nl") == nil)
    }
}

@Suite("Urenlogboek")
struct UrenRekenaarTests {
    let begin = Date(timeIntervalSince1970: 1_800_000_000)

    var regels: [UrenRegelData] {
        [
            .init(datum: begin, minuten: 90, persoonID: "a", persoonNaam: "Sanne", categorie: .administratie),
            .init(datum: begin.addingTimeInterval(3600), minuten: 30, persoonID: "b", persoonNaam: "Mark", categorie: .vervoer),
            .init(datum: begin.addingTimeInterval(7200), minuten: 60, persoonID: "a", persoonNaam: "Sanne", categorie: .vervoer),
            .init(datum: begin.addingTimeInterval(86_400 * 40), minuten: 120, persoonID: "b", persoonNaam: "Mark", categorie: .huishouden)
        ]
    }

    @Test func totaalEnPerPersoon() {
        #expect(UrenRekenaar.totaal(regels) == 300)
        let per = UrenRekenaar.perPersoon(regels)
        #expect(per.map(\.naam) == ["Mark", "Sanne"])
        #expect(per.map(\.minuten) == [150, 150].map { $0 })
        #expect(abs(per.map(\.aandeel).reduce(0, +) - 1) < 0.0001)
    }

    @Test func periode() {
        let maand = DateInterval(start: begin, duration: 86_400 * 30)
        #expect(UrenRekenaar.totaal(regels, periode: maand) == 180)
        let per = UrenRekenaar.perPersoon(regels, periode: maand)
        #expect(per.first?.naam == "Sanne")
        #expect(per.first?.minuten == 150)
    }

    @Test func perCategorie() {
        let cat = UrenRekenaar.perCategorie(regels)
        #expect(cat.map(\.categorie) == [.administratie, .vervoer, .huishouden])
        #expect(cat.map(\.minuten) == [90, 90, 120])
    }

    @Test func zonderPersoon() {
        let r = [UrenRegelData(datum: begin, minuten: 15, persoonID: nil, persoonNaam: "Onbekend", categorie: .overig)]
        #expect(UrenRekenaar.perPersoon(r).first?.id == UrenRekenaar.zonderPersoonID)
        #expect(UrenRekenaar.urenEnMinuten(135) == (2, 15))
        #expect(UrenRekenaar.urenEnMinuten(-5) == (0, 0))
    }
}

@Suite("Opgeslagen enums")
struct EnumTests {
    @Test func fallback() {
        #expect(ZaakStatus(opgeslagen: nil) == .voorbereiden)
        #expect(ZaakStatus(opgeslagen: "toekomstigeWaarde") == .voorbereiden)
        #expect(DocumentCategorie(opgeslagen: "wmo") == .wmo)
        #expect(Herhaling(opgeslagen: "") == .geen)
    }

    @Test func zaakStatusVervolg() {
        #expect(ZaakStatus.afgerond.vervolgStatussen.isEmpty)
        #expect(!ZaakStatus.afgerond.isLopend)
        for status in ZaakStatus.allCases where status != .afgerond {
            #expect(!status.vervolgStatussen.isEmpty, "\(status) moet een vervolgstap hebben")
            #expect(!status.vervolgStatussen.contains(status))
        }
    }
}
