import SwiftUI

// TIJDELIJK: deze tabbladen worden in de volgende bouwfasen vervangen
// (fase 4 Zaken, fase 5 Taken). Dit bestand gaat dan weg.

struct ZakenView: View {
    var body: some View {
        NavigationStack {
            MetGeselecteerdeNaaste { _ in
                ContentUnavailableView("Zaken", systemImage: "folder", description: Text("Dossiers met tijdlijn volgen in een volgende bouwstap."))
            }
            .navigationTitle("Zaken")
        }
    }
}

struct TakenView: View {
    var body: some View {
        NavigationStack {
            MetGeselecteerdeNaaste { _ in
                ContentUnavailableView("Taken", systemImage: "checklist", description: Text("Taken en urenlogboek volgen in een volgende bouwstap."))
            }
            .navigationTitle("Taken")
        }
    }
}
