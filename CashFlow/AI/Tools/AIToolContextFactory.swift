import Foundation
import SwiftData

@MainActor
enum AIToolContextFactory {
    static func make(from container: ModelContainer) throws -> AIToolContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let transactions = try context.fetch(
            FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\Transaction.occurredOn, order: .reverse)])
        )
        let accounts = try context.fetch(
            FetchDescriptor<Account>(
                predicate: #Predicate { !$0.isArchived },
                sortBy: [SortDescriptor(\Account.sortOrder)]
            )
        )
        let bills = try context.fetch(
            FetchDescriptor<Bill>(sortBy: [SortDescriptor(\Bill.dueDate)])
        )
        let receivables = try context.fetch(
            FetchDescriptor<Receivable>(sortBy: [SortDescriptor(\Receivable.expectedDate)])
        )
        let goals = try context.fetch(
            FetchDescriptor<FinancialGoal>(sortBy: [SortDescriptor(\FinancialGoal.createdAt, order: .reverse)])
        )
        let wishlistItems = try context.fetch(
            FetchDescriptor<WishlistItem>(sortBy: [SortDescriptor(\WishlistItem.createdAt, order: .reverse)])
        )
        let recurringExpenses = try context.fetch(
            FetchDescriptor<RecurringExpense>(sortBy: [SortDescriptor(\RecurringExpense.createdAt)])
        )
        let recurringIncomes = try context.fetch(
            FetchDescriptor<RecurringIncome>(sortBy: [SortDescriptor(\RecurringIncome.createdAt)])
        )
        let categories = try context.fetch(
            FetchDescriptor<Category>(sortBy: [SortDescriptor(\Category.sortOrder)])
        )

        return AIToolContext(
            modelContext: context,
            transactions: transactions,
            accounts: accounts,
            bills: bills,
            receivables: receivables,
            goals: goals,
            recurringExpenses: recurringExpenses,
            recurringIncomes: recurringIncomes,
            categories: categories,
            wishlistItems: wishlistItems
        )
    }
}
