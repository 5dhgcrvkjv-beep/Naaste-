import CoreData
import NaasteKit
import SwiftUI

/// Waarom de paywall wordt getoond. De paywall verschijnt alleen na een bewuste actie
/// van de gebruiker (tik op een Plus-functie of op "Naaste Plus" in Instellingen).
enum PaywallAanleiding: Identifiable, Equatable {
    case limiet(Limiet)
    case functie(PlusFunctie)
    case handmatig

    var id: String {
        switch self {
        case let .limiet(l): "limiet-\(l)"
        case let .functie(f): "functie-\(f.rawValue)"
        case .handmatig: "handmatig"
        }
    }
}

/// Centrale app-toestand: opslag, abonnement, limieten en meldingen.
@MainActor
@Observable
final class AppModel {
    let persistence: PersistenceController
    let entitlements: EntitlementStore
    let meldingen: Meldingen
    let delen: Delen

    var paywall: PaywallAanleiding?
    var foutmelding: String?

    init(persistence: PersistenceController, entitlements: EntitlementStore, meldingen: Meldingen? = nil) {
        self.persistence = persistence
        self.entitlements = entitlements
        self.meldingen = meldingen ?? Meldingen()
        self.delen = Delen(persistence: persistence)
    }

    var context: NSManagedObjectContext { persistence.viewContext }
    var isPlus: Bool { entitlements.isPlus }

    // MARK: - Limieten

    /// Regels voor een naaste. Bij een met jou gedeelde naaste telt (ook) het abonnement van de eigenaar.
    func policy(voor naaste: Naaste?) -> LimitPolicy {
        let eigenaarPlus = naaste.map { persistence.staatInGedeeldeOpslag($0) && $0.eigenaarHeeftPlus } ?? false
        return LimitPolicy(isPlus: isPlus || eigenaarPlus)
    }

    /// Controleert of er een naaste bij mag; toont anders de uitleg over Plus.
    func magNaasteToevoegen() -> Bool {
        let uitkomst = LimitPolicy(isPlus: isPlus).naasteToevoegen(huidigAantalEigen: persistence.aantalEigenNaasten())
        return toegestaan(uitkomst)
    }

    /// - Parameter extra: aantal documenten dat tegelijk wordt toegevoegd.
    func magDocumentToevoegen(bij naaste: Naaste, extra: Int = 1) -> Bool {
        if naaste.isVoorbeeld { return true }
        let policy = policy(voor: naaste)
        let huidig = persistence.staatInGedeeldeOpslag(naaste)
            ? persistence.aantalDocumenten(van: naaste)
            : persistence.aantalEigenDocumenten()
        return toegestaan(policy.documentToevoegen(huidigAantal: huidig, extra: extra))
    }

    func resterendeDocumenten(bij naaste: Naaste) -> Int? {
        if naaste.isVoorbeeld { return nil }
        let huidig = persistence.staatInGedeeldeOpslag(naaste)
            ? persistence.aantalDocumenten(van: naaste)
            : persistence.aantalEigenDocumenten()
        return policy(voor: naaste).resterendeDocumenten(huidigAantal: huidig)
    }

    func heeftToegang(tot functie: PlusFunctie, bij naaste: Naaste?) -> Bool {
        if naaste?.isVoorbeeld == true { return true }
        return policy(voor: naaste).heeftToegang(tot: functie)
    }

    /// Opent Plus-uitleg als de functie niet beschikbaar is. Geeft `true` terug als de functie mag.
    func vraagToegang(tot functie: PlusFunctie, bij naaste: Naaste?) -> Bool {
        if heeftToegang(tot: functie, bij: naaste) { return true }
        paywall = .functie(functie)
        return false
    }

    private func toegestaan(_ uitkomst: LimietUitkomst) -> Bool {
        if case let .limietBereikt(limiet) = uitkomst {
            paywall = .limiet(limiet)
            return false
        }
        return true
    }

    // MARK: - Opslaan

    /// Slaat op en toont een begrijpelijke melding als dat niet lukt.
    @discardableResult
    func bewaar() -> Bool {
        do {
            try persistence.bewaar()
            planMeldingen()
            return true
        } catch {
            foutmelding = String(localized: "Je wijziging kon niet worden opgeslagen. Probeer het opnieuw. Blijft dit gebeuren, controleer dan of er genoeg opslagruimte vrij is op je iPhone.")
            return false
        }
    }

    // MARK: - Voorbeeld

    @discardableResult
    func laadVoorbeeld() -> Naaste? {
        if let bestaand = persistence.voorbeeldNaasten().first { return bestaand }
        let naaste = VoorbeeldData.maak(in: context)
        return bewaar() ? naaste : nil
    }

    func verwijderVoorbeeld() {
        for naaste in persistence.voorbeeldNaasten() {
            context.delete(naaste)
        }
        bewaar()
    }

    /// Laat eigen naasten weten of de eigenaar Plus heeft, zodat familieleden met wie
    /// gedeeld wordt dezelfde mogelijkheden krijgen.
    func werkEigenaarStatusBij() {
        let request = Naaste.fetchRequest()
        if let store = persistence.privateStore { request.affectedStores = [store] }
        guard let eigen = try? context.fetch(request) else { return }
        var gewijzigd = false
        for naaste in eigen where naaste.eigenaarHeeftPlus != isPlus {
            naaste.eigenaarHeeftPlus = isPlus
            gewijzigd = true
        }
        if gewijzigd { bewaar() }
    }
}
