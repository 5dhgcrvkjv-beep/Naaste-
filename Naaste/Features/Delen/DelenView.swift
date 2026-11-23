import CloudKit
import CoreData
import NaasteKit
import SwiftUI

/// Delen van de zorgmap van een naaste met familie.
struct DelenView: View {
    @ObservedObject var naaste: Naaste
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var share: CKShare?
    @State private var bezig = false
    @State private var bevestigVerlaten = false

    private var isDeelnemer: Bool { app.delen.isDeelnemer(bij: naaste) }

    var body: some View {
        List {
            if naaste.isVoorbeeld {
                Section {
                    Label("De voorbeeld-naaste kun je niet delen. Voeg je eigen naaste toe om samen met familie te werken.", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            } else if isDeelnemer {
                deelnemerSecties
            } else {
                eigenaarSecties
            }

            Section("Zo werkt het") {
                Uitlegregel(symbool: "person.2", tekst: "Familieleden hebben een eigen iPhone, een Apple ID en de app Naaste nodig.")
                Uitlegregel(symbool: "icloud", tekst: "De uitnodiging gaat via Berichten of Mail. Alles loopt via iCloud; Naaste heeft geen eigen server.")
                Uitlegregel(symbool: "arrow.triangle.2.circlepath", tekst: "Documenten, zaken, taken en uren van deze naaste zijn voor iedereen hetzelfde en blijven bijgewerkt.")
                Uitlegregel(symbool: "sparkles", tekst: "Heeft de eigenaar Naaste Plus, dan geldt dat ook voor wie meedoet.")
            }
        }
        .navigationTitle("Delen met familie")
        .overlay {
            if bezig { ProgressView().controlSize(.large) }
        }
        .task { laad() }
        .refreshable { laad() }
        .confirmationDialog("Deze zorgmap verlaten?", isPresented: $bevestigVerlaten, titleVisibility: .visible) {
            Button("Verlaat", role: .destructive) {
                Task {
                    bezig = true
                    let gelukt = await app.verlaat(naaste)
                    bezig = false
                    if gelukt { dismiss() }
                }
            }
        } message: {
            Text("\(naaste.weergaveNaam) verdwijnt van deze iPhone. De gegevens blijven bewaard bij de eigenaar. Je kunt opnieuw worden uitgenodigd.")
        }
    }

    // MARK: Eigenaar

    @ViewBuilder private var eigenaarSecties: some View {
        let deelnemers = share.map(app.delen.deelnemers(van:)) ?? []
        Section {
            if deelnemers.isEmpty {
                LegeRij(tekst: "Je deelt \(naaste.weergaveNaam) nog met niemand.")
            }
            ForEach(deelnemers) { DeelnemerRij(deelnemer: $0) }
        } header: {
            Text("Gedeeld met")
        } footer: {
            if !app.policy(voor: naaste).isPlus {
                Text("In de gratis versie deel je met \(LimitPolicy.gratisMaxDeelnemers) persoon. Met Naaste Plus deel je met de hele familie.")
            }
        }

        Section {
            Button {
                open(uitnodigen: true)
            } label: {
                Label("Familielid uitnodigen", systemImage: "person.badge.plus")
            }
            if share != nil {
                Button {
                    open(uitnodigen: false)
                } label: {
                    Label("Rechten wijzigen of stoppen met delen", systemImage: "person.2.badge.gearshape")
                }
            }
        } footer: {
            if share != nil {
                Text("Stop je met delen, dan verdwijnt \(naaste.weergaveNaam) bij de anderen. Jouw eigen gegevens blijven staan.")
            }
        }
        .disabled(bezig)
    }

    // MARK: Deelnemer

    @ViewBuilder private var deelnemerSecties: some View {
        Section {
            if let share {
                LabeledContent("Eigenaar", value: app.delen.eigenaarNaam(van: share))
                ForEach(app.delen.deelnemers(van: share)) { DeelnemerRij(deelnemer: $0) }
            }
        } header: {
            Text("Gedeeld met jou")
        } footer: {
            Text("Je werkt mee in de zorgmap van \(naaste.weergaveNaam). Wijzigingen zie je bij iedereen.")
        }

        Section {
            Button {
                open(uitnodigen: false)
            } label: {
                Label("Wie doet er mee", systemImage: "person.2")
            }
            Button("Deze zorgmap verlaten", role: .destructive) {
                bevestigVerlaten = true
            }
        }
        .disabled(bezig)
    }

    // MARK: Acties

    private func laad() {
        share = app.delen.share(van: naaste)
    }

    private func open(uitnodigen: Bool) {
        bezig = true
        app.openDelen(naaste, uitnodigen: uitnodigen) {
            bezig = false
            laad()
        }
        // Als de limiet bereikt is, opent de paywall en komt er geen callback.
        if app.paywall != nil { bezig = false }
    }
}

private struct DeelnemerRij: View {
    let deelnemer: Delen.Deelnemer

    var body: some View {
        HStack {
            Image(systemName: "person.crop.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(deelnemer.naam)
                Text(onderregel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var onderregel: String {
        let rechten = deelnemer.magBewerken ? String(localized: "kan wijzigen") : String(localized: "alleen bekijken")
        let status: String = switch deelnemer.status {
        case .accepted: String(localized: "doet mee")
        case .pending: String(localized: "uitgenodigd")
        case .removed: String(localized: "verwijderd")
        default: String(localized: "onbekend")
        }
        return "\(status) · \(rechten)"
    }
}

private struct Uitlegregel: View {
    let symbool: String
    let tekst: LocalizedStringKey

    var body: some View {
        Label {
            Text(tekst)
                .font(.subheadline)
        } icon: {
            Image(systemName: symbool)
                .foregroundStyle(Color.accentColor)
        }
    }
}
