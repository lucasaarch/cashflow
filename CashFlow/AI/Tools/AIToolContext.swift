import Foundation
import SwiftData

struct AIToolContext {
    let modelContext: ModelContext
    let transactions: [Transaction]
    let accounts: [Account]
    let bills: [Bill]
    let receivables: [Receivable]
    let goals: [FinancialGoal]
    let recurringExpenses: [RecurringExpense]
    let recurringIncomes: [RecurringIncome]
    let categories: [Category]
    let wishlistItems: [WishlistItem]
    var dashboardInsightMonthKey: String?
    var wishlistInsightMonthKey: String?
    var calendar: Calendar = .current
    var now: Date = .now

    var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    func referenceDate(from args: [String: Any]) -> Date {
        AIToolJSON.date(args, key: "reference_date", calendar: calendar)
            ?? AIToolJSON.date(args, key: "as_of_date", calendar: calendar)
            ?? now
    }

    func monthSummary(referenceDate: Date? = nil) -> MonthSummary {
        MonthSummary(
            referenceDate: referenceDate ?? now,
            transactions: transactions,
            pendingReceivables: receivables,
            calendar: calendar,
            now: now
        )
    }

    func overview(asOf: Date? = nil) -> FinancialOverview {
        FinancialOverview(
            accounts: accounts,
            transactions: transactions,
            bills: bills,
            asOf: asOf ?? now,
            now: now
        )
    }

    func reportBuilder(referenceDate: Date, period: ReportPeriod) -> ReportBuilder {
        ReportBuilder(
            referenceDate: referenceDate,
            period: period,
            transactions: transactions,
            accounts: accounts,
            bills: bills,
            calendar: calendar,
            now: now
        )
    }
}
