import CoreData
import CoreTransferable
import NaasteKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// Een document bekijken, delen, wijzigen of verwijderen.
struct DocumentDetailView: View {
    @ObservedObject var document: Document
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var bewerken = false
    @State private var gegevens = false
    @State private var bevestigVerwijderen = false

    var body: some View {
        Group {
            if let data = document.bestand {
                PDFWeergave(data: data)
                    .ignoresSafeArea(edges: .bottom)
                    .accessibilityLabel(document.weergaveTitel)
            } else {
                ContentUnavailableView(
                    "Bestand nog niet binnen",
                    systemImage: "icloud.and.arrow.down",
                    description: Text("Dit document wordt nog uit iCloud gehaald. Controleer of je verbinding hebt.")
                )
            }
        }
        .navigationTitle(document.weergaveTitel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let data = document.bestand {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(
                        item: PDFExport(data: data, bestandsnaam: DocumentNamen.bestandsnaam(voorTitel: document.weergaveTitel)),
                        preview: SharePreview(document.weergaveTitel)
                    ) {
                        Label("Deel", systemImage: "square.and.arrow.up")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { bewerken = true } label: {
                        Label("Wijzig titel, map of datum", systemImage: "pencil")
                    }
                    Button { gegevens = true } label: {
                        Label("Gegevens en herkende tekst", systemImage: "text.viewfinder")
                    }
                    Button(role: .destructive) { bevestigVerwijderen = true } label: {
                        Label("Verwijder document", systemImage: "trash")
                    }
                } label: {
                    Label("Meer", systemImage: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $bewerken) {
            DocumentBewerkenView(document: document, isNieuw: false)
        }
        .sheet(isPresented: $gegevens) {
            DocumentGegevensView(document: document)
        }
        .confirmationDialog("Document verwijderen?", isPresented: $bevestigVerwijderen, titleVisibility: .visible) {
            Button("Verwijder", role: .destructive) {
                app.context.delete(document)
                if app.bewaar() { dismiss() }
            }
        } message: {
            Text("Het document verdwijnt ook bij familieleden met wie je deze naaste deelt.")
        }
    }
}

/// PDF delen als bestand met een nette naam.
struct PDFExport: Transferable {
    let data: Data
    let bestandsnaam: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { $0.data }
            .suggestedFileName { $0.bestandsnaam }
    }
}

/// PDFKit in SwiftUI: doorlopend scrollen, inzoomen met twee vingers.
struct PDFWeergave: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let weergave = PDFView()
        weergave.autoScales = true
        weergave.displayMode = .singlePageContinuous
        weergave.displayDirection = .vertical
        weergave.backgroundColor = .secondarySystemBackground
        weergave.document = PDFDocument(data: data)
        context.coordinator.data = data
        return weergave
    }

    func updateUIView(_ weergave: PDFView, context: Context) {
        // Alleen opnieuw laden als het bestand echt veranderd is (bijv. via iCloud).
        guard context.coordinator.data != data else { return }
        context.coordinator.data = data
        weergave.document = PDFDocument(data: data)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var data: Data?
    }
}

/// Map, datum, aantal pagina's en de tekst die Naaste heeft gelezen.
struct DocumentGegevensView: View {
    @ObservedObject var document: Document
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Map", value: document.categorieWaarde.titel)
                    if let datum = document.documentDatum {
                        LabeledContent("Datum", value: datum.formatted(date: .long, time: .omitted))
                    }
                    LabeledContent("Pagina's", value: document.paginas, format: .number)
                    if let naam = document.bestandsnaam?.nietLeeg {
                        LabeledContent("Bestand", value: naam)
                    }
                    if let toegevoegd = document.aangemaakt {
                        LabeledContent("Toegevoegd", value: toegevoegd.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                Section {
                    switch document.ocrStatusWaarde {
                    case .wachtend, .bezig:
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Naaste leest de tekst…")
                                .foregroundStyle(.secondary)
                        }
                    case .mislukt:
                        Text("De tekst kon niet worden gelezen.")
                            .foregroundStyle(.secondary)
                        Button("Probeer opnieuw") { app.herkenTekst(in: document) }
                    case .klaar, .nietNodig:
                        if let tekst = document.ocrTekst?.nietLeeg {
                            Text(tekst)
                                .font(.callout)
                                .textSelection(.enabled)
                        } else {
                            Text("Er is geen tekst gevonden in dit document.")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Herkende tekst")
                } footer: {
                    Text("De tekst wordt op je iPhone gelezen en alleen gebruikt om te zoeken. Er gaat niets naar een server.")
                }
            }
            .navigationTitle(document.weergaveTitel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
    }
}

/// Titel, map en datum van een document. Ook getoond direct na scannen of importeren.
struct DocumentBewerkenView: View {
    @ObservedObject var document: Document
    let isNieuw: Bool

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var titel = ""
    @State private var categorie: DocumentCategorie = .overig
    @State private var heeftDatum = true
    @State private var datum = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Miniatuur(data: document.miniatuur)
                            .frame(width: 60, height: 80)
                        TextField("Titel, bijv. Beschikking Wmo", text: $titel, axis: .vertical)
                            .font(.headline)
                            .lineLimit(1...3)
                    }
                }

                Section {
                    Picker("Map", selection: $categorie) {
                        ForEach(DocumentCategorie.allCases) { categorie in
                            Label(categorie.titel, systemImage: categorie.symbool).tag(categorie)
                        }
                    }
                } footer: {
                    Text(categorie.uitleg)
                }

                Section {
                    Toggle("Datum van de brief", isOn: $heeftDatum.animation())
                    if heeftDatum {
                        DatePicker("Datum", selection: $datum, displayedComponents: .date)
                    }
                } footer: {
                    Text("De datum op de brief zelf, zodat de nieuwste bovenaan staat.")
                }
            }
            .navigationTitle(isNieuw ? "Nieuw document" : "Wijzig document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isNieuw ? "Later" : "Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar", action: bewaar)
                }
            }
            .onAppear(perform: laad)
        }
        .interactiveDismissDisabled(!isNieuw)
    }

    private func laad() {
        titel = document.titel ?? ""
        categorie = document.categorieWaarde
        heeftDatum = document.documentDatum != nil
        datum = document.documentDatum ?? .now
    }

    private func bewaar() {
        document.titel = titel.nietLeeg
        document.categorieWaarde = categorie
        document.documentDatum = heeftDatum ? Calendar.current.startOfDay(for: datum) : nil
        document.gewijzigd = .now
        if app.bewaar() { dismiss() }
    }
}
