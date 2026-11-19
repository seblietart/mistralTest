import Foundation

struct MonthReference: Equatable {
    let year: Int
    let month: Int

    var monthIndex: Int { year * 12 + (month - 1) }

    static func containing(_ date: Date, calendar: Calendar = .current) -> MonthReference {
        let components = calendar.dateComponents([.year, .month], from: date)
        return MonthReference(year: components.year ?? 2000, month: components.month ?? 1)
    }

    func next() -> MonthReference {
        if month == 12 {
            return MonthReference(year: year + 1, month: 1)
        }
        return MonthReference(year: year, month: month + 1)
    }

    func startDate(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    func numberOfDays(calendar: Calendar = .current) -> Int {
        guard let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: start) else { return 30 }
        return range.count
    }

    func name(calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("MMMM y")
        return formatter.string(from: startDate(calendar: calendar))
    }
}

enum BudgetCalculator {
    static func monthlyTotal(_ items: [RecurringItem], kind: ItemKind) -> Double {
        items
            .filter { $0.kind == kind && $0.isActive }
            .reduce(0) { $0 + $1.monthlyAmount }
    }

    static func chargeTotal(_ items: [RecurringItem]) -> Double {
        items.reduce(0) { $0 + $1.amount }
    }

    static func charges(_ items: [RecurringItem], kind: ItemKind, month: MonthReference) -> [RecurringItem] {
        items.filter { $0.kind == kind && $0.isActive && chargesIn($0, month: month) }
    }

    static func chargesIn(_ item: RecurringItem, month: MonthReference) -> Bool {
        guard item.isActive else { return false }
        if item.frequency == .monthly { return true }
        let anchor = MonthReference.containing(item.anchorDate).monthIndex
        guard month.monthIndex >= anchor else { return false }
        return (month.monthIndex - anchor) % item.frequency.monthsPerCharge == 0
    }
}
