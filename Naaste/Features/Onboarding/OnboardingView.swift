import SwiftUI

/// Korte kennismaking bij de eerste start. Vier pagina's, overslaan kan altijd.
/// Eindigt met "Voeg je naaste toe" of "Bekijk eerst een voorbeeld".
struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @AppStorage(Opslagsleutel.onboardingKlaar) private var klaar = false
    @AppStorage(Opslagsleutel.geselecteerdeNaaste) private var geselecteerdeID = ""
    @State private var pagina = 0
    @State private var nieuweNaaste = false

    private struct Pagina: Identifiable {
        let id: Int
        let symbool: String
        let titel: LocalizedStringKey
        let tekst: LocalizedStringKey
    }

    private let paginas: [Pagina] = [
        Pagina(
            id: 0,
            symbool: "heart.text.square",
            titel: "Samen zorgen, samen regelen",
            tekst: "Naaste helpt families met de administratie rond een ouder of naaste: brieven, aanvragen, afspraken en wie wat doet."
        ),
        Pagina(
            id: 1,
            symbool: "doc.viewfinder",
            titel: "Alles op één plek",
            tekst: "Scan brieven van de gemeente, het CIZ of het CAK en vind ze terug op een woord. Volg aanvragen met een tijdlijn en krijg een seintje vóór een deadline."
        ),
        Pagina(
            id: 2,
            symbool: "person.3",
            titel: "Met de hele familie",
            tekst: "Deel de zorgmap met broers, zussen of de buren. Iedereen ziet dezelfde documenten, zaken en taken op de eigen iPhone."
        ),
        Pagina(
            id: 3,
            symbool: "lock.shield",
            titel: "Van jou, niet van ons",
            tekst: "Alles staat op je iPhone en in je eigen iCloud. Naaste heeft geen eigen server, geen account en geen tracking. Het is geen medische app: medische zaken blijven bij de huisarts."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if pagina < paginas.count - 1 {
                    Button("Sla over") { pagina = paginas.count - 1 }
                        .padding()
                        .frame(minHeight: 44)
                }
            }
            .frame(height: 56)

            TabView(selection: $pagina.animation()) {
                ForEach(paginas) { p in
                    PaginaInhoud(symbool: p.symbool, titel: p.titel, tekst: p.tekst)
                        .tag(p.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            .onAppear {
                // Standaard is het actieve bolletje wit: onzichtbaar op een lichte achtergrond.
                UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(named: "AccentColor")
                UIPageControl.appearance().pageIndicatorTintColor = .tertiaryLabel
            }

            VStack(spacing: 12) {
                if pagina < paginas.count - 1 {
                    Button {
                        withAnimation { pagina += 1 }
                    } label: {
                        Text("Volgende")
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .hoofdknop()
                } else {
                    Button {
                        if app.magNaasteToevoegen() { nieuweNaaste = true }
                    } label: {
                        Text("Voeg je naaste toe")
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .hoofdknop()

                    Button {
                        if let voorbeeld = app.laadVoorbeeld() {
                            geselecteerdeID = voorbeeld.uuid?.uuidString ?? ""
                        }
                        klaar = true
                    } label: {
                        Text("Bekijk eerst een voorbeeld")
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $nieuweNaaste) {
            NaasteBewerkenView(modus: .nieuw, opgeslagen: { naaste in
                geselecteerdeID = naaste.uuid?.uuidString ?? ""
                klaar = true
            })
        }
    }
}

private struct PaginaInhoud: View {
    let symbool: String
    let titel: LocalizedStringKey
    let tekst: LocalizedStringKey

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: symbool)
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 24)
                    .accessibilityHidden(true)
                Text(titel)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(tekst)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48) // ruimte voor de paginabolletjes
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
