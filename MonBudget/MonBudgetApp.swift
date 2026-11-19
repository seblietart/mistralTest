import SwiftUI
import SwiftData

@main
struct MonBudgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: RecurringItem.self)
    }
}
