import Foundation

enum AIToolFormatters {
    static func money(_ value: Decimal) -> String { value.brl }

    static func accountJSON(_ account: Account, balance: Decimal) -> [String: AIToolJSONValue] {
        [
            "id": .string(account.id.uuidString),
            "name": .string(account.name),
            "kind": .string(account.kind.rawValue),
            "balance": .from(balance)
        ]
    }

    static func transactionJSON(_ transaction: Transaction, calendar: Calendar, now: Date) -> [String: AIToolJSONValue] {
        var object: [String: AIToolJSONValue] = [
            "id": .string(transaction.id.uuidString),
            "date": .string(transaction.occurredOn.formatted(date: .abbreviated, time: .omitted)),
            "status": .string(transaction.occurredOn > now ? "planned" : "realized"),
            "kind": .string(transaction.isTransfer ? "transfer" : transaction.kind.rawValue),
            "amount": .from(transaction.amount),
            "account": .string(transaction.account?.name ?? ""),
            "category": .string(transaction.category?.name ?? "")
        ]
        if let relative = transaction.occurredOn.cfRelativeDay(now: now, calendar: calendar) {
            object["date_relative"] = .string(relative)
        }
        if !transaction.note.isEmpty { object["note"] = .string(transaction.note) }
        if transaction.isTransfer, let groupID = transaction.transferGroupID {
            object["transfer_group_id"] = .string(groupID.uuidString)
        }
        if let billing = transaction.billingCycleCaption(calendar: calendar) {
            object["billing"] = .string(billing)
        }
        return object
    }

    static func billJSON(_ bill: Bill, now: Date) -> [String: AIToolJSONValue] {
        var object: [String: AIToolJSONValue] = [
            "id": .string(bill.id.uuidString),
            "name": .string(bill.name),
            "amount": .from(bill.amount),
            "due_date": .string(bill.dueDate.formatted(date: .abbreviated, time: .omitted)),
            "status": .string(bill.status.rawValue),
            "overdue": .bool(bill.isOverdue(now: now))
        ]
        if let relative = bill.dueDate.cfRelativeDay(now: now) {
            object["due_in"] = .string(relative)
        }
        if let category = bill.category { object["category"] = .string(category.name) }
        if let account = bill.account { object["account"] = .string(account.name) }
        if !bill.note.isEmpty { object["note"] = .string(bill.note) }
        return object
    }

    static func receivableJSON(_ receivable: Receivable, now: Date) -> [String: AIToolJSONValue] {
        var object: [String: AIToolJSONValue] = [
            "id": .string(receivable.id.uuidString),
            "name": .string(receivable.name),
            "amount": .from(receivable.amount),
            "expected_date": .string(receivable.expectedDate.formatted(date: .abbreviated, time: .omitted)),
            "status": .string(receivable.status.rawValue),
            "late": .bool(receivable.isLate(now: now))
        ]
        if let relative = receivable.expectedDate.cfRelativeDay(now: now) {
            object["expected_in"] = .string(relative)
        }
        if let category = receivable.category { object["category"] = .string(category.name) }
        if let account = receivable.account { object["account"] = .string(account.name) }
        if !receivable.note.isEmpty { object["note"] = .string(receivable.note) }
        return object
    }

    static func wishlistItemJSON(_ item: WishlistItem, now: Date) -> [String: AIToolJSONValue] {
        var object: [String: AIToolJSONValue] = [
            "id": .string(item.id.uuidString),
            "name": .string(item.name),
            "estimated_amount": .from(item.estimatedAmount),
            "priority": .string(item.priority.rawValue),
            "note": .string(item.note)
        ]
        if let desiredBy = item.desiredBy {
            object["desired_by"] = .string(desiredBy.formatted(date: .abbreviated, time: .omitted))
            if let relative = desiredBy.cfRelativeDay(now: now) {
                object["desired_in"] = .string(relative)
            }
        }
        if let category = item.category { object["category"] = .string(category.name) }
        return object
    }

    static func goalJSON(_ goal: FinancialGoal, snapshot: GoalProgressSnapshot) -> [String: AIToolJSONValue] {
        var object: [String: AIToolJSONValue] = [
            "id": .string(goal.id.uuidString),
            "name": .string(goal.name),
            "current": .from(snapshot.currentAmount),
            "target": .from(snapshot.targetAmount),
            "progress_percent": .double(snapshot.progress * 100),
            "completed": .bool(goal.isCompleted)
        ]
        if let deadline = goal.deadline {
            object["deadline"] = .string(deadline.formatted(date: .abbreviated, time: .omitted))
            if let relative = deadline.cfRelativeDay() {
                object["deadline_in"] = .string(relative)
            }
        }
        if let monthly = snapshot.monthlyNeeded {
            object["monthly_needed"] = .from(monthly)
        }
        if let months = snapshot.monthsRemaining {
            object["months_remaining"] = .int(months)
        }
        if !goal.notes.isEmpty { object["notes"] = .string(goal.notes) }
        return object
    }

    static func recurringExpenseJSON(_ rule: RecurringExpense) -> [String: AIToolJSONValue] {
        var object: [String: AIToolJSONValue] = [
            "id": .string(rule.id.uuidString),
            "name": .string(rule.name),
            "amount": .from(rule.amount),
            "day_of_month": .int(rule.dayOfMonth),
            "paused": .bool(rule.isPaused),
            "requires_confirmation": .bool(rule.requiresConfirmation)
        ]
        if let account = rule.account { object["account"] = .string(account.name) }
        if let category = rule.category { object["category"] = .string(category.name) }
        return object
    }

    static func recurringIncomeJSON(_ rule: RecurringIncome) -> [String: AIToolJSONValue] {
        var object: [String: AIToolJSONValue] = [
            "id": .string(rule.id.uuidString),
            "name": .string(rule.name),
            "amount": .from(rule.amount),
            "day_of_month": .int(rule.dayOfMonth),
            "paused": .bool(rule.isPaused),
            "requires_confirmation": .bool(rule.requiresConfirmation)
        ]
        if let account = rule.account { object["account"] = .string(account.name) }
        if let category = rule.category { object["category"] = .string(category.name) }
        return object
    }

    static func patrimonyJSON(_ overview: FinancialOverview) -> [String: AIToolJSONValue] {
        [
            "net_worth": .from(overview.netWorth),
            "liquid_balance": .from(overview.liquidBalance),
            "debt_balance": .from(overview.debtBalance),
            "investment_balance": .from(overview.investmentBalance),
            "goal_reserved_balance": .from(overview.goalReservedBalance),
            "pending_bills_total": .from(overview.pendingBillsTotal),
            "overdue_bills_count": .int(overview.overdueBillsCount)
        ]
    }

    static func monthSummaryJSON(_ summary: MonthSummary) -> [String: AIToolJSONValue] {
        [
            "reference_month": .string(summary.referenceDate.formatted(.dateTime.month(.wide).year())),
            "total_income": .from(summary.totalIncome),
            "total_expense": .from(summary.totalExpense),
            "balance": .from(summary.balance),
            "planned_income": .from(summary.plannedIncome),
            "planned_expense": .from(summary.plannedExpense),
            "pending_receivable_income": .from(summary.pendingReceivableIncome),
            "expected_income": .from(summary.expectedIncome),
            "projected_balance": .from(summary.projectedBalance),
            "uses_fallback_income": .bool(summary.usesFallbackIncome)
        ]
    }

    static func monthPaceJSON(_ summary: MonthSummary) -> [String: AIToolJSONValue] {
        [
            "pace_state": .string(summary.paceState.label),
            "spent_ratio_percent": .double(summary.spentRatio * 100),
            "day_progress_percent": .double(summary.dayProgress * 100),
            "days_remaining": .int(summary.daysRemaining),
            "daily_budget_remaining": .from(summary.dailyBudgetRemaining)
        ]
    }
}
