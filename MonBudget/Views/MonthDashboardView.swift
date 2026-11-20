import SwiftUI
import SwiftData

struct MonthDashboardView: View {
    @Query(sort: \RecurringItem.createdAt) private var items: [RecurringItem]
    @AppStorage("unplannedBudget") private var unplannedBudget: Double = 100

    var body: some View {
        NavigationStack {
            if items.isEmpty {
                ContentUnavailableView(
                    "Aucune donnée",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Ajoutez vos revenus et vos charges récurrentes dans l'onglet Récurrents.")
                )
                .navigationTitle("Mon Budget")
            } else {
                dashboard
                    .navigationTitle("Mon Budget")
            }
        }
    }

    private func money(_ value: Double) -> Text {
        Text(value, format: .currency(code: "EUR"))
    }

    private var dashboard: some View {
        let now = Date()
        let calendar = Calendar.current
        let currentMonth = MonthReference.containing(now, calendar: calendar)
        let nextMonth = currentMonth.next()
        let today = calendar.component(.day, from: now)
        let daysInMonth = currentMonth.numberOfDays(calendar: calendar)
        let income = BudgetCalculator.monthlyTotal(items, kind: .income)
        let fixed = BudgetCalculator.monthlyTotal(items, kind: .expense)
        let leftover = income - fixed
        let effectiveUnplanned = min(unplannedBudget, max(0, leftover))
        let remaining = leftover - effectiveUnplanned
        let perDay = daysInMonth > 0 ? remaining / Double(daysInMonth) : 0
        let monthCharges = BudgetCalculator.charges(items, kind: .expense, month: currentMonth)
        let alreadyDebited = monthCharges.filter { $0.chargeDay <= today }
        let alreadySum = BudgetCalculator.chargeTotal(alreadyDebited)
        let upcoming = monthCharges.filter { $0.chargeDay > today }.sorted { $0.chargeDay < $1.chargeDay }
        let upcomingSum = BudgetCalculator.chargeTotal(upcoming)
        let nextCharges = BudgetCalculator.charges(items, kind: .expense, month: nextMonth)
            .sorted { $0.chargeDay < $1.chargeDay }
        let nextChargesSum = BudgetCalculator.chargeTotal(nextCharges)
        let nextDays = nextMonth.numberOfDays(calendar: calendar)
        let nextPerDay = nextDays > 0 ? (income - nextChargesSum - effectiveUnplanned) / Double(nextDays) : 0

        return List {
            Section("Où j'en suis — \(currentMonth.name(calendar: calendar))") {
                LabeledContent("Revenus mensuels") {
                    money(income).foregroundStyle(.green)
                }
                LabeledContent("Charges fixes (lissées / mois)") {
                    money(fixed).foregroundStyle(.red)
                }
                LabeledContent("Déjà débité ce mois-ci") {
                    money(alreadySum)
                }
                LabeledContent("Encore à débiter ce mois") {
                    money(upcomingSum)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Jour \(today) sur \(daysInMonth)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: min(1, Double(today) / Double(max(daysInMonth, 1))))
                        .progressViewStyle(.linear)
                }
            }

            Section("Dépenses non prévues") {
                LabeledContent("Curseur des imprévus") {
                    money(effectiveUnplanned)
                }
                Slider(
                    value: Binding(
                        get: { min(unplannedBudget, max(0, sliderMax(leftover: leftover))) },
                        set: { unplannedBudget = $0 }
                    ),
                    in: 0...max(50, sliderMax(leftover: leftover)),
                    step: 5
                )
                .disabled(leftover <= 0)
                Text(money(effectiveUnplanned) + Text(" mis de côté pour les imprévus."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                LabeledContent("Reste à vivre après imprévus") {
                    money(remaining)
                }
                LabeledContent("Budget par jour") {
                    money(perDay)
                }
                if leftover <= 0 {
                    Label("Vos charges dépassent vos revenus. Ajustez le curseur d'imprévus à 0 ou revoyez vos charges.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section("Projection — \(nextMonth.name(calendar: calendar))") {
                LabeledContent("Revenus prévus") {
                    money(income).foregroundStyle(.green)
                }
                LabeledContent("Charges prévues") {
                    money(nextChargesSum).foregroundStyle(.red)
                }
                LabeledContent("Imprévus estimés") {
                    money(effectiveUnplanned)
                }
                LabeledContent("Reste à vivre projeté") {
                    money(income - nextChargesSum - effectiveUnplanned)
                        .font(.body.bold())
                }
                LabeledContent("Soit par jour") {
                    money(nextPerDay)
                }
                ForEach(nextCharges) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                            if let remaining = item.creditRemaining,
                               let end = BudgetCalculator.creditEndDate(of: item, from: nextMonth) {
                                Text("Crédit · \(remaining) échéances restantes · fin \(end.name(calendar: calendar))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("le \(item.chargeDay)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        money(item.amount)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func sliderMax(leftover: Double) -> Double {
        leftover > 0 ? leftover : 50
    }
}

#Preview {
    MonthDashboardView()
        .modelContainer(for: RecurringItem.self, inMemory: true)
}
