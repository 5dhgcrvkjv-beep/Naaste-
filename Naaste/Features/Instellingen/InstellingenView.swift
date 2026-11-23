import CoreData
import NaasteKit
import StoreKit
import SwiftUI

struct InstellingenView: View {
    @Environment(AppModel.self) private var app
    @FetchRequest(fetchRequest: Naaste.alle()) private var naasten: FetchedResults<Naaste>
    @State private var beheerAbonnement = false
    @State private var herstellen = false
    @State private var melding: String?

    var body: some View {
        NavigationStack {
            List {
                abonnementSectie

                Section {
                    NavigationLink {
                        MetGeselecteerdeNaaste { naaste in
                            FamilieView(naaste: naaste)
                        }
                    } label: {
                        Label("Familieleden", systemImage: "person.3")
                    }
                } header: {
                    Text("Familie")
                } footer: {
                    Text("Familieleden zijn naamkaartjes voor taken en uren. Je hebt geen account nodig.")
                }

                Section {
                    if naasten.contains(where: \.isVoorbeeld) {
                        Button("Voorbeeld-naaste verwijderen", role: .destructive) {
                            app.verwijderVoorbeeld()
                        }
                    } else {
                        Button("Voorbeeld-naaste tonen") {
                            app.laadVoorbeeld()
                        }
                    }
                } header: {
                    Text("Voorbeeld")
                } footer: {
                    Text("Een voorbeeld met verzonnen gegevens om alle functies te bekijken. Telt niet mee voor de gratis limieten.")
                }

                Section {
                    Link(destination: AppLinks.privacybeleid) {
                        Label("Privacybeleid", systemImage: "hand.raised")
                    }
                    Link(destination: AppLinks.gebruiksvoorwaarden) {
                        Label("Gebruiksvoorwaarden", systemImage: "doc.plaintext")
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Je gegevens staan alleen op je iPhone en in je eigen iCloud, en bij familieleden met wie je deelt. Naaste heeft geen eigen server, verzamelt geen gegevens en gebruikt geen tracking.")
                }

                Section("Over Naaste") {
                    LabeledContent("Versie", value: Self.versie)
                    Link(destination: AppLinks.ondersteuning) {
                        Label("Hulp en contact", systemImage: "questionmark.circle")
                    }
                }
            }
            .navigationTitle("Instellingen")
            .manageSubscriptionsSheet(isPresented: $beheerAbonnement)
            .alert("Aankopen herstellen", isPresented: Binding(get: { melding != nil }, set: { if !$0 { melding = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(melding ?? "")
            }
        }
    }

    private var abonnementSectie: some View {
        Section {
            switch app.entitlements.status {
            case .gratis:
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gratis versie")
                        .font(.headline)
                    Text("1 naaste, \(LimitPolicy.gratisMaxDocumenten) documenten, delen met 1 persoon en het overdrachtsoverzicht.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                Button {
                    app.paywall = .handmatig
                } label: {
                    Label("Bekijk Naaste Plus", systemImage: "sparkles")
                }
            case let .plus(_, verlooptOp, viaGezin):
                VStack(alignment: .leading, spacing: 4) {
                    Text("Naaste Plus is actief")
                        .font(.headline)
                    if viaGezin {
                        Text("Via Gezinsdeling.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let verlooptOp {
                        Text("Loopt tot \(verlooptOp.formatted(date: .long, time: .omitted)) en wordt automatisch verlengd, tenzij je opzegt.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }

            Button {
                beheerAbonnement = true
            } label: {
                Label("Abonnement beheren of opzeggen", systemImage: "creditcard")
            }

            Button {
                Task { await herstel() }
            } label: {
                HStack {
                    Label("Aankopen herstellen", systemImage: "arrow.clockwise")
                    if herstellen {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(herstellen)
        } header: {
            Text("Abonnement")
        }
    }

    private func herstel() async {
        herstellen = true
        defer { herstellen = false }
        do {
            try await app.entitlements.herstel()
            melding = app.isPlus
                ? String(localized: "Je abonnement is hersteld. Naaste Plus is actief.")
                : String(localized: "Er is geen actief abonnement gevonden voor deze Apple ID.")
        } catch {
            melding = String(localized: "Herstellen is niet gelukt. Controleer je internetverbinding en probeer het opnieuw.")
        }
    }

    private static var versie: String {
        let info = Bundle.main.infoDictionary
        let versie = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(versie) (\(build))"
    }
}
