import Foundation

/// Builds the list of `Transaction`s that compose an `InstallmentPlan`.
/// Centavos are absorbed by the first installment so the sum stays exact.
enum InstallmentMaterializer {

    struct Draft {
        let occurredOn: Date
        let amount: Decimal
        let installmentIndex: Int
        let note: String
    }

    /// Returns N drafts. Caller wraps them in `Transaction(...)` so we don't reach into SwiftData here.
    /// `occurredOn` of installment K (1-indexed) is `purchaseDate + (K-1) months`.
    /// `reportingDate` (which determines the invoice month) is derived later by `Transaction.reportingDate`,
    /// honoring the card's billing cycle.
    static func drafts(
        purchaseDate: Date,
        totalCents: Int,
        installmentCount: Int,
        noteBase: String,
        calendar: Calendar = .current
    ) -> [Draft] {
        precondition(installmentCount >= 1, "installmentCount must be >= 1")
        precondition(totalCents > 0, "totalCents must be > 0")

        let baseCents = totalCents / installmentCount
        let remainderCents = totalCents - baseCents * installmentCount

        return (1...installmentCount).map { index in
            let offsetMonths = index - 1
            let date = calendar.date(byAdding: .month, value: offsetMonths, to: purchaseDate) ?? purchaseDate
            // First installment absorbs the leftover cents so the sum equals totalCents exactly.
            let cents = index == 1 ? baseCents + remainderCents : baseCents
            let amount = Decimal(cents) / 100
            let suffix = noteBase.isEmpty ? "" : " — \(noteBase)"
            let note = "Parcela \(index)/\(installmentCount)\(suffix)"
            return Draft(
                occurredOn: calendar.startOfDay(for: date),
                amount: amount,
                installmentIndex: index,
                note: note
            )
        }
    }
}
