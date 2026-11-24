import CoreData
import CoreSpotlight
import SwiftUI

@main
struct NaasteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var app: AppModel

    init() {
        #if DEBUG
        // `-toonOnboarding` laat de kennismaking opnieuw zien (voor testen en screenshots).
        if ProcessInfo.processInfo.arguments.contains("-toonOnboarding") {
            UserDefaults.standard.set(false, forKey: Opslagsleutel.onboardingKlaar)
        }
        #endif
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var geaccepteerd: String?
    @AppStorage(Opslagsleutel.onboardingKlaar) private var onboardingKlaar = false
    @FetchRequest(fetchRequest: Naaste.alle()) private var naasten: FetchedResults<Naaste>

    /// Alleen bij de eerste start en zolang er nog geen naaste is (ook niet via iCloud of delen).
    private var toonOnboarding: Binding<Bool> {
        Binding(
            get: { !onboardingKlaar && naasten.isEmpty && app.persistence.laadFout == nil },
            set: { if !$0 { onboardingKlaar = true } }
        )
    }

    var body: some View {
        @Bindable var app = app
        Group {
            if app.persistence.laadFout != nil {
                OpslagFoutView()
            } else {
                RootTabView()
            }
        }
        .fullScreenCover(isPresented: toonOnboarding) {
            OnboardingView()
        }
        .sheet(item: $app.paywall) { aanleiding in
            PaywallView(aanleiding: aanleiding)
        }
        .task {
            app.entitlements.start()
            app.herkenOpenstaandeDocumenten()
            app.planMeldingen()
            app.werkSpotlightBij()
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-laadVoorbeeld") {
                app.laadVoorbeeld()
            }
            // `-snelkoppeling nl.naaste.scan` doet alsof je een snelle actie op het app-icoon kiest.
            if let i = args.firstIndex(of: "-snelkoppeling"), i + 1 < args.count {
                Navigatie.shared.voerUit(UIApplicationShortcutItem(type: args[i + 1], localizedTitle: ""))
            }
            #endif
        }
        // Wijzigingen van familieleden (via iCloud) of een nieuwe dag: meldingen opnieuw plannen.
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            app.planMeldingen()
            app.werkSpotlightBij()
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activiteit in
            if let id = activiteit.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                Navigatie.shared.open(spotlightID: id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deelUitnodigingGeaccepteerd)) { bericht in
            let titel = bericht.object as? String ?? String(localized: "de zorgmap")
            app.foutmelding = nil
            geaccepteerd = String(localized: "Je doet nu mee met \(titel). Kies de naaste via het menu rechtsboven in Overzicht.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .deelUitnodigingMislukt)) { _ in
            app.foutmelding = String(localized: "De uitnodiging kon niet worden geopend. Controleer of je bent ingelogd bij iCloud en internet hebt, en open de link opnieuw.")
        }
        .alert("Welkom", isPresented: Binding(get: { geaccepteerd != nil }, set: { if !$0 { geaccepteerd = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(geaccepteerd ?? "")
        }
        .onChange(of: scenePhase) { _, fase in
            if fase == .active { app.planMeldingen() }
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

enum HoofdTab: String, Hashable {
    case overzicht, documenten, zaken, taken, instellingen
}

struct RootTabView: View {
    @Environment(AppModel.self) private var app
    @State private var tab: HoofdTab = Self.starttab
    @AppStorage(Opslagsleutel.geselecteerdeNaaste) private var geselecteerdeID = ""
    private let navigatie = Navigatie.shared

    var body: some View {
        TabView(selection: $tab) {
            Tab("Overzicht", systemImage: "house", value: .overzicht) {
                OverzichtView()
            }
            Tab("Documenten", systemImage: "doc.text", value: .documenten) {
                DocumentenView()
            }
            Tab("Zaken", systemImage: "folder", value: .zaken) {
                ZakenView()
            }
            Tab("Taken", systemImage: "checklist", value: .taken) {
                TakenView()
            }
            Tab("Instellingen", systemImage: "gearshape", value: .instellingen) {
                InstellingenView()
            }
        }
        .onChange(of: navigatie.open, initial: true) { _, bestemming in
            ga(naar: bestemming)
        }
    }

    /// Kiest het tabblad (en de naaste) bij een bestemming. Het tabblad zelf opent daarna het juiste scherm.
    private func ga(naar bestemming: Navigatie.Bestemming?) {
        guard let bestemming else { return }
        let naaste: Naaste?
        switch bestemming {
        case let .document(id):
            naaste = Navigatie.zoek(Document.self, uuid: id, in: app.context)?.naaste
            tab = .documenten
        case let .zaak(id):
            naaste = Navigatie.zoek(Zaak.self, uuid: id, in: app.context)?.naaste
            tab = .zaken
        case let .taak(id):
            naaste = Navigatie.zoek(Taak.self, uuid: id, in: app.context)?.naaste
            tab = .taken
        case .scan:
            naaste = nil
            tab = .documenten
        case .nieuweTaak, .uren:
            naaste = nil
            tab = .taken
        }
        if let id = naaste?.uuid?.uuidString { geselecteerdeID = id }
    }

    /// Alleen in DEBUG: `-startTab zaken` opent direct een tabblad (handig voor screenshots).
    private static var starttab: HoofdTab {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-startTab"), i + 1 < args.count,
           let tab = HoofdTab(rawValue: args[i + 1]) {
            return tab
        }
        #endif
        return .overzicht
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
