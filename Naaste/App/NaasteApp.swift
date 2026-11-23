import SwiftUI

@main
struct NaasteApp: App {
    @State private var app: AppModel

    init() {
        let persistence = PersistenceController.shared
        _app = State(initialValue: AppModel(persistence: persistence, entitlements: EntitlementStore()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(\.managedObjectContext, app.persistence.viewContext)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        Group {
            if app.persistence.laadFout != nil {
                OpslagFoutView()
            } else {
                RootTabView()
            }
        }
        .sheet(item: $app.paywall) { aanleiding in
            PaywallView(aanleiding: aanleiding)
        }
        .task {
            app.entitlements.start()
        }
        .onChange(of: app.isPlus) {
            app.werkEigenaarStatusBij()
        }
        .alert(
            "Er ging iets mis",
            isPresented: Binding(get: { app.foutmelding != nil }, set: { if !$0 { app.foutmelding = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(app.foutmelding ?? "")
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Overzicht", systemImage: "house") {
                OverzichtView()
            }
            Tab("Documenten", systemImage: "doc.text") {
                DocumentenView()
            }
            Tab("Zaken", systemImage: "folder") {
                ZakenView()
            }
            Tab("Taken", systemImage: "checklist") {
                TakenView()
            }
            Tab("Instellingen", systemImage: "gearshape") {
                InstellingenView()
            }
        }
    }
}

/// Als de database niet geladen kan worden (bijv. iPhone vol). Geen crash, wel uitleg.
struct OpslagFoutView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Gegevens niet beschikbaar", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Naaste kan je gegevens nu niet openen. Maak wat opslagruimte vrij op je iPhone en start de app opnieuw. Je gegevens in iCloud blijven bewaard.")
        }
    }
}

/// Toont de inhoud voor de gekozen naaste, of een welkomstscherm als er nog geen naaste is.
struct MetGeselecteerdeNaaste<Inhoud: View>: View {
    @FetchRequest(fetchRequest: Naaste.alle()) private var naasten: FetchedResults<Naaste>
    @AppStorage(Opslagsleutel.geselecteerdeNaaste) private var geselecteerdeID = ""
    private let inhoud: (Naaste) -> Inhoud

    init(@ViewBuilder inhoud: @escaping (Naaste) -> Inhoud) {
        self.inhoud = inhoud
    }

    var body: some View {
        if let naaste = huidige {
            inhoud(naaste)
        } else {
            GeenNaasteView()
        }
    }

    private var huidige: Naaste? {
        naasten.first { $0.uuid?.uuidString == geselecteerdeID } ?? naasten.first
    }
}
