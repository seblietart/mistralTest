import Foundation
import SwiftData

enum ItemKind: String, Codable, CaseIterable, Identifiable {
    case income
    case expense

    var id: String { rawValue }

    var label: String {
        switch self {
        case .income: return "Revenu"
        case .expense: return "Dépense"
        }
    }
}

enum Frequency: String, Codable, CaseIterable, Identifiable {
    case monthly
    case everyThreeMonths
    case everySixMonths
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monthly: return "Mensuelle"
        case .everyThreeMonths: return "Trimestrielle"
        case .everySixMonths: return "Semestrielle"
        case .yearly: return "Annuelle"
        }
    }

    var timesPerYear: Double {
        switch self {
        case .monthly: return 12
        case .everyThreeMonths: return 4
        case .everySixMonths: return 2
        case .yearly: return 1
        }
    }

    var monthsPerCharge: Int {
        switch self {
        case .monthly: return 1
        case .everyThreeMonths: return 3
        case .everySixMonths: return 6
        case .yearly: return 12
        }
    }
}

@Model
final class RecurringItem {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    var kindRawValue: String = ItemKind.expense.rawValue
    var frequencyRawValue: String = Frequency.monthly.rawValue
    var dayOfMonth: Int = 1
    var anchorDate: Date = Date()
    var isActive: Bool = true
    var createdAt: Date = Date()
    var isCredit: Bool = false
    var remainingInstallments: Int = 12

    init(
        name: String,
        amount: Double,
        kind: ItemKind,
        frequency: Frequency,
        dayOfMonth: Int,
        isCredit: Bool = false,
        remainingInstallments: Int = 12
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.kindRawValue = kind.rawValue
        self.frequencyRawValue = frequency.rawValue
        self.dayOfMonth = dayOfMonth
        self.anchorDate = Date()
        self.isActive = true
        self.createdAt = Date()
        self.isCredit = isCredit
        self.remainingInstallments = remainingInstallments
    }

    var kind: ItemKind {
        get { ItemKind(rawValue: kindRawValue) ?? .expense }
        set { kindRawValue = newValue.rawValue }
    }

    var frequency: Frequency {
        get { Frequency(rawValue: frequencyRawValue) ?? .monthly }
        set { frequencyRawValue = newValue.rawValue }
    }

    var chargeDay: Int {
        min(max(dayOfMonth, 1), 28)
    }

    var monthlyAmount: Double {
        amount * frequency.timesPerYear / 12
    }

    var creditRemaining: Int? {
        guard kind == .expense && isCredit else { return nil }
        return max(1, remainingInstallments)
    }
}
