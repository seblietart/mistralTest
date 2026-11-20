import SwiftUI
import SwiftData

struct RecurringListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringItem.createdAt) private var items: [RecurringItem]
    @State private var editingItem: RecurringItem?
    @State private var isAddingIncome = false
    @State private var isAddingExpense = false

    var body: some View {
        NavigationStack {
            List {
                section(for: .income, title: "Revenus", emptyText: "Aucun revenu. Touchez + pour en ajouter un.")
                section(for: .expense, title: "Charges fixes et récurrentes", emptyText: "Aucune dépense. Touchez + pour en ajouter une.")
            }
            .navigationTitle("Récurrents")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isAddingIncome = true
                        } label: {
                            Label("Nouveau revenu", systemImage: "plus.circle")
                        }
                        Button {
                            isAddingExpense = true
                        } label: {
                            Label("Nouvelle dépense", systemImage: "minus.circle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingIncome) {
                ItemFormView(item: nil, defaultKind: .income)
            }
            .sheet(isPresented: $isAddingExpense) {
                ItemFormView(item: nil, defaultKind: .expense)
            }
            .sheet(item: $editingItem) { item in
                ItemFormView(item: item)
            }
        }
    }

    private func section(for kind: ItemKind, title: String, emptyText: String) -> some View {
        Section(title) {
            let kindItems = items.filter { $0.kind == kind }
            ForEach(kindItems) { item in
                row(for: item)
            }
            if kindItems.isEmpty {
                Text(emptyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func creditEndDate(for item: RecurringItem) -> MonthReference? {
        BudgetCalculator.creditEndDate(of: item, from: MonthReference.containing(Date()))
    }

    private func row(for item: RecurringItem) -> some View {
        Button {
            editingItem = item
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                    HStack(spacing: 4) {
                        Text(item.frequency.label)
                        Text("·")
                        Text("le \(item.chargeDay)")
                        if item.frequency != .monthly {
                            Text("·")
                            Text("soit")
                            Text(item.monthlyAmount, format: .currency(code: "EUR"))
                            Text("/ mois")
                        }
                        if let remaining = item.creditRemaining {
                            Text("·")
                            Text("crédit : \(remaining) échéances restantes")
                        }
                        if let end = creditEndDate(for: item) {
                            Text("·")
                            Text("fin \(end.name())")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.amount, format: .currency(code: "EUR"))
                    .foregroundStyle(item.kind == .income ? Color.green : Color.primary)
            }
            .opacity(item.isActive ? 1 : 0.5)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(item)
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }
}

#Preview {
    RecurringListView()
        .modelContainer(for: RecurringItem.self, inMemory: true)
}
