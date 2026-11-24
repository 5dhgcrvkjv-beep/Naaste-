import LocalAuthentication
import SwiftUI
import UIKit

/// Vergrendelt de app met Face ID, Touch ID of de toegangscode.
///
/// - Zodra de app niet meer actief is (app-kiezer, Bericht­geving), dekt een scherm de inhoud af.
/// - Gaat de app naar de achtergrond, dan moet je daarna opnieuw ontgrendelen.
///
/// Het afdekscherm is een eigen venster boven alles, zodat ook geopende bladen
/// (zoals een document of de scanner) verborgen worden.
@MainActor
@Observable
final class Vergrendeling {
    static let shared = Vergrendeling()

    enum Methode {
        case faceID, touchID, opticID, toegangscode, geen
    }

    /// Instelling van de gebruiker (alleen op deze iPhone, niet via iCloud).
    private(set) var aan: Bool
    /// `true` zolang de gebruiker nog moet ontgrendelen.
    private(set) var vergrendeld: Bool
    private(set) var bezig = false
    /// Waarom het ontgrendelen mislukte, voor op het afdekscherm.
    private(set) var melding: String?

    @ObservationIgnored private var venster: UIWindow?
    @ObservationIgnored private var waarnemers: [NSObjectProtocol] = []

    private init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-vergrendel") {
            UserDefaults.standard.set(true, forKey: Opslagsleutel.vergrendeling)
        }
        #endif
        let aan = UserDefaults.standard.bool(forKey: Opslagsleutel.vergrendeling)
        self.aan = aan
        self.vergrendeld = aan
        luister()
    }

    // MARK: Methode

    /// Wat dit toestel kan. `.geen` als er geen toegangscode is ingesteld.
    var methode: Methode {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return .geen }
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .toegangscode
        }
    }

    var methodeNaam: String {
        switch methode {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        case .toegangscode, .geen: String(localized: "toegangscode")
        }
    }

    var methodeSymbool: String {
        switch methode {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .toegangscode, .geen: "lock"
        }
    }

    // MARK: Aan en uit

    /// Zet de vergrendeling aan of uit. Vraagt eerst om Face ID, zodat niemand anders
    /// hem stilletjes kan uitzetten of je jezelf buitensluit. Geeft `true` terug als het gelukt is.
    @discardableResult
    func zet(aan nieuw: Bool) async -> Bool {
        guard nieuw != aan else { return true }
        let reden = nieuw
            ? String(localized: "Bevestig om de vergrendeling aan te zetten.")
            : String(localized: "Bevestig om de vergrendeling uit te zetten.")
        let gelukt = await controleer(reden: reden)
        if gelukt {
            aan = nieuw
            vergrendeld = false
            UserDefaults.standard.set(nieuw, forKey: Opslagsleutel.vergrendeling)
        }
        // Het Face ID-venster maakte de app even inactief; het afdekscherm weer weghalen.
        werkVensterBij(actief: true)
        return gelukt
    }

    // MARK: Ontgrendelen

    func ontgrendel() async {
        guard vergrendeld, !bezig else { return }
        melding = nil
        if await controleer(reden: String(localized: "Ontgrendel Naaste om je gegevens te zien.")) {
            vergrendeld = false
            werkVensterBij(actief: true)
            Navigatie.shared.gaVerderNaOntgrendelen()
        }
    }

    private func controleer(reden: String) async -> Bool {
        bezig = true
        defer { bezig = false }
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Annuleer")
        var fout: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &fout) else {
            melding = String(localized: "Stel eerst een toegangscode in op je iPhone (Instellingen → Face ID en toegangscode).")
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reden)
        } catch let fout as LAError where fout.code == .userCancel || fout.code == .appCancel || fout.code == .systemCancel {
            return false
        } catch {
            melding = String(localized: "Ontgrendelen is niet gelukt. Probeer het opnieuw.")
            return false
        }
    }

    // MARK: Scene-levenscyclus

    /// Aanroepen zodra er een scene is, zodat het afdekscherm er vanaf het begin ligt.
    func koppel(_ scene: UIWindowScene) {
        guard venster == nil else { return }
        let venster = UIWindow(windowScene: scene)
        venster.windowLevel = .alert + 1
        let host = UIHostingController(rootView: VergrendelScherm(vergrendeling: self))
        host.view.backgroundColor = .clear
        venster.rootViewController = host
        venster.backgroundColor = .clear
        self.venster = venster
        werkVensterBij(actief: false)
    }

    private func luister() {
        let centrum = NotificationCenter.default
        waarnemers = [
            centrum.addObserver(forName: UIScene.willDeactivateNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.werkVensterBij(actief: false) }
            },
            centrum.addObserver(forName: UIScene.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.aan else { return }
                    self.vergrendeld = true
                    self.werkVensterBij(actief: false)
                }
            },
            centrum.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    // Het Face ID-venster zelf maakt de app ook even inactief; dan niets doen.
                    guard !self.bezig else { return }
                    self.werkVensterBij(actief: true)
                    if self.vergrendeld { Task { await self.ontgrendel() } }
                }
            }
        ]
    }

    /// Toont het afdekscherm als de app vergrendeld is, of (met vergrendeling aan) niet actief.
    private func werkVensterBij(actief: Bool) {
        guard let venster else { return }
        let tonen = aan && (vergrendeld || !actief)
        if tonen {
            venster.isHidden = false
        } else if !venster.isHidden {
            venster.isHidden = true
        }
    }
}

/// Wat je ziet als Naaste vergrendeld of afgedekt is.
struct VergrendelScherm: View {
    let vergrendeling: Vergrendeling

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Group {
                    if vergrendeling.vergrendeld {
                        Text("Naaste is vergrendeld")
                    } else {
                        Text(verbatim: "Naaste")
                    }
                }
                .font(.title2.bold())
                if vergrendeling.vergrendeld {
                    if let melding = vergrendeling.melding {
                        Text(melding)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Button {
                        Task { await vergrendeling.ontgrendel() }
                    } label: {
                        Label("Ontgrendel met \(vergrendeling.methodeNaam)", systemImage: vergrendeling.methodeSymbool)
                            .padding(.horizontal, 8)
                    }
                    .hoofdknop()
                    .controlSize(.large)
                    .disabled(vergrendeling.bezig)
                }
            }
            .padding(32)
        }
    }
}
