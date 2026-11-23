import SwiftUI

// TIJDELIJK: deze tabbladen worden in de volgende bouwfasen vervangen
// (fase 5 Taken). Dit bestand gaat dan weg.

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
