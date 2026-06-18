import Foundation

enum AIToolResolver {
    static func account(
        in accounts: [Account],
        id: UUID?,
        name: String?,
        kinds: Set<AccountKind>? = nil
    ) throws -> Account {
        let pool = accounts.filter { account in
            guard !account.isArchived else { return false }
            if let kinds { return kinds.contains(account.kind) }
            return true
        }

        if let id, let match = pool.first(where: { $0.id == id }) {
            return match
        }

        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIToolResolverError.missingIdentifier("conta")
        }

        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = pool.filter { $0.name.lowercased() == normalized }
        if matches.count == 1 { return matches[0] }
        if matches.isEmpty {
            let partial = pool.filter { $0.name.lowercased().contains(normalized) }
            if partial.count == 1 { return partial[0] }
            if partial.count > 1 {
                let names = partial.map(\.name).joined(separator: ", ")
                throw AIToolResolverError.ambiguous("conta", options: names)
            }
            throw AIToolResolverError.notFound("conta", name)
        }
        let names = matches.map(\.name).joined(separator: ", ")
        throw AIToolResolverError.ambiguous("conta", options: names)
    }

    static func category(
        in categories: [Category],
        id: UUID?,
        name: String?,
        kind: CategoryKind? = nil
    ) throws -> Category {
        let pool = categories.filter { category in
            guard let kind else { return true }
            return category.kind == kind
        }

        if let id, let match = pool.first(where: { $0.id == id }) {
            return match
        }

        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIToolResolverError.missingIdentifier("categoria")
        }

        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = pool.filter { $0.name.lowercased() == normalized }
        if matches.count == 1 { return matches[0] }
        if matches.isEmpty {
            let partial = pool.filter { $0.name.lowercased().contains(normalized) }
            if partial.count == 1 { return partial[0] }
            if partial.count > 1 {
                let names = partial.map(\.name).joined(separator: ", ")
                throw AIToolResolverError.ambiguous("categoria", options: names)
            }
            throw AIToolResolverError.notFound("categoria", name)
        }
        let names = matches.map(\.name).joined(separator: ", ")
        throw AIToolResolverError.ambiguous("categoria", options: names)
    }

    static func bill(in bills: [Bill], id: UUID?, name: String?) throws -> Bill {
        if let id, let match = bills.first(where: { $0.id == id }) {
            return match
        }
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIToolResolverError.missingIdentifier("conta a pagar")
        }
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = bills.filter { $0.name.lowercased() == normalized }
        if matches.count == 1 { return matches[0] }
        if matches.isEmpty {
            let partial = bills.filter { $0.name.lowercased().contains(normalized) }
            if partial.count == 1 { return partial[0] }
            if partial.count > 1 {
                throw AIToolResolverError.ambiguous("conta a pagar", options: partial.map(\.name).joined(separator: ", "))
            }
            throw AIToolResolverError.notFound("conta a pagar", name)
        }
        throw AIToolResolverError.ambiguous("conta a pagar", options: matches.map(\.name).joined(separator: ", "))
    }

    static func receivable(in receivables: [Receivable], id: UUID?, name: String?) throws -> Receivable {
        if let id, let match = receivables.first(where: { $0.id == id }) {
            return match
        }
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIToolResolverError.missingIdentifier("conta a receber")
        }
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = receivables.filter { $0.name.lowercased() == normalized }
        if matches.count == 1 { return matches[0] }
        if matches.isEmpty {
            throw AIToolResolverError.notFound("conta a receber", name)
        }
        throw AIToolResolverError.ambiguous("conta a receber", options: matches.map(\.name).joined(separator: ", "))
    }

    static func goal(in goals: [FinancialGoal], id: UUID?, name: String?) throws -> FinancialGoal {
        if let id, let match = goals.first(where: { $0.id == id }) {
            return match
        }
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIToolResolverError.missingIdentifier("meta")
        }
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = goals.filter { $0.name.lowercased() == normalized }
        if matches.count == 1 { return matches[0] }
        if matches.isEmpty {
            throw AIToolResolverError.notFound("meta", name)
        }
        throw AIToolResolverError.ambiguous("meta", options: matches.map(\.name).joined(separator: ", "))
    }

    static func wishlistItem(in items: [WishlistItem], id: UUID?, name: String?) throws -> WishlistItem {
        if let id, let match = items.first(where: { $0.id == id }) {
            return match
        }
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIToolResolverError.missingIdentifier("item da lista de desejos")
        }
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = items.filter { $0.name.lowercased() == normalized }
        if matches.count == 1 { return matches[0] }
        if matches.isEmpty {
            let partial = items.filter { $0.name.lowercased().contains(normalized) }
            if partial.count == 1 { return partial[0] }
            if partial.count > 1 {
                throw AIToolResolverError.ambiguous("item da lista de desejos", options: partial.map(\.name).joined(separator: ", "))
            }
            throw AIToolResolverError.notFound("item da lista de desejos", name)
        }
        throw AIToolResolverError.ambiguous("item da lista de desejos", options: matches.map(\.name).joined(separator: ", "))
    }

    static func transaction(in transactions: [Transaction], id: UUID?) throws -> Transaction {
        guard let id else { throw AIToolResolverError.missingIdentifier("lançamento") }
        guard let match = transactions.first(where: { $0.id == id }) else {
            throw AIToolResolverError.notFound("lançamento", id.uuidString)
        }
        return match
    }

    static func recurringExpense(in rules: [RecurringExpense], id: UUID?, name: String?) throws -> RecurringExpense {
        if let id, let match = rules.first(where: { $0.id == id }) {
            return match
        }
        guard let name else { throw AIToolResolverError.missingIdentifier("despesa fixa") }
        let normalized = name.lowercased()
        let matches = rules.filter { $0.name.lowercased() == normalized }
        if matches.count == 1 { return matches[0] }
        throw AIToolResolverError.notFound("despesa fixa", name)
    }

    static func recurringIncome(in rules: [RecurringIncome], id: UUID?, name: String?) throws -> RecurringIncome {
        if let id, let match = rules.first(where: { $0.id == id }) {
            return match
        }
        guard let name else { throw AIToolResolverError.missingIdentifier("renda fixa") }
        let normalized = name.lowercased()
        let matches = rules.filter { $0.name.lowercased() == normalized }
        if matches.count == 1 { return matches[0] }
        throw AIToolResolverError.notFound("renda fixa", name)
    }
}

enum AIToolResolverError: LocalizedError {
    case missingIdentifier(String)
    case notFound(String, String)
    case ambiguous(String, options: String)

    var errorDescription: String? {
        switch self {
        case .missingIdentifier(let entity):
            return "Informe \(entity)_id ou \(entity)_name."
        case .notFound(let entity, let query):
            return "\(entity.capitalized) não encontrada: \(query)."
        case .ambiguous(let entity, let options):
            return "\(entity.capitalized) ambígua. Opções: \(options)."
        }
    }
}
