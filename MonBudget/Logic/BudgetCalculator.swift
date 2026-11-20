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
    static func monthlyTotal(_ items: [RecurringItem], kind: ItemKind, now: Date = Date(), calendar: Calendar = .current) -> Double {
        items
            .filter { $0.kind == kind && isActiveCharge($0, now: now, calendar: calendar) }
            .reduce(0) { $0 + $1.monthlyAmount }
    }

    static func chargeTotal(_ items: [RecurringItem]) -> Double {
        items.reduce(0) { $0 + $1.amount }
    }

    static func charges(_ items: [RecurringItem], kind: ItemKind, month: MonthReference, now: Date = Date(), calendar: Calendar = .current) -> [RecurringItem] {
        items.filter {
            $0.kind == kind
                && isActiveCharge($0, now: now, calendar: calendar)
                && chargesIn($0, month: month)
        }
    }

    static func chargesIn(_ item: RecurringItem, month: MonthReference) -> Bool {
        guard item.isActive else { return false }
        if item.frequency == .monthly { return true }
        let anchor = MonthReference.containing(item.anchorDate).monthIndex
        guard month.monthIndex >= anchor else { return false }
        return (month.monthIndex - anchor) % item.frequency.monthsPerCharge == 0
    }

    static func isActiveCharge(_ item: RecurringItem, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard item.isActive else { return false }
        guard let remaining = creditRemainingInstallments(item, now: now, calendar: calendar) else { return true }
        return remaining > 0
    }

    static func installmentDate(of item: RecurringItem, month: MonthReference, calendar: Calendar = .current) -> Date? {
        guard chargesIn(item, month: month) else { return nil }
        return calendar.date(from: DateComponents(year: month.year, month: month.month, day: item.chargeDay))
    }

    static func creditPaidSinceReference(_ item: RecurringItem, now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard item.creditStoredRemaining != nil else { return 0 }
        let today = calendar.startOfDay(for: now)
        let referenceDay = calendar.startOfDay(for: item.remainingAsOfDate)
        var cursor = MonthReference.containing(item.remainingAsOfDate, calendar: calendar)
        let current = MonthReference.containing(now, calendar: calendar)
        var paid = 0
        while cursor.monthIndex <= current.monthIndex {
            if let occurrence = installmentDate(of: item, month: cursor, calendar: calendar) {
                let occurrenceDay = calendar.startOfDay(for: occurrence)
                if occurrenceDay > referenceDay && occurrenceDay < today {
                    paid += 1
                }
            }
            cursor = cursor.next()
        }
        return paid
    }

    static func creditRemainingInstallments(_ item: RecurringItem, now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let stored = item.creditStoredRemaining else { return nil }
        return max(0, stored - creditPaidSinceReference(item, now: now, calendar: calendar))
    }

    static func creditEndDate(of item: RecurringItem, now: Date = Date(), calendar: Calendar = .current) -> MonthReference? {
        guard var remaining = creditRemainingInstallments(item, now: now, calendar: calendar), remaining > 0 else {
            return nil
        }
        let today = calendar.startOfDay(for: now)
        var cursor = MonthReference.containing(now, calendar: calendar)
        for _ in 0..<(12 * 100) {
            if let occurrence = installmentDate(of: item, month: cursor, calendar: calendar),
               calendar.startOfDay(for: occurrence) >= today {
                remaining -= 1
                if remaining == 0 {
                    return cursor
                }
            }
            cursor = cursor.next()
        }
        return nil
    }
}
