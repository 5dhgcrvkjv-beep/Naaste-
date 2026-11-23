import CoreData
import CoreGraphics
import NaasteKit
import Testing
@testable import NaasteApp

/// Tests voor het Core Data-model op een opslag in het geheugen (geen iCloud).
@MainActor
@Suite("Datamodel")
struct ModelTests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.viewContext }

    @Test func opslagLaadt() {
        #expect(persistence.laadFout == nil)
        #expect(persistence.privateStore != nil)
    }

    @Test func nieuwObjectKrijgtIDEnDatum() throws {
        let naaste = Naaste(context: context)
        naaste.naam = "Test"
        try persistence.bewaar()
        #expect(naaste.uuid != nil)
        #expect(naaste.aangemaakt != nil)
        #expect(naaste.isVoorbeeld == false)
    }

    @Test func verwijderenCascadeert() throws {
        let naaste = Naaste(context: context)
        let contact = Contactpersoon(context: context)
        contact.naaste = naaste
        let zaak = Zaak(context: context)
        zaak.naaste = naaste
        let gebeurtenis = ZaakGebeurtenis(context: context)
        gebeurtenis.zaak = zaak
        let lid = Familielid(context: context)
        lid.naaste = naaste
        let taak = Taak(context: context)
        taak.naaste = naaste
        taak.toegewezenAan = lid
        try persistence.bewaar()

        context.delete(naaste)
        try persistence.bewaar()

        for entiteit in ["Naaste", "Contactpersoon", "Zaak", "ZaakGebeurtenis", "Familielid", "Taak"] {
            let request = NSFetchRequest<NSManagedObject>(entityName: entiteit)
            #expect(try context.count(for: request) == 0, "\(entiteit) moet weg zijn")
        }
    }

    @Test func familielidVerwijderenLaatTaakStaan() throws {
        let naaste = Naaste(context: context)
        let lid = Familielid(context: context)
        lid.naaste = naaste
        let taak = Taak(context: context)
        taak.naaste = naaste
        taak.toegewezenAan = lid
        try persistence.bewaar()

        context.delete(lid)
        try persistence.bewaar()
        #expect(taak.isDeleted == false)
        #expect(taak.toegewezenAan == nil)
    }

    @Test func documentEnZaakVeelOpVeel() throws {
        let naaste = Naaste(context: context)
        let document = Document(context: context)
        document.naaste = naaste
        let zaakA = Zaak(context: context)
        let zaakB = Zaak(context: context)
        zaakA.naaste = naaste
        zaakB.naaste = naaste
        zaakA.mutableSetValue(forKey: "documenten").add(document)
        zaakB.mutableSetValue(forKey: "documenten").add(document)
        try persistence.bewaar()

        #expect(document.zakenLijst.count == 2)
        context.delete(zaakA)
        try persistence.bewaar()
        #expect(document.isDeleted == false)
        #expect(document.zakenLijst.count == 1)
    }

    @Test func statusWijzigingKomtInTijdlijn() throws {
        let zaak = Zaak(context: context)
        #expect(zaak.statusWaarde == .voorbereiden)
        zaak.zetStatus(.aangevraagd, door: "Sanne")
        #expect(zaak.statusWaarde == .aangevraagd)
        #expect(zaak.datumAangevraagd != nil)
        #expect(zaak.tijdlijn.count == 1)
        #expect(zaak.tijdlijn.first?.nieuweStatusWaarde == .aangevraagd)
        #expect(zaak.tijdlijn.first?.auteur == "Sanne")

        // Dezelfde status nogmaals zetten voegt niets toe.
        zaak.zetStatus(.aangevraagd, door: "Sanne")
        #expect(zaak.tijdlijn.count == 1)
    }

    @Test func onbekendeEnumWaardeValtTerug() {
        let document = Document(context: context)
        document.categorie = "bestaat-niet"
        #expect(document.categorieWaarde == .overig)
        document.categorieWaarde = .wmo
        #expect(document.categorie == "wmo")
    }

    @Test func voorbeeldDataIsCompleet() throws {
        let naaste = VoorbeeldData.maak(in: context)
        try persistence.bewaar()

        #expect(naaste.isVoorbeeld)
        #expect(naaste.contactenLijst.count >= 5)
        #expect(naaste.documentenLijst.count == 4)
        #expect(naaste.documentenLijst.allSatisfy { ($0.bestand?.count ?? 0) > 500 && $0.ocrStatusWaarde == .klaar })
        #expect(naaste.zakenLijst.count == 4)
        #expect(naaste.lopendeZaken.count == 3)
        #expect(naaste.familieledenLijst.count == 3)
        #expect(naaste.openTaken.count == 4)
        #expect(naaste.herinneringenLijst.count == 4)
        #expect(naaste.urenregelsLijst.count == 10)
    }

    @Test func voorbeeldTeltNietVoorLimieten() throws {
        VoorbeeldData.maak(in: context)
        try persistence.bewaar()
        #expect(persistence.aantalEigenNaasten() == 0)
        #expect(persistence.aantalEigenDocumenten() == 0)

        let eigen = Naaste(context: context)
        let document = Document(context: context)
        document.naaste = eigen
        try persistence.bewaar()
        #expect(persistence.aantalEigenNaasten() == 1)
        #expect(persistence.aantalEigenDocumenten() == 1)
    }

    @Test func zoekenInVoorbeelddocumenten() throws {
        let naaste = VoorbeeldData.maak(in: context)
        try persistence.bewaar()
        let treffers = naaste.documentenLijst.filter { Zoeken.past("svb", in: [$0.titel, $0.ocrTekst]) }
        #expect(treffers.map(\.titel) == ["Toekenning pgb dagbesteding"])
    }

    @Test func herinneringPlanbaar() {
        let herinnering = Herinnering(context: context)
        #expect(herinnering.planbaar == nil) // nog geen datum
        herinnering.datum = Date().addingTimeInterval(86_400 * 10)
        herinnering.herhalingWaarde = .maandelijks
        #expect(herinnering.dagenVooraf == 7) // standaardwaarde uit het model
        #expect(herinnering.planbaar?.herhaling == .maandelijks)
        #expect(herinnering.volgendeDatum() == herinnering.datum)
    }

    @Test func urenregelNaarData() {
        let lid = Familielid(context: context)
        lid.naam = "Mark"
        let regel = Urenregel(context: context)
        regel.familielid = lid
        regel.minuten = 90
        regel.categorieWaarde = .vervoer
        regel.datum = Date()
        #expect(regel.data.persoonNaam == "Mark")
        #expect(regel.data.persoonID == lid.uuid?.uuidString)
        #expect(UrenRekenaar.totaal([regel.data]) == 90)
    }

    @Test func pdfOpmaakMaaktGeldigePDF() {
        var opmaak = PDFOpmaak()
        opmaak.voettekst = "Test"
        opmaak.voegToe(.titel("Titel"))
        for i in 0..<120 { opmaak.voegToe(.veld(label: "Regel \(i)", waarde: "Waarde \(i)")) }
        let data = opmaak.maakPDF(titelMetadata: "Test")
        #expect(data.starts(with: Array("%PDF".utf8)))
        let document = CGPDFDocument(CGDataProvider(data: data as CFData)!)
        #expect((document?.numberOfPages ?? 0) >= 2) // automatische pagina-overgang
    }
}
