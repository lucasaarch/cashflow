import Foundation
import SwiftData

struct AIPendingWriteAction: Identifiable, Codable, Hashable {
    enum Source: String, Codable {
        case agent
        case mcp
    }

    let id: UUID
    let toolCallID: String
    let toolName: String
    let argumentsJSON: String
    let summary: String
    let source: Source

    enum CodingKeys: String, CodingKey {
        case id
        case toolCallID = "tool_call_id"
        case toolName = "tool_name"
        case argumentsJSON = "arguments_json"
        case summary
        case source
    }

    init(
        id: UUID,
        toolCallID: String,
        toolName: String,
        argumentsJSON: String,
        summary: String,
        source: Source = .agent
    ) {
        self.id = id
        self.toolCallID = toolCallID
        self.toolName = toolName
        self.argumentsJSON = argumentsJSON
        self.summary = summary
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        toolCallID = try container.decode(String.self, forKey: .toolCallID)
        toolName = try container.decode(String.self, forKey: .toolName)
        argumentsJSON = try container.decode(String.self, forKey: .argumentsJSON)
        summary = try container.decode(String.self, forKey: .summary)
        source = try container.decodeIfPresent(Source.self, forKey: .source) ?? .agent
    }
}

enum AIToolWriters {
    static func buildSummary(toolName: String, args: [String: Any], context: AIToolContext) throws -> String {
        switch toolName {
        case "record_fund_transfer":
            let direction = AIToolJSON.string(args, key: "direction") ?? "deposit"
            let amount = try requireDecimal(args, key: "amount")
            let bank = AIToolJSON.string(args, key: "bank_account") ?? "?"
            let fund = AIToolJSON.string(args, key: "fund_account") ?? "?"
            let verb = direction == "withdraw" ? "Resgatar" : "Aportar"
            return "\(verb) \(amount.brl) de \(bank) para \(fund)"

        case "create_transaction":
            let kind = AIToolJSON.string(args, key: "kind") ?? "expense"
            let amount = try requireDecimal(args, key: "amount")
            let account = AIToolJSON.string(args, key: "account") ?? "?"
            let label = kind == "income" ? "Registrar receita" : "Registrar despesa"
            return "\(label) de \(amount.brl) em \(account)"

        case "pay_bill":
            let bill = AIToolJSON.string(args, key: "bill") ?? "?"
            let amount = AIToolJSON.decimal(args, key: "amount")
            if let amount {
                return "Pagar \(bill) — \(amount.brl)"
            }
            return "Pagar conta: \(bill)"

        case "confirm_receivable":
            let name = AIToolJSON.string(args, key: "receivable") ?? "?"
            let amount = AIToolJSON.decimal(args, key: "amount")
            if let amount {
                return "Confirmar recebimento de \(name) — \(amount.brl)"
            }
            return "Confirmar recebimento: \(name)"

        case "create_bill":
            let name = AIToolJSON.string(args, key: "name") ?? "?"
            let amount = try requireDecimal(args, key: "amount")
            return "Criar conta a pagar \(name) — \(amount.brl)"

        case "create_receivable":
            let name = AIToolJSON.string(args, key: "name") ?? "?"
            let amount = try requireDecimal(args, key: "amount")
            return "Criar conta a receber \(name) — \(amount.brl)"

        case "reschedule_bill":
            let bill = AIToolJSON.string(args, key: "bill") ?? "?"
            let date = AIToolJSON.string(args, key: "new_due_date") ?? "?"
            return "Reagendar \(bill) para \(date)"

        case "reschedule_receivable":
            let name = AIToolJSON.string(args, key: "receivable") ?? "?"
            let date = AIToolJSON.string(args, key: "new_expected_date") ?? "?"
            return "Reagendar \(name) para \(date)"

        case "pay_card_invoice":
            let card = AIToolJSON.string(args, key: "card_account") ?? "?"
            let bank = AIToolJSON.string(args, key: "bank_account") ?? "?"
            let amount = try requireDecimal(args, key: "amount")
            return "Pagar fatura \(card) (\(amount.brl)) via \(bank)"

        case "create_wishlist_item":
            let name = AIToolJSON.string(args, key: "name") ?? "?"
            let amount = try requireDecimal(args, key: "estimated_amount")
            return "Adicionar à lista de desejos: \(name) — \(amount.brl)"

        case "update_wishlist_item":
            let name = AIToolJSON.string(args, key: "item_name") ?? AIToolJSON.string(args, key: "item_id") ?? "?"
            return "Atualizar desejo: \(name)"

        case "delete_wishlist_item":
            let name = AIToolJSON.string(args, key: "item_name") ?? AIToolJSON.string(args, key: "item_id") ?? "?"
            return "Remover da lista: \(name)"

        case "purchase_wishlist_item":
            let name = AIToolJSON.string(args, key: "item_name") ?? AIToolJSON.string(args, key: "item_id") ?? "?"
            let amount = AIToolJSON.decimal(args, key: "amount")
            if let amount {
                return "Registrar compra de \(name) — \(amount.brl)"
            }
            return "Registrar compra: \(name)"

        case "cancel_bill":
            let bill = AIToolJSON.string(args, key: "bill") ?? "?"
            return "Cancelar conta a pagar: \(bill)"

        case "cancel_receivable":
            let name = AIToolJSON.string(args, key: "receivable") ?? "?"
            return "Cancelar conta a receber: \(name)"

        case "update_bill":
            return try updateBillSummary(args, context)

        case "update_receivable":
            return try updateReceivableSummary(args, context)

        case "update_transaction":
            return try updateTransactionSummary(args, context)

        case "delete_transaction":
            return try deleteTransactionSummary(args, context)

        case "create_recurring_expense":
            let name = AIToolJSON.string(args, key: "name") ?? "?"
            let amount = try requireDecimal(args, key: "amount")
            return "Criar despesa fixa \(name) — \(amount.brl)/mês"

        case "create_recurring_income":
            let name = AIToolJSON.string(args, key: "name") ?? "?"
            let amount = try requireDecimal(args, key: "amount")
            return "Criar renda fixa \(name) — \(amount.brl)/mês"

        case "create_goal":
            let name = AIToolJSON.string(args, key: "name") ?? "?"
            let amount = try requireDecimal(args, key: "target_amount")
            return "Criar meta \(name) — alvo \(amount.brl)"

        default:
            throw AIToolExecutorError.unknownTool(toolName)
        }
    }

    static func execute(
        toolName: String,
        args: [String: Any],
        context: AIToolContext
    ) throws -> AIToolResultPayload {
        switch toolName {
        case "record_fund_transfer": return try recordFundTransfer(args, context)
        case "create_transaction": return try createTransaction(args, context)
        case "pay_bill": return try payBill(args, context)
        case "confirm_receivable": return try confirmReceivable(args, context)
        case "create_bill": return try createBill(args, context)
        case "create_receivable": return try createReceivable(args, context)
        case "reschedule_bill": return try rescheduleBill(args, context)
        case "reschedule_receivable": return try rescheduleReceivable(args, context)
        case "pay_card_invoice": return try payCardInvoice(args, context)
        case "create_wishlist_item": return try createWishlistItem(args, context)
        case "update_wishlist_item": return try updateWishlistItem(args, context)
        case "delete_wishlist_item": return try deleteWishlistItem(args, context)
        case "purchase_wishlist_item": return try purchaseWishlistItem(args, context)
        case "cancel_bill": return try cancelBill(args, context)
        case "cancel_receivable": return try cancelReceivable(args, context)
        case "update_bill": return try updateBill(args, context)
        case "update_receivable": return try updateReceivable(args, context)
        case "update_transaction": return try updateTransaction(args, context)
        case "delete_transaction": return try deleteTransaction(args, context)
        case "create_recurring_expense": return try createRecurringExpense(args, context)
        case "create_recurring_income": return try createRecurringIncome(args, context)
        case "create_goal": return try createGoal(args, context)
        default:
            throw AIToolExecutorError.unknownTool(toolName)
        }
    }

    // MARK: - Writes

    private static func recordFundTransfer(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        guard let directionRaw = AIToolJSON.string(args, key: "direction"),
              let direction = FundTransferDirection(rawValue: directionRaw) else {
            throw AIToolExecutorError.invalidArguments("direction deve ser deposit ou withdraw.")
        }
        let amount = try requireDecimal(args, key: "amount")
        guard amount > 0 else { throw AIToolExecutorError.invalidArguments("Valor deve ser positivo.") }

        let bank = try AIToolResolver.account(
            in: context.accounts,
            id: nil,
            name: AIToolJSON.string(args, key: "bank_account"),
            kinds: [.bank]
        )
        let fund = try AIToolResolver.account(
            in: context.accounts,
            id: nil,
            name: AIToolJSON.string(args, key: "fund_account"),
            kinds: [.investment, .goal]
        )
        let date = AIToolJSON.date(args, key: "date", calendar: context.calendar) ?? context.now
        let note = AIToolJSON.string(args, key: "note") ?? ""

        FundTransferRecorder.record(
            in: context.modelContext,
            direction: direction,
            amount: amount,
            occurredOn: date,
            bankAccount: bank,
            fundAccount: fund,
            note: note
        )

        return .success(.object([
            "direction": .string(direction.rawValue),
            "amount": .from(amount),
            "bank_account": .string(bank.name),
            "fund_account": .string(fund.name)
        ]))
    }

    private static func createTransaction(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        guard let kindRaw = AIToolJSON.string(args, key: "kind"),
              let kind = TransactionKind(rawValue: kindRaw) else {
            throw AIToolExecutorError.invalidArguments("kind deve ser income ou expense.")
        }
        let amount = try requireDecimal(args, key: "amount")
        guard amount > 0 else { throw AIToolExecutorError.invalidArguments("Valor deve ser positivo.") }

        let account = try AIToolResolver.account(
            in: context.accounts,
            id: nil,
            name: AIToolJSON.string(args, key: "account")
        )
        let category = try? AIToolResolver.category(
            in: context.categories,
            id: nil,
            name: AIToolJSON.string(args, key: "category"),
            kind: kind == .income ? .income : .expense
        )
        let date = AIToolJSON.date(args, key: "date", calendar: context.calendar) ?? context.now
        let note = AIToolJSON.string(args, key: "note") ?? ""

        let txn = Transaction(
            amount: amount,
            kind: kind,
            occurredOn: date,
            note: note,
            category: category,
            account: account
        )
        context.modelContext.insert(txn)

        return .success(.object([
            "transaction_id": .string(txn.id.uuidString),
            "amount": .from(amount),
            "account": .string(account.name)
        ]))
    }

    private static func payBill(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let billRef = AIToolJSON.string(args, key: "bill") ?? ""
        let bill = try AIToolResolver.bill(
            in: context.bills,
            id: UUID(uuidString: billRef),
            name: billRef
        )
        guard bill.isPending else {
            throw AIToolExecutorError.invalidArguments("Conta já está paga ou cancelada.")
        }

        let paidAmount = AIToolJSON.decimal(args, key: "amount") ?? bill.amount
        let paidDate = AIToolJSON.date(args, key: "paid_date", calendar: context.calendar) ?? context.now
        let account = try AIToolResolver.account(
            in: context.accounts,
            id: nil,
            name: AIToolJSON.string(args, key: "account") ?? bill.account?.name,
            kinds: [.bank, .creditCard]
        )

        let normalizedDate = context.calendar.startOfDay(for: paidDate)
        let memo = bill.note.isEmpty ? bill.name : "\(bill.name) — \(bill.note)"
        let txn = Transaction(
            amount: paidAmount,
            kind: .expense,
            occurredOn: normalizedDate,
            note: memo,
            category: bill.category,
            account: account
        )
        context.modelContext.insert(txn)

        bill.status = .paid
        bill.paidOn = normalizedDate
        bill.paidTransactionID = txn.id
        BillNotifications.cancel(for: bill)

        return .success(.object([
            "bill": .string(bill.name),
            "amount": .from(paidAmount),
            "account": .string(account.name)
        ]))
    }

    private static func confirmReceivable(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let ref = AIToolJSON.string(args, key: "receivable") ?? ""
        let receivable = try AIToolResolver.receivable(
            in: context.receivables,
            id: UUID(uuidString: ref),
            name: ref
        )
        guard receivable.isPending else {
            throw AIToolExecutorError.invalidArguments("Recebível já confirmado ou cancelado.")
        }

        let receivedAmount = AIToolJSON.decimal(args, key: "amount") ?? receivable.amount
        let receivedDate = AIToolJSON.date(args, key: "received_date", calendar: context.calendar) ?? context.now
        let account = try AIToolResolver.account(
            in: context.accounts,
            id: nil,
            name: AIToolJSON.string(args, key: "account") ?? receivable.account?.name,
            kinds: [.bank]
        )

        let normalizedDate = context.calendar.startOfDay(for: receivedDate)
        let memo = receivable.note.isEmpty ? receivable.name : "\(receivable.name) — \(receivable.note)"
        let txn = Transaction(
            amount: receivedAmount,
            kind: .income,
            occurredOn: normalizedDate,
            note: memo,
            category: receivable.category,
            account: account
        )
        context.modelContext.insert(txn)

        receivable.status = .received
        receivable.receivedOn = normalizedDate
        receivable.receivedTransactionID = txn.id
        ReceivableNotifications.cancel(for: receivable)

        return .success(.object([
            "receivable": .string(receivable.name),
            "amount": .from(receivedAmount),
            "account": .string(account.name)
        ]))
    }

    private static func createBill(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        guard let name = AIToolJSON.string(args, key: "name"), !name.isEmpty else {
            throw AIToolExecutorError.invalidArguments("name é obrigatório.")
        }
        let amount = try requireDecimal(args, key: "amount")
        guard let dueDate = AIToolJSON.date(args, key: "due_date", calendar: context.calendar) else {
            throw AIToolExecutorError.invalidArguments("due_date inválida.")
        }

        let account = try? AIToolResolver.account(in: context.accounts, id: nil, name: AIToolJSON.string(args, key: "account"))
        let category = try? AIToolResolver.category(
            in: context.categories,
            id: nil,
            name: AIToolJSON.string(args, key: "category"),
            kind: .expense
        )
        let note = AIToolJSON.string(args, key: "note") ?? ""

        let bill = Bill(
            name: name,
            amount: amount,
            dueDate: dueDate,
            note: note,
            category: category,
            account: account
        )
        context.modelContext.insert(bill)
        BillNotifications.schedule(for: bill)

        return .success(.object([
            "bill_id": .string(bill.id.uuidString),
            "name": .string(name),
            "amount": .from(amount)
        ]))
    }

    private static func createReceivable(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        guard let name = AIToolJSON.string(args, key: "name"), !name.isEmpty else {
            throw AIToolExecutorError.invalidArguments("name é obrigatório.")
        }
        let amount = try requireDecimal(args, key: "amount")
        guard let expectedDate = AIToolJSON.date(args, key: "expected_date", calendar: context.calendar) else {
            throw AIToolExecutorError.invalidArguments("expected_date inválida.")
        }

        let account = try? AIToolResolver.account(in: context.accounts, id: nil, name: AIToolJSON.string(args, key: "account"))
        let category = try? AIToolResolver.category(
            in: context.categories,
            id: nil,
            name: AIToolJSON.string(args, key: "category"),
            kind: .income
        )
        let note = AIToolJSON.string(args, key: "note") ?? ""

        let receivable = Receivable(
            name: name,
            amount: amount,
            expectedDate: expectedDate,
            note: note,
            category: category,
            account: account
        )
        context.modelContext.insert(receivable)
        ReceivableNotifications.schedule(for: receivable)

        return .success(.object([
            "receivable_id": .string(receivable.id.uuidString),
            "name": .string(name),
            "amount": .from(amount)
        ]))
    }

    private static func rescheduleBill(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let ref = AIToolJSON.string(args, key: "bill") ?? ""
        let bill = try AIToolResolver.bill(in: context.bills, id: UUID(uuidString: ref), name: ref)
        guard let newDate = AIToolJSON.date(args, key: "new_due_date", calendar: context.calendar) else {
            throw AIToolExecutorError.invalidArguments("new_due_date inválida.")
        }
        bill.dueDate = newDate
        BillNotifications.cancel(for: bill)
        BillNotifications.schedule(for: bill)
        return .success(.object([
            "bill": .string(bill.name),
            "new_due_date": .string(newDate.formatted(date: .abbreviated, time: .omitted))
        ]))
    }

    private static func rescheduleReceivable(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let ref = AIToolJSON.string(args, key: "receivable") ?? ""
        let receivable = try AIToolResolver.receivable(in: context.receivables, id: UUID(uuidString: ref), name: ref)
        guard let newDate = AIToolJSON.date(args, key: "new_expected_date", calendar: context.calendar) else {
            throw AIToolExecutorError.invalidArguments("new_expected_date inválida.")
        }
        receivable.expectedDate = newDate
        ReceivableNotifications.cancel(for: receivable)
        ReceivableNotifications.schedule(for: receivable)
        return .success(.object([
            "receivable": .string(receivable.name),
            "new_expected_date": .string(newDate.formatted(date: .abbreviated, time: .omitted))
        ]))
    }

    private static func payCardInvoice(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let amount = try requireDecimal(args, key: "amount")
        guard amount > 0 else { throw AIToolExecutorError.invalidArguments("Valor deve ser positivo.") }

        let card = try AIToolResolver.account(
            in: context.accounts,
            id: nil,
            name: AIToolJSON.string(args, key: "card_account"),
            kinds: [.creditCard]
        )
        let bank = try AIToolResolver.account(
            in: context.accounts,
            id: nil,
            name: AIToolJSON.string(args, key: "bank_account"),
            kinds: [.bank]
        )
        let paymentDate = AIToolJSON.date(args, key: "date", calendar: context.calendar) ?? context.now
        let normalizedDate = context.calendar.startOfDay(for: paymentDate)

        let expenseCategory = context.categories.first { $0.kind == .expense && $0.name.lowercased().contains("cartão") }
            ?? context.categories.first { $0.kind == .expense }

        let note = "Pagamento fatura \(card.name)"
        let bankPayment = Transaction(
            amount: amount,
            kind: .expense,
            occurredOn: normalizedDate,
            note: note,
            category: expenseCategory,
            account: bank
        )
        let cardPayment = Transaction(
            amount: amount,
            kind: .income,
            occurredOn: normalizedDate,
            note: note,
            account: card
        )
        context.modelContext.insert(bankPayment)
        context.modelContext.insert(cardPayment)

        return .success(.object([
            "card": .string(card.name),
            "bank_account": .string(bank.name),
            "amount": .from(amount)
        ]))
    }

    private static func createWishlistItem(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        guard let name = AIToolJSON.string(args, key: "name")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            throw AIToolExecutorError.invalidArguments("Nome é obrigatório.")
        }
        let amount = try requireDecimal(args, key: "estimated_amount")
        guard amount > 0 else { throw AIToolExecutorError.invalidArguments("Valor deve ser positivo.") }

        let priority = WishlistPriority(rawValue: AIToolJSON.string(args, key: "priority") ?? "") ?? .medium
        let category = try? AIToolResolver.category(
            in: context.categories,
            id: nil,
            name: AIToolJSON.string(args, key: "category"),
            kind: .expense
        )
        let desiredBy = AIToolJSON.date(args, key: "desired_by", calendar: context.calendar)
        let note = AIToolJSON.string(args, key: "note") ?? ""

        let item = WishlistItem(
            name: name,
            estimatedAmount: amount,
            priority: priority,
            note: note,
            desiredBy: desiredBy,
            category: category
        )
        context.modelContext.insert(item)

        return .success(.object([
            "id": .string(item.id.uuidString),
            "name": .string(item.name),
            "estimated_amount": .from(amount)
        ]))
    }

    private static func updateWishlistItem(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let item = try AIToolResolver.wishlistItem(
            in: context.wishlistItems,
            id: AIToolJSON.uuid(args, key: "item_id"),
            name: AIToolJSON.string(args, key: "item_name")
        )

        if let name = AIToolJSON.string(args, key: "name")?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            item.name = name
        }
        if let amount = AIToolJSON.decimal(args, key: "estimated_amount") {
            guard amount > 0 else { throw AIToolExecutorError.invalidArguments("Valor deve ser positivo.") }
            item.estimatedAmount = amount
        }
        if let priorityRaw = AIToolJSON.string(args, key: "priority"),
           let priority = WishlistPriority(rawValue: priorityRaw) {
            item.priority = priority
        }
        if args.keys.contains("note") {
            item.note = AIToolJSON.string(args, key: "note") ?? ""
        }
        if args.keys.contains("desired_by") {
            item.desiredBy = AIToolJSON.date(args, key: "desired_by", calendar: context.calendar)
        }
        if let categoryName = AIToolJSON.string(args, key: "category") {
            item.category = try AIToolResolver.category(
                in: context.categories,
                id: nil,
                name: categoryName,
                kind: .expense
            )
        }

        return .success(.object(AIToolFormatters.wishlistItemJSON(item, now: context.now)))
    }

    private static func deleteWishlistItem(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let item = try AIToolResolver.wishlistItem(
            in: context.wishlistItems,
            id: AIToolJSON.uuid(args, key: "item_id"),
            name: AIToolJSON.string(args, key: "item_name")
        )
        let name = item.name
        context.modelContext.delete(item)
        return .success(.object(["deleted": .string(name)]))
    }

    private static func purchaseWishlistItem(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let item = try AIToolResolver.wishlistItem(
            in: context.wishlistItems,
            id: AIToolJSON.uuid(args, key: "item_id"),
            name: AIToolJSON.string(args, key: "item_name")
        )
        let amount = AIToolJSON.decimal(args, key: "amount") ?? item.estimatedAmount
        guard amount > 0 else { throw AIToolExecutorError.invalidArguments("Valor deve ser positivo.") }

        let account = try AIToolResolver.account(
            in: context.accounts,
            id: nil,
            name: AIToolJSON.string(args, key: "account"),
            kinds: [.bank, .creditCard]
        )
        let date = AIToolJSON.date(args, key: "date", calendar: context.calendar) ?? context.now
        let category = try? AIToolResolver.category(
            in: context.categories,
            id: nil,
            name: AIToolJSON.string(args, key: "category"),
            kind: .expense
        )

        let txn = WishlistPurchaseRecorder.recordPurchase(
            item: item,
            amount: amount,
            account: account,
            date: date,
            category: category ?? item.category,
            modelContext: context.modelContext
        )

        return .success(.object([
            "transaction_id": .string(txn.id.uuidString),
            "name": .string(txn.note),
            "amount": .from(amount),
            "account": .string(account.name)
        ]))
    }

    private static func cancelBill(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let ref = AIToolJSON.string(args, key: "bill") ?? ""
        let bill = try AIToolResolver.bill(in: context.bills, id: UUID(uuidString: ref), name: ref)
        guard bill.isPending else {
            throw AIToolExecutorError.invalidArguments("Conta já está paga ou cancelada.")
        }
        guard !bill.isCardStatement else {
            throw AIToolExecutorError.invalidArguments("Faturas de cartão não podem ser canceladas por aqui.")
        }
        bill.status = .cancelled
        BillNotifications.cancel(for: bill)
        return .success(.object(["bill": .string(bill.name), "status": .string("cancelled")]))
    }

    private static func cancelReceivable(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let ref = AIToolJSON.string(args, key: "receivable") ?? ""
        let receivable = try AIToolResolver.receivable(in: context.receivables, id: UUID(uuidString: ref), name: ref)
        guard receivable.isPending else {
            throw AIToolExecutorError.invalidArguments("Recebível já confirmado ou cancelado.")
        }
        receivable.status = .cancelled
        ReceivableNotifications.cancel(for: receivable)
        return .success(.object(["receivable": .string(receivable.name), "status": .string("cancelled")]))
    }

    private static func updateBill(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let ref = AIToolJSON.string(args, key: "bill") ?? ""
        let bill = try AIToolResolver.bill(in: context.bills, id: UUID(uuidString: ref), name: ref)
        guard bill.isPending else {
            throw AIToolExecutorError.invalidArguments("Só contas pendentes podem ser editadas.")
        }
        guard !bill.isCardStatement else {
            throw AIToolExecutorError.invalidArguments("Faturas de cartão não podem ser editadas por aqui.")
        }
        guard hasAnyKey(args, keys: ["name", "amount", "due_date", "account", "category", "note"]) else {
            throw AIToolExecutorError.invalidArguments("Informe ao menos um campo para atualizar.")
        }

        if let name = AIToolJSON.string(args, key: "name"), !name.isEmpty {
            bill.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let amount = AIToolJSON.decimal(args, key: "amount") {
            guard amount > 0 else { throw AIToolExecutorError.invalidArguments("Valor deve ser positivo.") }
            bill.amount = amount
        }
        if let dueDate = AIToolJSON.date(args, key: "due_date", calendar: context.calendar) {
            bill.dueDate = context.calendar.startOfDay(for: dueDate)
        }
        if let accountName = AIToolJSON.string(args, key: "account") {
            bill.account = try AIToolResolver.account(
                in: context.accounts,
                id: nil,
                name: accountName,
                kinds: [.bank, .creditCard]
            )
        }
        if let categoryName = AIToolJSON.string(args, key: "category") {
            bill.category = try AIToolResolver.category(
                in: context.categories,
                id: nil,
                name: categoryName,
                kind: .expense
            )
        }
        if args.keys.contains("note") {
            bill.note = AIToolJSON.string(args, key: "note") ?? ""
        }

        BillNotifications.schedule(for: bill)
        return .success(.object(["bill": .string(bill.name), "amount": .from(bill.amount)]))
    }

    private static func updateReceivable(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        let ref = AIToolJSON.string(args, key: "receivable") ?? ""
        let receivable = try AIToolResolver.receivable(in: context.receivables, id: UUID(uuidString: ref), name: ref)
        guard receivable.isPending else {
            throw AIToolExecutorError.invalidArguments("Só recebíveis pendentes podem ser editados.")
        }
        guard hasAnyKey(args, keys: ["name", "amount", "expected_date", "account", "category", "note"]) else {
            throw AIToolExecutorError.invalidArguments("Informe ao menos um campo para atualizar.")
        }

        if let name = AIToolJSON.string(args, key: "name"), !name.isEmpty {
            receivable.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let amount = AIToolJSON.decimal(args, key: "amount") {
            guard amount > 0 else { throw AIToolExecutorError.invalidArguments("Valor deve ser positivo.") }
            receivable.amount = amount
        }
        if let expectedDate = AIToolJSON.date(args, key: "expected_date", calendar: context.calendar) {
            receivable.expectedDate = context.calendar.startOfDay(for: expectedDate)
        }
        if let accountName = AIToolJSON.string(args, key: "account") {
            receivable.account = try AIToolResolver.account(
                in: context.accounts,
                id: nil,
                name: accountName,
                kinds: [.bank]
            )
        }
        if let categoryName = AIToolJSON.string(args, key: "category") {
            receivable.category = try AIToolResolver.category(
                in: context.categories,
                id: nil,
                name: categoryName,
                kind: .income
            )
        }
        if args.keys.contains("note") {
            receivable.note = AIToolJSON.string(args, key: "note") ?? ""
        }

        ReceivableNotifications.schedule(for: receivable)
        return .success(.object(["receivable": .string(receivable.name), "amount": .from(receivable.amount)]))
    }

    private static func updateTransaction(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        guard let idRaw = AIToolJSON.string(args, key: "transaction_id"),
              let id = UUID(uuidString: idRaw) else {
            throw AIToolExecutorError.invalidArguments("transaction_id inválido.")
        }
        let transaction = try AIToolResolver.transaction(in: context.transactions, id: id)
        guard hasAnyKey(args, keys: ["amount", "kind", "account", "category", "date", "note"]) else {
            throw AIToolExecutorError.invalidArguments("Informe ao menos um campo para atualizar.")
        }

        if let amount = AIToolJSON.decimal(args, key: "amount") {
            guard amount > 0 else { throw AIToolExecutorError.invalidArguments("Valor deve ser positivo.") }
            transaction.amount = amount
        }
        if let kindRaw = AIToolJSON.string(args, key: "kind"),
           let kind = TransactionKind(rawValue: kindRaw) {
            transaction.kind = kind
        }
        if let accountName = AIToolJSON.string(args, key: "account") {
            transaction.account = try AIToolResolver.account(in: context.accounts, id: nil, name: accountName)
        }
        if let categoryName = AIToolJSON.string(args, key: "category") {
            let kind: CategoryKind = transaction.kind == .income ? .income : .expense
            transaction.category = try AIToolResolver.category(
                in: context.categories,
                id: nil,
                name: categoryName,
                kind: kind
            )
        }
        if let date = AIToolJSON.date(args, key: "date", calendar: context.calendar) {
            transaction.occurredOn = context.calendar.startOfDay(for: date)
        }
        if args.keys.contains("note") {
            transaction.note = AIToolJSON.string(args, key: "note") ?? ""
        }

        return .success(.object([
            "transaction_id": .string(transaction.id.uuidString),
            "amount": .from(transaction.amount),
            "account": .string(transaction.account?.name ?? "")
        ]))
    }

    private static func deleteTransaction(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        guard let idRaw = AIToolJSON.string(args, key: "transaction_id"),
              let id = UUID(uuidString: idRaw) else {
            throw AIToolExecutorError.invalidArguments("transaction_id inválido.")
        }
        let transaction = try AIToolResolver.transaction(in: context.transactions, id: id)
        try assertTransactionCanBeDeleted(transaction, context: context)
        let summary = transaction.note.isEmpty ? transaction.id.uuidString : transaction.note
        context.modelContext.delete(transaction)
        return .success(.object(["deleted": .string(summary)]))
    }

    private static func createRecurringExpense(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        guard let name = AIToolJSON.string(args, key: "name"), !name.isEmpty else {
            throw AIToolExecutorError.invalidArguments("name é obrigatório.")
        }
        let amount = try requireDecimal(args, key: "amount")
        guard amount > 0 else { throw AIToolExecutorError.invalidArguments("Valor deve ser positivo.") }
        guard let dayOfMonth = AIToolJSON.int(args, key: "day_of_month"), (1...31).contains(dayOfMonth) else {
            throw AIToolExecutorError.invalidArguments("day_of_month deve ser entre 1 e 31.")
        }

        let account = try AIToolResolver.account(
            in: context.accounts,
            id: nil,
            name: AIToolJSON.string(args, key: "account"),
            kinds: [.bank, .creditCard]
        )
        let category = try AIToolResolver.category(
            in: context.categories,
            id: nil,
            name: AIToolJSON.string(args, key: "category"),
            kind: .expense
        )
        let startDate = AIToolJSON.date(args, key: "start_date", calendar: context.calendar) ?? context.now
        let requiresConfirmation = AIToolJSON.bool(args, key: "requires_confirmation") ?? false

        let rule = RecurringExpense(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            dayOfMonth: dayOfMonth,
            startDate: context.calendar.startOfDay(for: startDate),
            endDate: nil,
            requiresConfirmation: requiresConfirmation,
            category: category,
            account: account
        )
        context.modelContext.insert(rule)
        RecurringExpenseMaterializer.materialize(
            rule: rule,
            horizon: Date.now.addingTimeInterval(RecurringExpenseMaterializer.defaultHorizon),
            context: context.modelContext
        )

        return .success(.object([
            "rule_id": .string(rule.id.uuidString),
            "name": .string(rule.name),
            "amount": .from(amount),
            "requires_confirmation": .bool(requiresConfirmation)
        ]))
    }

    private static func createRecurringIncome(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        guard let name = AIToolJSON.string(args, key: "name"), !name.isEmpty else {
            throw AIToolExecutorError.invalidArguments("name é obrigatório.")
        }
        let amount = try requireDecimal(args, key: "amount")
        guard amount > 0 else { throw AIToolExecutorError.invalidArguments("Valor deve ser positivo.") }
        guard let dayOfMonth = AIToolJSON.int(args, key: "day_of_month"), (1...31).contains(dayOfMonth) else {
            throw AIToolExecutorError.invalidArguments("day_of_month deve ser entre 1 e 31.")
        }

        let account = try AIToolResolver.account(
            in: context.accounts,
            id: nil,
            name: AIToolJSON.string(args, key: "account"),
            kinds: [.bank]
        )
        let category = try AIToolResolver.category(
            in: context.categories,
            id: nil,
            name: AIToolJSON.string(args, key: "category"),
            kind: .income
        )
        let startDate = AIToolJSON.date(args, key: "start_date", calendar: context.calendar) ?? context.now
        let requiresConfirmation = AIToolJSON.bool(args, key: "requires_confirmation") ?? true

        let rule = RecurringIncome(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            dayOfMonth: dayOfMonth,
            startDate: context.calendar.startOfDay(for: startDate),
            endDate: nil,
            requiresConfirmation: requiresConfirmation,
            category: category,
            account: account
        )
        context.modelContext.insert(rule)
        RecurringIncomeMaterializer.materialize(
            rule: rule,
            horizon: Date.now.addingTimeInterval(RecurringIncomeMaterializer.defaultHorizon),
            context: context.modelContext
        )

        return .success(.object([
            "rule_id": .string(rule.id.uuidString),
            "name": .string(rule.name),
            "amount": .from(amount),
            "requires_confirmation": .bool(requiresConfirmation)
        ]))
    }

    private static func createGoal(_ args: [String: Any], _ context: AIToolContext) throws -> AIToolResultPayload {
        guard let name = AIToolJSON.string(args, key: "name"), !name.isEmpty else {
            throw AIToolExecutorError.invalidArguments("name é obrigatório.")
        }
        let targetAmount = try requireDecimal(args, key: "target_amount")
        guard targetAmount > 0 else { throw AIToolExecutorError.invalidArguments("Valor alvo deve ser positivo.") }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let deadline = AIToolJSON.date(args, key: "deadline", calendar: context.calendar)
            .map { context.calendar.startOfDay(for: $0) }
        let openingBalance = AIToolJSON.decimal(args, key: "opening_balance") ?? 0
        let notes = AIToolJSON.string(args, key: "notes") ?? ""

        let nextSortOrder = (context.accounts.map(\.sortOrder).max() ?? -1) + 1
        let dedicated = Account(
            name: trimmedName,
            kind: .goal,
            colorHex: "#6366F1",
            symbolName: "flag.fill",
            sortOrder: nextSortOrder,
            openingBalance: openingBalance,
            openingDate: context.calendar.startOfDay(for: context.now)
        )
        context.modelContext.insert(dedicated)

        let goal = FinancialGoal(
            name: trimmedName,
            targetAmount: targetAmount,
            deadline: deadline,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            linkedAccounts: [dedicated]
        )
        context.modelContext.insert(goal)

        return .success(.object([
            "goal_id": .string(goal.id.uuidString),
            "name": .string(goal.name),
            "target_amount": .from(targetAmount),
            "account": .string(dedicated.name)
        ]))
    }

    private static func updateBillSummary(_ args: [String: Any], _ context: AIToolContext) throws -> String {
        let ref = AIToolJSON.string(args, key: "bill") ?? "?"
        let bill = try AIToolResolver.bill(in: context.bills, id: UUID(uuidString: ref), name: ref)
        var changes: [String] = []
        if let name = AIToolJSON.string(args, key: "name"), !name.isEmpty, name != bill.name {
            changes.append("nome \"\(bill.name)\" → \"\(name)\"")
        }
        if let amount = AIToolJSON.decimal(args, key: "amount"), amount != bill.amount {
            changes.append("valor \(bill.amount.brl) → \(amount.brl)")
        }
        if let dueDate = AIToolJSON.date(args, key: "due_date", calendar: context.calendar) {
            let newDay = dueDate.formatted(date: .abbreviated, time: .omitted)
            let oldDay = bill.dueDate.formatted(date: .abbreviated, time: .omitted)
            if newDay != oldDay {
                changes.append("vencimento \(oldDay) → \(newDay)")
            }
        }
        if let accountName = AIToolJSON.string(args, key: "account"),
           accountName != (bill.account?.name ?? "") {
            changes.append("conta → \(accountName)")
        }
        if changes.isEmpty {
            return "Atualizar conta a pagar: \(bill.name)"
        }
        return "Atualizar \(bill.name): \(changes.joined(separator: ", "))"
    }

    private static func updateReceivableSummary(_ args: [String: Any], _ context: AIToolContext) throws -> String {
        let ref = AIToolJSON.string(args, key: "receivable") ?? "?"
        let receivable = try AIToolResolver.receivable(in: context.receivables, id: UUID(uuidString: ref), name: ref)
        var changes: [String] = []
        if let name = AIToolJSON.string(args, key: "name"), !name.isEmpty, name != receivable.name {
            changes.append("nome \"\(receivable.name)\" → \"\(name)\"")
        }
        if let amount = AIToolJSON.decimal(args, key: "amount"), amount != receivable.amount {
            changes.append("valor \(receivable.amount.brl) → \(amount.brl)")
        }
        if let expectedDate = AIToolJSON.date(args, key: "expected_date", calendar: context.calendar) {
            let newDay = expectedDate.formatted(date: .abbreviated, time: .omitted)
            let oldDay = receivable.expectedDate.formatted(date: .abbreviated, time: .omitted)
            if newDay != oldDay {
                changes.append("previsão \(oldDay) → \(newDay)")
            }
        }
        if let accountName = AIToolJSON.string(args, key: "account"),
           accountName != (receivable.account?.name ?? "") {
            changes.append("conta → \(accountName)")
        }
        if changes.isEmpty {
            return "Atualizar conta a receber: \(receivable.name)"
        }
        return "Atualizar \(receivable.name): \(changes.joined(separator: ", "))"
    }

    private static func updateTransactionSummary(_ args: [String: Any], _ context: AIToolContext) throws -> String {
        guard let idRaw = AIToolJSON.string(args, key: "transaction_id"),
              let id = UUID(uuidString: idRaw) else {
            throw AIToolExecutorError.invalidArguments("transaction_id inválido.")
        }
        let transaction = try AIToolResolver.transaction(in: context.transactions, id: id)
        let label = transaction.note.isEmpty
            ? (transaction.category?.name ?? "Lançamento")
            : transaction.note
        var changes: [String] = []
        if let amount = AIToolJSON.decimal(args, key: "amount"), amount != transaction.amount {
            changes.append("valor \(transaction.amount.brl) → \(amount.brl)")
        }
        if let kindRaw = AIToolJSON.string(args, key: "kind"),
           let kind = TransactionKind(rawValue: kindRaw),
           kind != transaction.kind {
            changes.append("tipo \(transaction.kind.rawValue) → \(kind.rawValue)")
        }
        if let accountName = AIToolJSON.string(args, key: "account"),
           accountName != (transaction.account?.name ?? "") {
            changes.append("conta → \(accountName)")
        }
        if changes.isEmpty {
            return "Atualizar lançamento: \(label)"
        }
        return "Atualizar \(label): \(changes.joined(separator: ", "))"
    }

    private static func deleteTransactionSummary(_ args: [String: Any], _ context: AIToolContext) throws -> String {
        guard let idRaw = AIToolJSON.string(args, key: "transaction_id"),
              let id = UUID(uuidString: idRaw) else {
            throw AIToolExecutorError.invalidArguments("transaction_id inválido.")
        }
        let transaction = try AIToolResolver.transaction(in: context.transactions, id: id)
        try assertTransactionCanBeDeleted(transaction, context: context)
        let label = transaction.note.isEmpty
            ? (transaction.category?.name ?? idRaw.prefix(8).description)
            : transaction.note
        return "Excluir lançamento: \(label) — \(transaction.amount.brl)"
    }

    private static func assertTransactionCanBeDeleted(_ transaction: Transaction, context: AIToolContext) throws {
        let id = transaction.id
        if let bill = context.bills.first(where: { $0.paidTransactionID == id && $0.isPaid }) {
            throw AIToolExecutorError.invalidArguments(
                "Este lançamento confirma o pagamento de \"\(bill.name)\" e não pode ser excluído."
            )
        }
        if let receivable = context.receivables.first(where: { $0.receivedTransactionID == id && $0.isReceived }) {
            throw AIToolExecutorError.invalidArguments(
                "Este lançamento confirma o recebimento de \"\(receivable.name)\" e não pode ser excluído."
            )
        }
    }

    private static func hasAnyKey(_ args: [String: Any], keys: [String]) -> Bool {
        keys.contains { args[$0] != nil }
    }

    private static func requireDecimal(_ args: [String: Any], key: String) throws -> Decimal {
        guard let value = AIToolJSON.decimal(args, key: key) else {
            throw AIToolExecutorError.invalidArguments("Parâmetro \(key) inválido.")
        }
        return value
    }
}
