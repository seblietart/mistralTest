import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MonthDashboardView()
                .tabItem {
                    Label("Mois", systemImage: "calendar")
                }
            RecurringListView()
                .tabItem {
                    Label("Récurrents", systemImage: "repeat")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: RecurringItem.self, inMemory: true)
}
