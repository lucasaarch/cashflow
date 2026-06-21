import Foundation

enum InstallmentCommitmentCalculator {
    struct MonthCommitment: Identifiable {
        let id: String
        let monthStart: Date
        let total: Decimal
        let count: Int
    }

    static func upcomingCommitments(
        transactions: [Transaction],
        from referenceDate: Date,
        monthCount: Int = 6,
        calendar: Calendar = .current
    ) -> [MonthCommitment] {
        guard monthCount > 0 else { return [] }

        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) ?? referenceDate
        var buckets: [String: (Date, Decimal, Int)] = [:]

        for transaction in transactions where transaction.isInstallment && transaction.occurredOn > referenceDate {
            guard transaction.kind == .expense else { continue }
            let anchor = calendar.date(from: calendar.dateComponents([.year, .month], from: transaction.occurredOn)) ?? transaction.occurredOn
            let key = monthKey(for: anchor, calendar: calendar)
            let existing = buckets[key]
            buckets[key] = (
                existing?.0 ?? anchor,
                (existing?.1 ?? 0) + transaction.amount,
                (existing?.2 ?? 0) + 1
            )
        }

        return (0..<monthCount).compactMap { offset -> MonthCommitment? in
            guard let month = calendar.date(byAdding: .month, value: offset, to: monthStart) else { return nil }
            let anchor = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
            let key = monthKey(for: anchor, calendar: calendar)
            guard let bucket = buckets[key], bucket.1 > 0 else { return nil }
            return MonthCommitment(id: key, monthStart: bucket.0, total: bucket.1, count: bucket.2)
        }
    }

    static func totalUpcoming(
        transactions: [Transaction],
        from referenceDate: Date,
        withinDays days: Int = 30,
        calendar: Calendar = .current
    ) -> Decimal {
        guard let end = calendar.date(byAdding: .day, value: days, to: referenceDate) else { return 0 }
        return transactions
            .filter { $0.isInstallment && $0.kind == .expense && $0.occurredOn > referenceDate && $0.occurredOn <= end }
            .reduce(0) { $0 + $1.amount }
    }

    private static func monthKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }
}
