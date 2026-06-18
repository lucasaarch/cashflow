import Foundation

enum AIToolReaders {
    static func execute(name: String, args: [String: Any], context: AIToolContext) throws -> AIToolResultPayload {
        switch name {
        case "get_app_context": return getAppContext(context)
        case "get_app_settings": return getAppSettings(context)
        case "get_patrimony": return getPatrimony(args, context)
        case "list_accounts": return listAccounts(args, context)
        case "get_account": return try getAccount(args, context)
        case "get_month_summary": return getMonthSummary(args, context)
        case "get_month_pace": return getMonthPace(args, context)
        case "compare_months": return compareMonths(args, context)
        case "search_transactions": return try searchTransactions(args, context)
        case "list_month_transactions": return listMonthTransactions(args, context)
        case "get_transaction": return try getTransaction(args, context)
        case "list_recent_transactions": return listRecentTransactions(args, context)
        case "list_bills": return try listBills(args, context)
        case "get_bill": return try getBill(args, context)
        case "get_bills_summary": return getBillsSummary(args, context)
        case "list_receivables": return listReceivables(args, context)
        case "get_receivable": return try getReceivable(args, context)
        case "get_receivables_summary": return getReceivablesSummary(args, context)
        case "list_recurring_expenses": return listRecurringExpenses(args, context)
        case "list_recurring_incomes": return listRecurringIncomes(args, context)
        case "get_recurring_expense": return try getRecurringExpense(args, context)
        case "get_recurring_income": return try getRecurringIncome(args, context)
        case "list_goals": return listGoals(args, context)
        case "list_wishlist": return listWishlist(context)
        case "get_goal": return try getGoal(args, context)
        case "get_investments_summary": return getInvestmentsSummary(args, context)
        case "list_fund_accounts": return listFundAccounts(args, context)
        case "list_transfers": return listTransfers(args, context)
        case "list_credit_cards": return listCreditCards(context)
        case "get_card_statement": return try getCardStatement(args, context)
        case "list_categories": return listCategories(args, context)
        case "get_category_breakdown": return getCategoryBreakdown(args, context)
        case "get_expenses_by_account": return getExpensesByAccount(args, context)
        case "get_cash_flow_series": return try getCashFlowSeries(args, context)
        case "get_net_worth_series": return try getNetWorthSeries(args, context)
        case "get_investment_flow_series": return try getInvestmentFlowSeries(args, context)
        default:
            throw AIToolExecutorError.unknownTool(name)
        }
    }

    // MARK: - A

    private static func getAppContext(_ context: AIToolContext) -> AIToolResultPayload {
        let ref = context.now
        let month = ref.formatted(.dateTime.month(.wide).year())
        return .success(.object([
            "now": .string(ref.formatted(date: .abbreviated, time: .shortened)),
            "reference_month": .string(month),
            "currency": .string("BRL"),
            "rules": .string("Realizado = data ≤ hoje. Previsto = lançamentos futuros no mês + contas a receber pendentes.")
        ]))
    }

    private static func getAppSettings(_ context: AIToolContext) -> AIToolResultPayload {
        .success(.object([
            "monthly_income_fallback": .from(Decimal(context.monthlyIncomeCents) / 100)
        ]))
    }

    // MARK: - B

    private static func getPatrimony(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let asOf = AIToolJSON.date(args, key: "as_of_date", calendar: context.calendar) ?? context.now
        let overview = context.overview(asOf: asOf)
        return .success(.object(AIToolFormatters.patrimonyJSON(overview)))
    }

    private static func listAccounts(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let asOf = AIToolJSON.date(args, key: "as_of_date", calendar: context.calendar) ?? context.now
        let includeArchived = AIToolJSON.bool(args, key: "include_archived") ?? false
        let kindFilter = AIToolJSON.string(args, key: "kind").flatMap { AccountKind(rawValue: $0) }

        let accounts = context.accounts.filter { account in
            if !includeArchived && account.isArchived { return false }
            if let kindFilter, account.kind != kindFilter { return false }
            return true
        }

        let items: [AIToolJSONValue] = accounts.map { account in
            let balance = account.currentBalance(considering: context.transactions, asOf: asOf)
            return .object(AIToolFormatters.accountJSON(account, balance: balance))
        }
        return .success(.object(["accounts": .array(items)]))
    }

    private static func getAccount(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let asOf = AIToolJSON.date(args, key: "as_of_date", calendar: context.calendar) ?? context.now
        let account = try AIToolResolver.account(
            in: context.accounts,
            id: AIToolJSON.uuid(args, key: "account_id"),
            name: AIToolJSON.string(args, key: "account_name")
        )
        let balance = account.currentBalance(considering: context.transactions, asOf: asOf)
        return .success(.object(AIToolFormatters.accountJSON(account, balance: balance)))
    }

    // MARK: - C

    private static func getMonthSummary(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let ref = context.referenceDate(from: args)
        let summary = context.monthSummary(referenceDate: ref)
        return .success(.object(AIToolFormatters.monthSummaryJSON(summary)))
    }

    private static func getMonthPace(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let ref = context.referenceDate(from: args)
        let summary = context.monthSummary(referenceDate: ref)
        return .success(.object(AIToolFormatters.monthPaceJSON(summary)))
    }

    private static func compareMonths(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let ref = context.referenceDate(from: args)
        let comparison = context.reportBuilder(referenceDate: ref, period: .threeMonths).monthComparison
        return .success(.object([
            "current_income": .from(comparison.currentIncome),
            "current_expense": .from(comparison.currentExpense),
            "previous_income": .from(comparison.previousIncome),
            "previous_expense": .from(comparison.previousExpense),
            "income_delta_percent": comparison.incomeDeltaPercent.map { .double($0) } ?? .null,
            "expense_delta_percent": comparison.expenseDeltaPercent.map { .double($0) } ?? .null
        ]))
    }

    // MARK: - D

    private static func searchTransactions(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let limit = min(AIToolJSON.int(args, key: "limit") ?? 30, 100)
        let includeTransfers = AIToolJSON.bool(args, key: "include_transfers") ?? false
        let status = AIToolJSON.string(args, key: "status") ?? "all"
        var dateFrom = AIToolJSON.date(args, key: "date_from", calendar: context.calendar)
        var dateTo = AIToolJSON.date(args, key: "date_to", calendar: context.calendar)
        let kindFilter = AIToolJSON.string(args, key: "kind")
        let text = AIToolJSON.string(args, key: "text")?.lowercased()
        let categoryNameQuery = AIToolJSON.string(args, key: "category_name")

        let account = try? AIToolResolver.account(
            in: context.accounts,
            id: AIToolJSON.uuid(args, key: "account_id"),
            name: AIToolJSON.string(args, key: "account_name")
        )
        let category = try? AIToolResolver.category(
            in: context.categories,
            id: AIToolJSON.uuid(args, key: "category_id"),
            name: categoryNameQuery
        )

        let hasScopedFilter = text != nil || category != nil || categoryNameQuery != nil
        if dateFrom == nil, dateTo == nil, hasScopedFilter,
           let monthInterval = context.calendar.dateInterval(of: .month, for: context.now) {
            dateFrom = monthInterval.start
            dateTo = monthInterval.end.addingTimeInterval(-1)
        }

        let results = context.transactions.filter { txn in
            if !includeTransfers && txn.isTransfer { return false }
            if let account, txn.account?.id != account.id { return false }
            if let category, txn.category?.id != category.id { return false }
            if let kindFilter, txn.kind.rawValue != kindFilter { return false }
            if let dateFrom, txn.occurredOn < dateFrom { return false }
            if let dateTo, txn.occurredOn > dateTo { return false }
            if let text {
                let haystack = [
                    txn.note,
                    txn.category?.name ?? "",
                    txn.account?.name ?? ""
                ].joined(separator: " ").lowercased()
                if !haystack.contains(text) { return false }
            } else if let categoryNameQuery, category == nil {
                let normalized = categoryNameQuery.lowercased()
                let categoryName = txn.category?.name.lowercased() ?? ""
                if !categoryName.contains(normalized) { return false }
            }
            switch status {
            case "realized": if txn.occurredOn > context.now { return false }
            case "planned": if txn.occurredOn <= context.now { return false }
            default: break
            }
            return true
        }
        .sorted { $0.occurredOn > $1.occurredOn }
        .prefix(limit)

        let items = results.map {
            AIToolJSONValue.object(AIToolFormatters.transactionJSON($0, calendar: context.calendar, now: context.now))
        }
        return .success(.object([
            "count": .int(items.count),
            "transactions": .array(Array(items))
        ]))
    }

    private static func listMonthTransactions(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let ref = context.referenceDate(from: args)
        let status = AIToolJSON.string(args, key: "status") ?? "all"
        let excludeTransfers = AIToolJSON.bool(args, key: "exclude_transfers") ?? false
        let summary = context.monthSummary(referenceDate: ref)

        var txns: [Transaction]
        switch status {
        case "realized":
            txns = summary.realizedMonthlyTransactions
        case "planned":
            txns = summary.plannedMonthlyTransactions
        default:
            txns = summary.monthlyTransactions
        }
        if excludeTransfers {
            txns = txns.filter { !$0.isTransfer }
        }

        let items = txns.sorted { $0.occurredOn > $1.occurredOn }.map {
            AIToolJSONValue.object(AIToolFormatters.transactionJSON($0, calendar: context.calendar, now: context.now))
        }
        return .success(.object(["transactions": .array(items)]))
    }

    private static func getTransaction(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let txn = try AIToolResolver.transaction(in: context.transactions, id: AIToolJSON.uuid(args, key: "transaction_id"))
        return .success(.object(AIToolFormatters.transactionJSON(txn, calendar: context.calendar, now: context.now)))
    }

    private static func listRecentTransactions(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let days = AIToolJSON.int(args, key: "days") ?? 90
        let limit = AIToolJSON.int(args, key: "limit") ?? 30
        let cutoff = context.calendar.date(byAdding: .day, value: -days, to: context.now) ?? context.now
        let items = context.transactions
            .filter { $0.occurredOn >= cutoff }
            .sorted { $0.occurredOn > $1.occurredOn }
            .prefix(limit)
            .map { AIToolJSONValue.object(AIToolFormatters.transactionJSON($0, calendar: context.calendar, now: context.now)) }
        return .success(.object(["transactions": .array(Array(items))]))
    }

    // MARK: - E

    private static func listBills(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let status = AIToolJSON.string(args, key: "status") ?? "pending"
        let overdueOnly = AIToolJSON.bool(args, key: "overdue_only") ?? false
        let dueBefore = AIToolJSON.date(args, key: "due_before", calendar: context.calendar)
        let dueAfter = AIToolJSON.date(args, key: "due_after", calendar: context.calendar)
        let limit = AIToolJSON.int(args, key: "limit") ?? 50
        let accountID = AIToolJSON.uuid(args, key: "account_id")

        let bills = context.bills.filter { bill in
            switch status {
            case "pending": if !bill.isPending { return false }
            case "paid": if !bill.isPaid { return false }
            case "cancelled": if bill.status != .cancelled { return false }
            default: break
            }
            if overdueOnly && !bill.isOverdue(now: context.now) { return false }
            if let dueBefore, bill.dueDate > dueBefore { return false }
            if let dueAfter, bill.dueDate < dueAfter { return false }
            if let accountID, bill.account?.id != accountID { return false }
            return true
        }
        .sorted { $0.dueDate < $1.dueDate }
        .prefix(limit)

        let items = bills.map { AIToolJSONValue.object(AIToolFormatters.billJSON($0, now: context.now)) }
        return .success(.object(["bills": .array(Array(items))]))
    }

    private static func getBill(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let bill = try AIToolResolver.bill(
            in: context.bills,
            id: AIToolJSON.uuid(args, key: "bill_id"),
            name: AIToolJSON.string(args, key: "bill_name")
        )
        return .success(.object(AIToolFormatters.billJSON(bill, now: context.now)))
    }

    private static func getBillsSummary(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let overview = context.overview()
        let builder = context.reportBuilder(referenceDate: context.referenceDate(from: args), period: .threeMonths)
        let groups = builder.pendingBillsByMonth.map { group in
            AIToolJSONValue.object([
                "month": .string(group.month.formatted(.dateTime.month(.abbreviated).year())),
                "total": .from(group.total),
                "count": .int(group.bills.count)
            ])
        }
        return .success(.object([
            "pending_total": .from(overview.pendingBillsTotal),
            "overdue_count": .int(overview.overdueBillsCount),
            "by_month": .array(groups)
        ]))
    }

    // MARK: - F

    private static func listReceivables(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let status = AIToolJSON.string(args, key: "status") ?? "pending"
        let lateOnly = AIToolJSON.bool(args, key: "late_only") ?? false
        let expectedInMonth = AIToolJSON.bool(args, key: "expected_in_month") ?? false
        let ref = context.referenceDate(from: args)
        let limit = AIToolJSON.int(args, key: "limit") ?? 50
        let monthInterval = context.calendar.dateInterval(of: .month, for: ref)

        let items = context.receivables.filter { receivable in
            switch status {
            case "pending": if !receivable.isPending { return false }
            case "received": if !receivable.isReceived { return false }
            default: break
            }
            if lateOnly && !receivable.isLate(now: context.now) { return false }
            if expectedInMonth, let monthInterval {
                if !monthInterval.contains(receivable.expectedDate) { return false }
            }
            return true
        }
        .sorted { $0.expectedDate < $1.expectedDate }
        .prefix(limit)
        .map { AIToolJSONValue.object(AIToolFormatters.receivableJSON($0, now: context.now)) }

        return .success(.object(["receivables": .array(Array(items))]))
    }

    private static func getReceivable(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let receivable = try AIToolResolver.receivable(
            in: context.receivables,
            id: AIToolJSON.uuid(args, key: "receivable_id"),
            name: AIToolJSON.string(args, key: "receivable_name")
        )
        return .success(.object(AIToolFormatters.receivableJSON(receivable, now: context.now)))
    }

    private static func getReceivablesSummary(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let ref = context.referenceDate(from: args)
        let summary = context.monthSummary(referenceDate: ref)
        let pending = context.receivables.filter(\.isPending)
        let late = pending.filter { $0.isLate(now: context.now) }
        let lateTotal = late.reduce(Decimal(0)) { $0 + $1.amount }
        let pendingTotal = pending.reduce(Decimal(0)) { $0 + $1.amount }
        return .success(.object([
            "pending_total": .from(pendingTotal),
            "late_count": .int(late.count),
            "late_total": .from(lateTotal),
            "expected_in_month": .from(summary.pendingReceivableIncome)
        ]))
    }

    // MARK: - G

    private static func listRecurringExpenses(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let activeOnly = AIToolJSON.bool(args, key: "active_only") ?? true
        let includePaused = AIToolJSON.bool(args, key: "include_paused") ?? false
        let rules = context.recurringExpenses.filter { rule in
            if activeOnly && rule.isPaused { return false }
            if !includePaused && rule.isPaused { return false }
            return true
        }
        let items = rules.map { AIToolJSONValue.object(AIToolFormatters.recurringExpenseJSON($0)) }
        return .success(.object(["recurring_expenses": .array(items)]))
    }

    private static func listRecurringIncomes(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let activeOnly = AIToolJSON.bool(args, key: "active_only") ?? true
        let includePaused = AIToolJSON.bool(args, key: "include_paused") ?? false
        let rules = context.recurringIncomes.filter { rule in
            if activeOnly && rule.isPaused { return false }
            if !includePaused && rule.isPaused { return false }
            return true
        }
        let items = rules.map { AIToolJSONValue.object(AIToolFormatters.recurringIncomeJSON($0)) }
        return .success(.object(["recurring_incomes": .array(items)]))
    }

    private static func getRecurringExpense(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let rule = try AIToolResolver.recurringExpense(
            in: context.recurringExpenses,
            id: AIToolJSON.uuid(args, key: "rule_id"),
            name: AIToolJSON.string(args, key: "name")
        )
        return .success(.object(AIToolFormatters.recurringExpenseJSON(rule)))
    }

    private static func getRecurringIncome(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let rule = try AIToolResolver.recurringIncome(
            in: context.recurringIncomes,
            id: AIToolJSON.uuid(args, key: "rule_id"),
            name: AIToolJSON.string(args, key: "name")
        )
        return .success(.object(AIToolFormatters.recurringIncomeJSON(rule)))
    }

    // MARK: - H

    private static func listGoals(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let activeOnly = AIToolJSON.bool(args, key: "active_only") ?? true
        let includeCompleted = AIToolJSON.bool(args, key: "include_completed") ?? false
        let ref = context.now
        let goals = context.goals.filter { goal in
            if activeOnly && goal.isCompleted { return false }
            if !includeCompleted && goal.isCompleted { return false }
            return true
        }
        let items = goals.map { goal in
            let snapshot = GoalProgressCalculator.snapshot(for: goal, transactions: context.transactions, asOf: ref, calendar: context.calendar)
            return AIToolJSONValue.object(AIToolFormatters.goalJSON(goal, snapshot: snapshot))
        }
        return .success(.object(["goals": .array(items)]))
    }

    private static func listWishlist(_ context: AIToolContext) -> AIToolResultPayload {
        let sorted = WishlistSortOrder.sorted(context.wishlistItems)
        let items = sorted.map { AIToolJSONValue.object(AIToolFormatters.wishlistItemJSON($0, now: context.now)) }
        let total = sorted.reduce(Decimal.zero) { $0 + $1.estimatedAmount }
        let byPriority = Dictionary(grouping: sorted, by: \.priority.rawValue)
            .mapValues { group in group.reduce(Decimal.zero) { $0 + $1.estimatedAmount } }
        var priorityTotals: [String: AIToolJSONValue] = [:]
        for (key, value) in byPriority {
            priorityTotals[key] = .from(value)
        }
        return .success(.object([
            "items": .array(items),
            "total_estimated": .from(total),
            "count": .int(sorted.count),
            "totals_by_priority": .object(priorityTotals)
        ]))
    }

    private static func getGoal(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let goal = try AIToolResolver.goal(
            in: context.goals,
            id: AIToolJSON.uuid(args, key: "goal_id"),
            name: AIToolJSON.string(args, key: "goal_name")
        )
        let snapshot = GoalProgressCalculator.snapshot(for: goal, transactions: context.transactions, asOf: context.now, calendar: context.calendar)
        return .success(.object(AIToolFormatters.goalJSON(goal, snapshot: snapshot)))
    }

    // MARK: - I

    private static func getInvestmentsSummary(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let ref = context.referenceDate(from: args)
        let summary = context.monthSummary(referenceDate: ref)
        let overview = context.overview(asOf: ref)
        return .success(.object([
            "investment_balance": .from(overview.investmentBalance),
            "goal_reserved_balance": .from(overview.goalReservedBalance),
            "net_invested_this_month": .from(summary.investedThisMonth)
        ]))
    }

    private static func listFundAccounts(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let asOf = AIToolJSON.date(args, key: "as_of_date", calendar: context.calendar) ?? context.now
        let kindFilter = AIToolJSON.string(args, key: "kind")
        let accounts = context.activeAccounts.filter { account in
            guard account.kind == .investment || account.kind == .goal else { return false }
            if let kindFilter, account.kind.rawValue != kindFilter { return false }
            return true
        }
        let items = accounts.map { account in
            let balance = account.currentBalance(considering: context.transactions, asOf: asOf)
            return AIToolJSONValue.object(AIToolFormatters.accountJSON(account, balance: balance))
        }
        return .success(.object(["fund_accounts": .array(items)]))
    }

    private static func listTransfers(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let limit = AIToolJSON.int(args, key: "limit") ?? 30
        let dateFrom = AIToolJSON.date(args, key: "date_from", calendar: context.calendar)
        let dateTo = AIToolJSON.date(args, key: "date_to", calendar: context.calendar)
        let fundKind = AIToolJSON.string(args, key: "fund_kind")
        let direction = AIToolJSON.string(args, key: "direction")

        var rows = FundTransferHistory.build(from: context.transactions, limit: 200)
        if let dateFrom { rows = rows.filter { $0.date >= dateFrom } }
        if let dateTo { rows = rows.filter { $0.date <= dateTo } }
        if let fundKind {
            rows = rows.filter { $0.fundKind.rawValue == fundKind }
        }
        if let direction {
            let isDeposit = direction == "deposit"
            rows = rows.filter { row in
                let deposit = row.title.contains("Aporte") || row.title.contains("Depósito")
                return isDeposit ? deposit : !deposit
            }
        }

        let items = rows.prefix(limit).map { row in
            AIToolJSONValue.object([
                "date": .string(row.date.formatted(date: .abbreviated, time: .omitted)),
                "amount": .from(row.amount),
                "title": .string(row.title),
                "subtitle": .string(row.subtitle),
                "planned": .bool(row.isPlanned)
            ])
        }
        return .success(.object(["transfers": .array(Array(items))]))
    }

    // MARK: - J

    private static func listCreditCards(_ context: AIToolContext) -> AIToolResultPayload {
        let cards = context.activeAccounts.filter { $0.kind == .creditCard }
        let items = cards.map { card in
            let balance = card.currentBalance(considering: context.transactions)
            let debt = max(0, -balance)
            return AIToolJSONValue.object([
                "id": .string(card.id.uuidString),
                "name": .string(card.name),
                "debt": .from(debt),
                "closing_day": .int(card.closingDay),
                "due_day": .int(card.dueDay)
            ])
        }
        return .success(.object(["credit_cards": .array(items)]))
    }

    private static func getCardStatement(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let card = try AIToolResolver.account(
            in: context.accounts,
            id: AIToolJSON.uuid(args, key: "account_id"),
            name: AIToolJSON.string(args, key: "account_name"),
            kinds: [.creditCard]
        )
        let statement = CreditCardBilling.openStatement(
            for: card,
            transactions: context.transactions,
            asOf: context.now,
            calendar: context.calendar
        )
        let items = statement.items.map { line -> AIToolJSONValue in
            switch line {
            case .openingBalance(let amount):
                return .object(["type": .string("opening_balance"), "amount": .from(amount)])
            case .expense(let txn):
                return .object(AIToolFormatters.transactionJSON(txn, calendar: context.calendar, now: context.now))
            case .payment(let txn):
                return .object(AIToolFormatters.transactionJSON(txn, calendar: context.calendar, now: context.now))
            }
        }
        return .success(.object([
            "card": .string(card.name),
            "total_debt": .from(statement.totalDebt),
            "closing_date": statement.closingDate.map { .string($0.formatted(date: .abbreviated, time: .omitted)) } ?? .null,
            "due_date": statement.dueDate.map { .string($0.formatted(date: .abbreviated, time: .omitted)) } ?? .null,
            "items": .array(items)
        ]))
    }

    // MARK: - K

    private static func listCategories(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let kindFilter = AIToolJSON.string(args, key: "kind").flatMap { CategoryKind(rawValue: $0) }
        let categories = context.categories.filter { category in
            guard let kindFilter else { return true }
            return category.kind == kindFilter
        }
        let items = categories.map { category in
            AIToolJSONValue.object([
                "id": .string(category.id.uuidString),
                "name": .string(category.name),
                "kind": .string(category.kind.rawValue)
            ])
        }
        return .success(.object(["categories": .array(items)]))
    }

    private static func getCategoryBreakdown(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let ref = context.referenceDate(from: args)
        let period = ReportPeriod(rawValue: AIToolJSON.string(args, key: "period") ?? "6m") ?? .sixMonths
        let limit = AIToolJSON.int(args, key: "limit") ?? 8
        let kind = AIToolJSON.string(args, key: "kind") ?? "expense"

        if kind == "expense" {
            let builder = context.reportBuilder(referenceDate: ref, period: period)
            let top = builder.topCategoryExpenses.prefix(limit)
            let items = top.map { point in
                AIToolJSONValue.object([
                    "category": .string(point.category.name),
                    "total": .from(point.total)
                ])
            }
            return .success(.object(["categories": .array(Array(items))]))
        }

        let summary = context.monthSummary(referenceDate: ref)
        let items = summary.expensesByCategory.prefix(limit).map { item in
            AIToolJSONValue.object([
                "category": .string(item.category.name),
                "total": .from(item.total),
                "count": .int(item.count)
            ])
        }
        return .success(.object(["categories": .array(Array(items))]))
    }

    private static func getExpensesByAccount(_ args: [String: Any], _ context: AIToolContext) -> AIToolResultPayload {
        let ref = context.referenceDate(from: args)
        let summary = context.monthSummary(referenceDate: ref)
        let items = summary.expensesByAccount.map { item in
            AIToolJSONValue.object([
                "account": .string(item.account.name),
                "total": .from(item.total),
                "count": .int(item.count)
            ])
        }
        return .success(.object(["accounts": .array(items)]))
    }

    // MARK: - L

    private static func getCashFlowSeries(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let period = try parsePeriod(args)
        let ref = context.referenceDate(from: args)
        let series = context.reportBuilder(referenceDate: ref, period: period).cashFlowSeries
        return seriesPayload(series.map { point in
            [
                "month": .string(point.month.formatted(.dateTime.month(.abbreviated).year())),
                "income": .from(point.income),
                "expense": .from(point.expense),
                "net": .from(point.net)
            ]
        })
    }

    private static func getNetWorthSeries(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let period = try parsePeriod(args)
        let ref = context.referenceDate(from: args)
        let series = context.reportBuilder(referenceDate: ref, period: period).netWorthSeries
        return seriesPayload(series.map { point in
            [
                "month": .string(point.month.formatted(.dateTime.month(.abbreviated).year())),
                "liquid": .from(point.liquid),
                "debt": .from(point.debt),
                "invested": .from(point.invested),
                "net_worth": .from(point.netWorth)
            ]
        })
    }

    private static func getInvestmentFlowSeries(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let period = try parsePeriod(args)
        let ref = context.referenceDate(from: args)
        let series = context.reportBuilder(referenceDate: ref, period: period).investmentFlowSeries
        return seriesPayload(series.map { point in
            [
                "month": .string(point.month.formatted(.dateTime.month(.abbreviated).year())),
                "net_invested": .from(point.netInvested)
            ]
        })
    }

    private static func parsePeriod(_ args: [String: Any]) throws -> ReportPeriod {
        guard let raw = AIToolJSON.string(args, key: "period"),
              let period = ReportPeriod(rawValue: raw) else {
            throw AIToolExecutorError.invalidArguments("Parâmetro period obrigatório (3m, 6m, 12m, ytd).")
        }
        return period
    }

    private static func seriesPayload(_ points: [[String: AIToolJSONValue]]) -> AIToolResultPayload {
        .success(.object(["series": .array(points.map { .object($0) })]))
    }
}
