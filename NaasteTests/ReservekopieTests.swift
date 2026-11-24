import CoreData
import Testing
@testable import NaasteApp

@MainActor
@Suite("Reservekopie")
struct ReservekopieTests {
    private func vulBron(_ persistence: PersistenceController) throws -> (naaste: Naaste, pdf: Data) {
        let context = persistence.viewContext
        let naaste = Naaste(context: context)
        naaste.naam = "Riet"
        let lid = Familielid(context: context)
        lid.naam = "Sanne"
        lid.naaste = naaste
        let taak = Taak(context: context)
        taak.titel = "Rollator ophalen"
        taak.naaste = naaste
        taak.toegewezenAan = lid
        let pdf = Data((0..<5000).map { UInt8($0 % 251) })
        let document = Document(context: context)
        document.titel = "Beschikking Wmo"
        document.bestand = pdf
        document.naaste = naaste
        let zaak = Zaak(context: context)
        zaak.titel = "Huishoudelijke hulp"
        zaak.naaste = naaste
        zaak.mutableSetValue(forKey: "documenten").add(document)
        let gebeurtenis = ZaakGebeurtenis(context: context)
        gebeurtenis.tekst = "Gebeld met de gemeente"
        gebeurtenis.setValue(zaak, forKey: "zaak")
        _ = VoorbeeldData.maak(in: context)
        try persistence.bewaar()
        return (naaste, pdf)
    }

    private func aantal(_ entiteit: String, in persistence: PersistenceController) throws -> Int {
        try persistence.viewContext.count(for: NSFetchRequest<NSManagedObject>(entityName: entiteit))
    }

    @Test func heenEnTerug() throws {
        let bron = PersistenceController(inMemory: true)
        let (origineel, pdf) = try vulBron(bron)
        let kopie = try Reservekopie.maak(uit: bron.viewContext, opslag: bron.privateStore)
        #expect(kopie.samenvatting.naasten == 1) // zonder de voorbeeld-naaste
        #expect(kopie.samenvatting.documenten == 1)

        let doel = PersistenceController(inMemory: true)
        let terug = try Reservekopie.zetTerug(kopie.data, in: doel.viewContext, opslag: doel.privateStore)
        try doel.bewaar()
        #expect(terug == Reservekopie.Samenvatting(naasten: 1, documenten: 1, overig: 4, overgeslagen: 0))

        let naaste = try #require(try doel.viewContext.fetch(NSFetchRequest<Naaste>(entityName: "Naaste")).first)
        #expect(naaste.uuid == origineel.uuid)
        #expect(naaste.naam == "Riet")
        #expect(!naaste.isVoorbeeld)
        let taak = try #require(try doel.viewContext.fetch(NSFetchRequest<Taak>(entityName: "Taak")).first)
        #expect(taak.toegewezenAan?.naam == "Sanne")
        #expect(taak.naaste == naaste)
        let document = try #require(try doel.viewContext.fetch(NSFetchRequest<Document>(entityName: "Document")).first)
        #expect(document.bestand == pdf)
        let zaak = try #require(try doel.viewContext.fetch(NSFetchRequest<Zaak>(entityName: "Zaak")).first)
        #expect((zaak.value(forKey: "documenten") as? Set<NSManagedObject>)?.count == 1)
        #expect((zaak.value(forKey: "gebeurtenissen") as? Set<NSManagedObject>)?.count == 1)
    }

    @Test func tweeKeerTerugzettenGeeftGeenDubbele() throws {
        let bron = PersistenceController(inMemory: true)
        _ = try vulBron(bron)
        let data = try Reservekopie.maak(uit: bron.viewContext, opslag: bron.privateStore).data

        // Terugzetten op dezelfde iPhone: alles staat er al.
        let terug = try Reservekopie.zetTerug(data, in: bron.viewContext, opslag: bron.privateStore)
        try bron.bewaar()
        #expect(terug.naasten == 0 && terug.documenten == 0 && terug.overig == 0)
        #expect(terug.overgeslagen == 6)
        #expect(try aantal("Taak", in: bron) >= 1)
        let echteNaasten = try bron.viewContext.count(for: {
            let r = NSFetchRequest<NSManagedObject>(entityName: "Naaste")
            r.predicate = NSPredicate(format: "isVoorbeeld == NO")
            return r
        }())
        #expect(echteNaasten == 1)
    }

    @Test func onbekendBestandGeeftFout() throws {
        let doel = PersistenceController(inMemory: true)
        #expect(throws: Reservekopie.Fout.self) {
            _ = try Reservekopie.zetTerug(Data("geen kopie".utf8), in: doel.viewContext, opslag: doel.privateStore)
        }
        let anderPlist = try PropertyListSerialization.data(fromPropertyList: ["formaat": "iets anders"], format: .binary, options: 0)
        #expect(throws: Reservekopie.Fout.self) {
            _ = try Reservekopie.zetTerug(anderPlist, in: doel.viewContext, opslag: doel.privateStore)
        }
        #expect(try aantal("Naaste", in: doel) == 0)
    }

    @Test func metWachtwoord() throws {
        let bron = PersistenceController(inMemory: true)
        _ = try vulBron(bron)
        let data = try Reservekopie.maak(uit: bron.viewContext, opslag: bron.privateStore, wachtwoord: "geheim123", rondes: 1000).data
        #expect(Reservekopie.isVersleuteld(data))
        // De inhoud is niet leesbaar zonder wachtwoord.
        #expect(data.range(of: Data("Riet".utf8)) == nil)

        let doel = PersistenceController(inMemory: true)
        #expect(throws: Reservekopie.Fout.wachtwoordNodig) {
            _ = try Reservekopie.zetTerug(data, in: doel.viewContext, opslag: doel.privateStore)
        }
        #expect(throws: Reservekopie.Fout.verkeerdWachtwoord) {
            _ = try Reservekopie.zetTerug(data, in: doel.viewContext, opslag: doel.privateStore, wachtwoord: "fout")
        }
        let terug = try Reservekopie.zetTerug(data, in: doel.viewContext, opslag: doel.privateStore, wachtwoord: "geheim123")
        #expect(terug.naasten == 1 && terug.documenten == 1)
    }

    @Test func zonderWachtwoordNietVersleuteld() throws {
        let bron = PersistenceController(inMemory: true)
        _ = try vulBron(bron)
        let data = try Reservekopie.maak(uit: bron.viewContext, opslag: bron.privateStore, wachtwoord: "").data
        #expect(!Reservekopie.isVersleuteld(data))
    }
}
