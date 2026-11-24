import NaasteKit
import StoreKit
import SwiftUI

/// Uitleg en aankoop van "Naaste Plus".
///
/// Toont altijd (App Store-richtlijn 3.1.2): naam van het abonnement, looptijd, prijs
/// (uit StoreKit, nooit hardcoded), wat je krijgt, automatische verlenging, hoe je opzegt,
/// links naar privacybeleid en gebruiksvoorwaarden, en "Aankopen herstellen".
struct PaywallView: View {
    let aanleiding: PaywallAanleiding

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: PlusProduct.alle) {
            PlusUitleg(aanleiding: aanleiding)
        }
        .subscriptionStoreButtonLabel(.multiline)
        // Koopknoppen: witte tekst op KnopKleur, ook leesbaar in dark mode.
        .tint(.knop)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .policies)
        .storeButton(.visible, for: .cancellation)
        .subscriptionStorePolicyDestination(url: AppLinks.privacybeleid, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: AppLinks.gebruiksvoorwaarden, for: .termsOfService)
        .onInAppPurchaseCompletion { _, resultaat in
            if case let .success(.success(verificatie)) = resultaat, case let .verified(transactie) = verificatie {
                await transactie.finish()
            }
            await app.entitlements.vernieuw()
            app.werkEigenaarStatusBij()
            if app.isPlus { dismiss() }
        }
        .task {
            await app.entitlements.laadProducten()
        }
        .tint(.accentColor)
    }
}

/// De inhoud boven de abonnementsknoppen.
private struct PlusUitleg: View {
    let aanleiding: PaywallAanleiding
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text("Naaste Plus")
                    .font(.largeTitle.bold())
                Text(aanleidingTekst)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Voordeel(symbool: "person.3", tekst: "Onbeperkt naasten en documenten")
                Voordeel(symbool: "person.2.badge.plus", tekst: "Delen met de hele familie")
                Voordeel(symbool: "clock", tekst: "Urenlogboek voor de onderlinge verdeling en de mantelzorgwaardering")
                Voordeel(symbool: "doc.richtext", tekst: "Urenoverzicht als PDF")
                Voordeel(symbool: "house.and.flag", tekst: "Gezinsdeling: deel Plus met je gezin")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Zo werkt het abonnement")
                    .font(.headline)
                ForEach(app.entitlements.producten, id: \.id) { product in
                    Text(prijsRegel(product))
                        .font(.subheadline)
                }
                if let fout = app.entitlements.productFout {
                    Text(fout)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Het abonnement wordt automatisch verlengd voor dezelfde periode en prijs, tenzij je het uiterlijk 24 uur voor het einde van de lopende periode opzegt. Na een gratis proefperiode wordt het abonnementsbedrag in rekening gebracht, tenzij je vóór het einde van de proef opzegt. De betaling loopt via je Apple ID.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Opzeggen kan altijd: in de app via Instellingen › Abonnement beheren, of in de iPhone-app Instellingen › [je naam] › Abonnementen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Zonder abonnement blijft Naaste gratis te gebruiken: 1 naaste, 15 documenten, delen met 1 persoon en het overdrachtsoverzicht.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 24)
    }

    private var aanleidingTekst: String {
        switch aanleiding {
        case .limiet(.naasten):
            String(localized: "In de gratis versie zorg je voor 1 naaste. Met Plus voeg je er zoveel toe als je wilt.")
        case let .limiet(.documenten(max)):
            String(localized: "Je hebt de \(max) gratis documenten gebruikt. Met Plus bewaar je onbeperkt documenten.")
        case .limiet(.deelnemers):
            String(localized: "Gratis deel je met 1 persoon. Met Plus doet de hele familie mee.")
        case .functie(.urenlogboek), .functie(.urenExport):
            String(localized: "Met het urenlogboek zie je wie hoeveel tijd besteedt, handig voor de verdeling en de mantelzorgwaardering van je gemeente.")
        case .functie:
            String(localized: "Met Plus krijg je alle functies van Naaste.")
        case .handmatig:
            String(localized: "Samen zorgen, zonder gedoe met papieren. Plus geeft je alle ruimte.")
        }
    }

    private func prijsRegel(_ product: Product) -> String {
        guard let abonnement = product.subscription else {
            return "\(product.displayName): \(product.displayPrice)"
        }
        var regel = String(localized: "\(product.displayName): \(product.displayPrice) per \(abonnement.subscriptionPeriod.leesbaar)")
        if let aanbod = abonnement.introductoryOffer,
           aanbod.paymentMode == .freeTrial,
           app.entitlements.proefBeschikbaar[product.id] == true {
            regel += String(localized: ", de eerste \(aanbod.period.leesbaar) gratis")
        }
        return regel
    }
}

private struct Voordeel: View {
    let symbool: String
    let tekst: LocalizedStringKey

    var body: some View {
        Label {
            Text(tekst)
        } icon: {
            Image(systemName: symbool)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
        }
        .font(.body)
    }
}
