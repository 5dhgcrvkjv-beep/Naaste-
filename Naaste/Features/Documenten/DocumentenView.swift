import CoreData
import NaasteKit
import SwiftUI

/// Tabblad Documenten: mappen per categorie, recent toegevoegd en zoeken in alle tekst.
struct DocumentenView: View {
    var body: some View {
        NavigationStack {
            MetGeselecteerdeNaaste { naaste in
                DocumentenKluis(naaste: naaste)
                    .id(naaste.objectID)
            }
            .navigationTitle("Documenten")
        }
    }
}

private struct DocumentenKluis: View {
    @ObservedObject var naaste: Naaste
    @Environment(AppModel.self) private var app
    @FetchRequest private var documenten: FetchedResults<Document>
    @State private var zoekterm = ""

    init(naaste: Naaste) {
        self.naaste = naaste
        _documenten = FetchRequest(fetchRequest: Document.alle(voor: naaste))
    }

    var body: some View {
        List {
            if zoekterm.nietLeeg != nil {
                zoekresultaten
            } else {
                mappen
                recent
                limietUitleg
            }
        }
        .searchable(text: $zoekterm, prompt: "Zoek in titels en tekst")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                DocumentToevoegenKnop(naaste: naaste, categorie: .overig)
            }
        }
        .navigationDestination(for: DocumentCategorie.self) { categorie in
            DocumentMapView(naaste: naaste, categorie: categorie)
        }
        .navigationDestination(for: Document.self) { document in
            DocumentDetailView(document: document)
        }
        .overlay {
            if documenten.isEmpty && zoekterm.nietLeeg == nil {
                ContentUnavailableView {
                    Label("Nog geen documenten", systemImage: "doc.text")
                } description: {
                    Text("Scan een brief of importeer een PDF, zoals een beschikking van de gemeente of de polis van de zorgverzekering. Naaste leest de tekst, zodat je later kunt zoeken.")
                } actions: {
                    DocumentToevoegenKnop(naaste: naaste, categorie: .overig, groot: true)
                }
            }
        }
    }

    // MARK: Secties

    @ViewBuilder private var mappen: some View {
        if !documenten.isEmpty {
            Section("Mappen") {
                ForEach(DocumentCategorie.allCases) { categorie in
                    let aantal = documenten.filter { $0.categorieWaarde == categorie }.count
                    NavigationLink(value: categorie) {
                        Label {
                            HStack {
                                Text(categorie.titel)
                                Spacer()
                                Text(aantal, format: .number)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        } icon: {
                            Image(systemName: categorie.symbool)
                        }
                    }
                    .accessibilityLabel("\(categorie.titel), \(aantal) documenten")
                }
            }
        }
    }

    @ViewBuilder private var recent: some View {
        let laatste = documenten.sorted { ($0.aangemaakt ?? .distantPast) > ($1.aangemaakt ?? .distantPast) }.prefix(5)
        if !laatste.isEmpty {
            Section("Recent toegevoegd") {
                ForEach(Array(laatste)) { document in
                    NavigationLink(value: document) {
                        DocumentRij(document: document)
                    }
                }
            }
        }
    }

    @ViewBuilder private var limietUitleg: some View {
        if let resterend = app.resterendeDocumenten(bij: naaste), !documenten.isEmpty {
            Section {
            } footer: {
                Text("In de gratis versie kun je nog \(resterend) documenten toevoegen. Met Naaste Plus is dat onbeperkt.")
            }
        }
    }

    @ViewBuilder private var zoekresultaten: some View {
        let treffers = documenten.filter { document in
            Zoeken.past(zoekterm, in: [document.titel, document.ocrTekst, document.bestandsnaam, document.categorieWaarde.titel])
        }
        if treffers.isEmpty {
            ContentUnavailableView.search(text: zoekterm)
        } else {
            Section {
                ForEach(treffers) { document in
                    NavigationLink(value: document) {
                        DocumentRij(document: document, fragment: Zoeken.fragment(voor: zoekterm, in: document.ocrTekst))
                    }
                }
            } footer: {
                if documenten.contains(where: { $0.ocrStatusWaarde == .bezig || $0.ocrStatusWaarde == .wachtend }) {
                    Text("Bij sommige documenten wordt de tekst nog gelezen. Die verschijnen zo ook in de resultaten.")
                }
            }
        }
    }
}

/// Eén map (categorie) met de documenten erin.
struct DocumentMapView: View {
    @ObservedObject var naaste: Naaste
    let categorie: DocumentCategorie
    @FetchRequest private var documenten: FetchedResults<Document>

    init(naaste: Naaste, categorie: DocumentCategorie) {
        self.naaste = naaste
        self.categorie = categorie
        let request = Document.alle(voor: naaste)
        request.predicate = NSPredicate(format: "naaste == %@ AND categorie == %@", naaste, categorie.rawValue)
        _documenten = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        List {
            Section {
                ForEach(documenten) { document in
                    NavigationLink(value: document) {
                        DocumentRij(document: document, toonCategorie: false)
                    }
                }
            } footer: {
                Text(categorie.uitleg)
            }
        }
        .navigationTitle(categorie.titel)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                DocumentToevoegenKnop(naaste: naaste, categorie: categorie)
            }
        }
        .overlay {
            if documenten.isEmpty {
                ContentUnavailableView {
                    Label("Map is leeg", systemImage: categorie.symbool)
                } description: {
                    Text(categorie.uitleg)
                } actions: {
                    DocumentToevoegenKnop(naaste: naaste, categorie: categorie, groot: true)
                }
            }
        }
    }
}

/// Rij met miniatuur, titel, datum en eventueel een tekstfragment uit de zoekresultaten.
struct DocumentRij: View {
    @ObservedObject var document: Document
    var fragment: String?
    var toonCategorie = true

    var body: some View {
        HStack(spacing: 12) {
            Miniatuur(data: document.miniatuur)
                .frame(width: 44, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(document.weergaveTitel)
                    .font(.body)
                    .lineLimit(2)
                Text(onderregel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let fragment {
                    Text(fragment)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .italic()
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var onderregel: String {
        var delen: [String] = []
        if toonCategorie { delen.append(document.categorieWaarde.titel) }
        if let datum = document.documentDatum { delen.append(datum.kort) }
        if document.paginas > 1 { delen.append(String(localized: "\(Int(document.paginas)) pagina's")) }
        return delen.joined(separator: " · ")
    }
}

struct Miniatuur: View {
    let data: Data?

    var body: some View {
        Group {
            if let data, let beeld = UIImage(data: data) {
                Image(uiImage: beeld)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc.text")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.quaternary))
        .accessibilityHidden(true)
    }
}

/// "+"-knop met scannen en importeren. Na één nieuw document opent het formulier
/// om titel, map en datum te controleren.
struct DocumentToevoegenKnop: View {
    @ObservedObject var naaste: Naaste
    let categorie: DocumentCategorie
    var groot = false

    @Environment(AppModel.self) private var app
    @State private var scannen = false
    @State private var importeren = false
    @State private var controleren: Document?

    var body: some View {
        Menu {
            if DocumentScanner.isBeschikbaar {
                Button {
                    if app.magDocumentToevoegen(bij: naaste) { scannen = true }
                } label: {
                    Label("Scan een brief", systemImage: "doc.viewfinder")
                }
            }
            Button {
                if app.magDocumentToevoegen(bij: naaste) { importeren = true }
            } label: {
                Label("Importeer PDF uit Bestanden", systemImage: "folder")
            }
        } label: {
            if groot {
                Text("Document toevoegen")
                    .frame(minWidth: 220, minHeight: 34)
            } else {
                Label("Document toevoegen", systemImage: "plus")
            }
        }
        .modifier(KnopStijl(groot: groot))
        .fullScreenCover(isPresented: $scannen) {
            DocumentScanner { paginas in
                scannen = false
                guard !paginas.isEmpty, let bestand = app.bestand(vanScan: paginas) else { return }
                controleren = app.voegDocumentenToe([bestand], aan: naaste, categorie: categorie).first
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $importeren, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { resultaat in
            guard case let .success(urls) = resultaat else { return }
            let bestanden = app.bestanden(vanImport: urls)
            let nieuw = app.voegDocumentenToe(bestanden, aan: naaste, categorie: categorie)
            if nieuw.count == 1 { controleren = nieuw.first }
        }
        .sheet(item: $controleren) { document in
            DocumentBewerkenView(document: document, isNieuw: true)
        }
    }
}

private struct KnopStijl: ViewModifier {
    let groot: Bool

    func body(content: Content) -> some View {
        if groot {
            content.hoofdknop()
        } else {
            content
        }
    }
}
