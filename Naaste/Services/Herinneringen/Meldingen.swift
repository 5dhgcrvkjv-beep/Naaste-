import Foundation
import NaasteKit
import UserNotifications

/// Lokale meldingen voor herinneringen en vervolgdatums van zaken.
///
/// Alles wordt op het toestel gepland (geen server, geen push). Bij elke wijziging
/// worden de wachtende meldingen opnieuw berekend, want iOS bewaart er maximaal 64.
@MainActor
@Observable
final class Meldingen: NSObject {
    /// Eén planbaar onderwerp met de tekst die in de melding komt.
    struct Onderwerp {
        let planbaar: PlanbareHerinnering
        let titel: String
        let naaste: String?
    }

    enum Toestemming {
        case onbekend, toegestaan, geweigerd
    }

    private(set) var toestemming: Toestemming = .onbekend
    private let centrum: UNUserNotificationCenter
    private var planTaak: Task<Void, Never>?

    init(centrum: UNUserNotificationCenter = .current()) {
        self.centrum = centrum
        super.init()
        centrum.delegate = self
    }

    // MARK: Toestemming

    func werkToestemmingBij() async {
        let instellingen = await centrum.notificationSettings()
        toestemming = switch instellingen.authorizationStatus {
        case .authorized, .provisional, .ephemeral: .toegestaan
        case .denied: .geweigerd
        default: .onbekend
        }
    }

    /// Vraagt toestemming als dat nog niet gebeurd is. Alleen aanroepen na een bewuste
    /// actie, zoals het bewaren van een herinnering.
    func vraagToestemmingAlsNodig() async {
        await werkToestemmingBij()
        guard toestemming == .onbekend else { return }
        _ = try? await centrum.requestAuthorization(options: [.alert, .sound, .badge])
        await werkToestemmingBij()
    }

    // MARK: Plannen

    /// Plant opnieuw, een halve seconde na de laatste aanroep (meerdere wijzigingen achter elkaar = één keer plannen).
    func planUitgesteld(_ onderwerpen: @escaping @MainActor () -> [Onderwerp]) {
        planTaak?.cancel()
        planTaak = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await plan(onderwerpen())
        }
    }

    func plan(_ onderwerpen: [Onderwerp], nu: Date = .now) async {
        await werkToestemmingBij()
        centrum.removeAllPendingNotificationRequests()
        guard toestemming == .toegestaan else { return }

        let perID = Dictionary(onderwerpen.map { ($0.planbaar.id, $0) }, uniquingKeysWith: { a, _ in a })
        let meldingen = ReminderPlanner().plan(onderwerpen.map(\.planbaar), nu: nu)
        for melding in meldingen {
            guard let onderwerp = perID[melding.herinneringID] else { continue }
            let tekst = MeldingTekst.maak(
                onderwerp: onderwerp.titel,
                naaste: onderwerp.naaste,
                melding: melding,
                heeftTijd: onderwerp.planbaar.heeftTijd
            )
            let inhoud = UNMutableNotificationContent()
            inhoud.title = tekst.titel
            inhoud.body = tekst.tekst
            inhoud.sound = .default
            inhoud.threadIdentifier = melding.herinneringID.uuidString

            let onderdelen = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: melding.moment)
            let trigger = UNCalendarNotificationTrigger(dateMatching: onderdelen, repeats: false)
            try? await centrum.add(UNNotificationRequest(identifier: melding.id, content: inhoud, trigger: trigger))
        }
    }
}

extension Meldingen: UNUserNotificationCenterDelegate {
    /// Ook een melding tonen als de app open staat.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
