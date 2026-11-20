import SwiftUI
import SwiftData

struct ItemFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let item: RecurringItem?

    @State private var name: String = ""
    @State private var amountText: String = ""
    @State private var kindSelection: ItemKind = .expense
    @State private var frequencySelection: Frequency = .monthly
    @State private var daySelection: Int = 1
    @State private var active: Bool = true
    @State private var isCredit: Bool = false
    @State private var installmentsText: String = "12"

    init(item: RecurringItem?, defaultKind: ItemKind = .expense) {
        self.item = item
        if let item {
            _name = State(initialValue: item.name)
            _amountText = State(initialValue: String(format: "%.2f", item.amount))
            _kindSelection = State(initialValue: item.kind)
            _frequencySelection = State(initialValue: item.frequency)
            _daySelection = State(initialValue: item.dayOfMonth)
            _active = State(initialValue: item.isActive)
            _isCredit = State(initialValue: item.isCredit && item.kind == .expense)
            if let remaining = item.creditRemaining {
                _installmentsText = State(initialValue: String(remaining))
            }
        } else {
            _kindSelection = State(initialValue: defaultKind)
        }
    }

    private var amount: Double? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    private var installments: Int? {
        let normalized = installmentsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(normalized), value >= 1 else { return nil }
        return value
    }

    private var canSave: Bool {
        let installmentsValid = kindSelection == .expense && isCredit ? installments != nil : true
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && amount != nil
            && installmentsValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Élément") {
                    TextField("Nom (ex : Loyer, Salaire…)", text: $name)
                    TextField("Montant", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("Type", selection: $kindSelection) {
                        ForEach(ItemKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    if kindSelection == .expense {
                        Toggle("C'est un crédit", isOn: $isCredit)
                        if isCredit {
                            TextField("Échéances restantes", text: $installmentsText)
                                .keyboardType(.numberPad)
                            if let remaining = installments {
                                Text("Soit \(remaining) mois de prélèvements restants.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Picker("Fréquence", selection: $frequencySelection) {
                        ForEach(Frequency.allCases) { frequency in
                            Text(frequency.label).tag(frequency)
                        }
                    }
                    if frequencySelection == .monthly {
                        Picker("Jour de prélèvement", selection: $daySelection) {
                            ForEach(1...28, id: \.self) { day in
                                Text("le \(day)").tag(day)
                            }
                        }
                    }
                    if item != nil {
                        Toggle("Actif", isOn: $active)
                    }
                }

                Section {
                    LabeledContent("Équivalent mensuel") {
                        Text(monthlyEquivalent, format: .currency(code: "EUR"))
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Utilisé pour lisser les charges trimestrielles, semestrielles ou annuelles sur 12 mois.")
                }

                if frequencySelection != .monthly {
                    Section("Fonctionnement") {
                        Text("La charge sera prise en compte dans le mois du prélèvement (tous les \(frequencySelection.monthsPerCharge) mois à partir de sa création).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(item == nil ? "Nouveau" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var monthlyEquivalent: Double {
        (amount ?? 0) * frequencySelection.timesPerYear / 12
    }

    private func save() {
        guard let amount else { return }
        if let item {
            item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            item.amount = amount
            item.kind = kindSelection
            item.frequency = frequencySelection
            item.dayOfMonth = daySelection
            item.isActive = active
            item.isCredit = kindSelection == .expense && isCredit
            if let remaining = installments {
                item.remainingInstallments = remaining
            }
        } else {
            let newItem = RecurringItem(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amount,
                kind: kindSelection,
                frequency: frequencySelection,
                dayOfMonth: daySelection,
                isCredit: kindSelection == .expense && isCredit,
                remainingInstallments: installments ?? 12
            )
            modelContext.insert(newItem)
        }
        dismiss()
    }
}

#Preview {
    ItemFormView(item: nil)
        .modelContainer(for: RecurringItem.self, inMemory: true)
}
