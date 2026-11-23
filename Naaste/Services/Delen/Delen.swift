import CloudKit
import CoreData
import NaasteKit
import os

/// Delen van een naaste met familie via CloudKit (CKShare).
///
/// De eigenaar deelt een naaste; alles wat eronder hangt (documenten, zaken, taken …)
/// gaat mee. Deelnemers zien de naaste in hun gedeelde opslag. Er is geen eigen server:
/// iCloud regelt de uitnodiging en de synchronisatie.
@MainActor
final class Delen {
    enum Fout: LocalizedError {
        case geenICloud
        case geenOpslag

        var errorDescription: String? {
            switch self {
            case .geenICloud:
                String(localized: "Log in bij iCloud (Instellingen → je naam) om te kunnen delen. Delen werkt via je eigen iCloud.")
            case .geenOpslag:
                String(localized: "De gedeelde opslag is nog niet klaar. Probeer het straks opnieuw.")
            }
        }
    }

    /// Wie er meedoet, zonder de eigenaar.
    struct Deelnemer: Identifiable {
        let id: String
        let naam: String
        let status: CKShare.ParticipantAcceptanceStatus
        let magBewerken: Bool
    }

    let persistence: PersistenceController
    private let log = Logger(subsystem: "nl.naaste.app", category: "Delen")

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    var ckContainer: CKContainer { CKContainer(identifier: PersistenceController.cloudKitContainerID) }

    // MARK: Status

    /// De bestaande share van deze naaste, of `nil` als hij niet gedeeld is.
    func share(van naaste: Naaste) -> CKShare? {
        guard !persistence.isInMemory, !naaste.objectID.isTemporaryID else { return nil }
        do {
            return try persistence.container.fetchShares(matching: [naaste.objectID])[naaste.objectID]
        } catch {
            log.error("Shares ophalen mislukt: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// `true` als iemand anders deze naaste met jou deelt.
    func isDeelnemer(bij naaste: Naaste) -> Bool {
        persistence.staatInGedeeldeOpslag(naaste)
    }

    func deelnemers(van share: CKShare) -> [Deelnemer] {
        share.participants
            .filter { $0.role != .owner }
            .map { deelnemer in
                Deelnemer(
                    id: deelnemer.userIdentity.userRecordID?.recordName ?? UUID().uuidString,
                    naam: Self.naam(van: deelnemer),
                    status: deelnemer.acceptanceStatus,
                    magBewerken: deelnemer.permission == .readWrite
                )
            }
    }

    /// Naam van de eigenaar, voor "Gedeeld door Sanne".
    func eigenaarNaam(van share: CKShare) -> String {
        Self.naam(van: share.owner)
    }

    /// Telt mee voor de gratis limiet: iedereen behalve de eigenaar, ook openstaande uitnodigingen.
    /// Verwijderde uitnodigingen tellen niet.
    func aantalDeelnemers(van share: CKShare?) -> Int {
        share?.participants.filter { $0.role != .owner && $0.acceptanceStatus != .removed }.count ?? 0
    }

    private static func naam(van deelnemer: CKShare.Participant) -> String {
        if let onderdelen = deelnemer.userIdentity.nameComponents {
            let naam = PersonNameComponentsFormatter.localizedString(from: onderdelen, style: .default)
            if !naam.isEmpty { return naam }
        }
        return deelnemer.userIdentity.lookupInfo?.emailAddress
            ?? deelnemer.userIdentity.lookupInfo?.phoneNumber
            ?? String(localized: "Onbekend")
    }

    // MARK: Delen

    func controleerICloud() async throws {
        let status = try await ckContainer.accountStatus()
        guard status == .available else { throw Fout.geenICloud }
    }

    /// Geeft de bestaande share terug of maakt een nieuwe.
    func maakOfHaalShare(voor naaste: Naaste) async throws -> CKShare {
        if let bestaand = share(van: naaste) { return bestaand }
        try await controleerICloud()
        guard let privateStore = persistence.privateStore else { throw Fout.geenOpslag }

        let (_, share, _) = try await persistence.container.share([naaste], to: nil)
        share[CKShare.SystemFieldKey.title] = String(localized: "Zorgmap van \(naaste.weergaveNaam)")
        share.publicPermission = .none
        return try await persistence.container.persistUpdatedShare(share, in: privateStore)
    }

    // MARK: Stoppen

    /// Deelnemer: de gedeelde naaste verlaten en de lokale kopie weghalen.
    /// Eigenaar: delen stoppen én de gegevens van deze naaste overal verwijderen
    /// (dat is wat "alle gegevens wissen" nodig heeft; gewoon stoppen met delen
    /// gaat via het deelscherm van iOS en laat je eigen gegevens staan).
    func verwijderZone(van share: CKShare, eigenaar: Bool) async throws {
        let store = eigenaar ? persistence.privateStore : persistence.sharedStore
        guard let store else { throw Fout.geenOpslag }
        try await persistence.container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: store)
    }

    // MARK: Accepteren

    func accepteer(_ metadata: CKShare.Metadata) async throws {
        guard let sharedStore = persistence.sharedStore else { throw Fout.geenOpslag }
        _ = try await persistence.container.acceptShareInvitations(from: [metadata], into: sharedStore)
    }

    /// Alle shares waarin jij deelnemer bent.
    func gedeeldeShares() -> [CKShare] {
        guard let sharedStore = persistence.sharedStore, !persistence.isInMemory else { return [] }
        return (try? persistence.container.fetchShares(in: sharedStore)) ?? []
    }

    /// Alle shares die jij als eigenaar hebt aangemaakt.
    func eigenShares() -> [CKShare] {
        guard let privateStore = persistence.privateStore, !persistence.isInMemory else { return [] }
        return (try? persistence.container.fetchShares(in: privateStore)) ?? []
    }
}
