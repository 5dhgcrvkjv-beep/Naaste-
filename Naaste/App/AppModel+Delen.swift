import CloudKit
import CoreData
import NaasteKit
import UserNotifications

/// Delen met familie en alle gegevens wissen.
extension AppModel {
    /// Opent het deelscherm van iOS. `uitnodigen` = er komt (mogelijk) iemand bij,
    /// dan geldt de gratis limiet van 1 persoon.
    func openDelen(_ naaste: Naaste, uitnodigen: Bool, klaar: @escaping () -> Void = {}) {
        guard !naaste.isVoorbeeld else { return }
        let eigenaar = !delen.isDeelnemer(bij: naaste)
        if eigenaar && uitnodigen {
            let huidig = delen.aantalDeelnemers(van: delen.share(van: naaste))
            guard deelLimietToegestaan(policy(voor: naaste).deelnemerToevoegen(huidigAantalDeelnemers: huidig)) else { return }
        }
        Task {
            do {
                let share = try await delen.maakOfHaalShare(voor: naaste)
                DeelScherm.toon(share: share, container: delen.ckContainer, titel: naaste.weergaveNaam) { [self] gestopt, fout in
                    // AppModel leeft zo lang als de app; een sterke verwijzing is hier veilig.
                    if let fout {
                        foutmelding = String(localized: "Delen is niet gelukt: \(fout.localizedDescription)")
                    } else if !gestopt, eigenaar {
                        controleerDeelLimiet(naaste)
                    } else if gestopt, !eigenaar {
                        // Deelnemer koos "Verwijder mij": ook de lokale kopie weghalen.
                        Task { try? await self.delen.verwijderZone(van: share, eigenaar: false) }
                    }
                    klaar()
                }
            } catch {
                foutmelding = (error as? LocalizedError)?.errorDescription
                    ?? String(localized: "Delen is niet gelukt. Controleer je internetverbinding en of je bent ingelogd bij iCloud.")
                klaar()
            }
        }
    }

    /// Het deelscherm van iOS laat meerdere mensen tegelijk uitnodigen; achteraf
    /// wijzen we erop als dat boven de gratis limiet uitkomt.
    private func controleerDeelLimiet(_ naaste: Naaste) {
        let aantal = delen.aantalDeelnemers(van: delen.share(van: naaste))
        let policy = policy(voor: naaste)
        if !policy.isPlus && aantal > LimitPolicy.gratisMaxDeelnemers {
            paywall = .limiet(.deelnemers(max: LimitPolicy.gratisMaxDeelnemers))
        }
    }

    private func deelLimietToegestaan(_ uitkomst: LimietUitkomst) -> Bool {
        if case let .limietBereikt(limiet) = uitkomst {
            paywall = .limiet(limiet)
            return false
        }
        return true
    }

    /// Deelnemer: deze gedeelde naaste verlaten. De eigenaar en anderen houden hun gegevens.
    func verlaat(_ naaste: Naaste) async -> Bool {
        guard delen.isDeelnemer(bij: naaste), let share = delen.share(van: naaste) else { return false }
        do {
            try await delen.verwijderZone(van: share, eigenaar: false)
            return true
        } catch {
            foutmelding = String(localized: "Verlaten is niet gelukt. Controleer je internetverbinding en probeer het opnieuw.")
            return false
        }
    }

    // MARK: Alles wissen

    static let alleEntiteiten = ["ZaakGebeurtenis", "Herinnering", "Urenregel", "Taak", "Zaak", "Document", "Contactpersoon", "Familielid", "Naaste"]

    /// Wist alle gegevens van deze gebruiker:
    /// - gedeelde naasten van anderen worden verlaten (hun gegevens blijven bij hen);
    /// - eigen naasten worden verwijderd, ook uit iCloud en bij familie met wie je deelde;
    /// - meldingen en lokale voorkeuren worden gewist.
    /// Het abonnement loopt via Apple en blijft bestaan.
    func wisAlleGegevens() async -> Bool {
        var gelukt = true
        for share in delen.gedeeldeShares() {
            do { try await delen.verwijderZone(van: share, eigenaar: false) } catch { gelukt = false }
        }
        for share in delen.eigenShares() {
            do { try await delen.verwijderZone(van: share, eigenaar: true) } catch { gelukt = false }
        }

        // Alles wat nog in de privé-opslag staat (niet gedeeld, of nog niet gesynchroniseerd).
        for entiteit in Self.alleEntiteiten {
            let request = NSFetchRequest<NSManagedObject>(entityName: entiteit)
            if let store = persistence.privateStore { request.affectedStores = [store] }
            for object in (try? context.fetch(request)) ?? [] {
                context.delete(object)
            }
        }
        if !bewaar() { gelukt = false }

        let centrum = UNUserNotificationCenter.current()
        centrum.removeAllPendingNotificationRequests()
        centrum.removeAllDeliveredNotifications()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Opslagsleutel.geselecteerdeNaaste)
        for sleutel in defaults.dictionaryRepresentation().keys where sleutel.hasPrefix("ikBen-") {
            defaults.removeObject(forKey: sleutel)
        }
        return gelukt
    }
}
