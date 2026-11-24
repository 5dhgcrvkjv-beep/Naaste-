import Foundation

extension AppModel {
    /// Maakt een reservekopie van de eigen naasten. `nil` bij een fout (melding wordt getoond).
    func maakReservekopie() -> (data: Data, samenvatting: Reservekopie.Samenvatting)? {
        do {
            return try Reservekopie.maak(uit: context, opslag: persistence.privateStore)
        } catch {
            foutmelding = String(localized: "De reservekopie kon niet worden gemaakt. Probeer het opnieuw.")
            return nil
        }
    }

    /// Zet een reservekopie terug en slaat op. Gooit een fout met uitleg voor de gebruiker.
    func zetReservekopieTerug(_ data: Data) throws -> Reservekopie.Samenvatting {
        let samenvatting: Reservekopie.Samenvatting
        do {
            samenvatting = try Reservekopie.zetTerug(data, in: context, opslag: persistence.privateStore)
            try persistence.bewaar()
        } catch {
            context.rollback()
            throw error
        }
        planMeldingen()
        herkenOpenstaandeDocumenten()
        return samenvatting
    }
}
