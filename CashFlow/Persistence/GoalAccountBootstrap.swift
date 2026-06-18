import Foundation
import SwiftData

/// One-shot migration: converts legacy "manual mode" goals (which stored progress
/// directly on `manualCurrentAmount`) into goal-kind accounts linked to the goal.
/// Idempotent — running on every launch is safe since it skips goals that already
/// have linked accounts or no legacy manual value.
enum GoalAccountBootstrap {
    static func migrateLegacyManualGoals(context: ModelContext) {
        let descriptor = FetchDescriptor<FinancialGoal>()
        guard let goals = try? context.fetch(descriptor) else { return }

        let accountDescriptor = FetchDescriptor<Account>()
        let existingAccounts = (try? context.fetch(accountDescriptor)) ?? []
        var nextSortOrder = existingAccounts.map(\.sortOrder).max() ?? -1

        for goal in goals {
            guard let manual = goal.manualCurrentAmount,
                  goal.linkedAccounts.isEmpty
            else { continue }

            nextSortOrder += 1
            let account = Account(
                name: goal.name,
                kind: .goal,
                colorHex: goal.colorHex,
                symbolName: goal.symbolName,
                sortOrder: nextSortOrder,
                openingBalance: max(manual, 0),
                openingDate: Calendar.current.startOfDay(for: goal.createdAt)
            )
            context.insert(account)
            goal.linkedAccounts = [account]
            goal.manualCurrentAmount = nil
        }

        try? context.save()
    }
}
