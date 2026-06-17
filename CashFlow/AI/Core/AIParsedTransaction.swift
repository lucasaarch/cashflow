import Foundation

struct AIParsedTransaction: Equatable {
    var amount: Decimal?
    var kind: TransactionKind?
    var categoryName: String?
    var accountName: String?
    var date: Date?
    var note: String?
}

struct AICategorySuggestion: Equatable, Decodable {
    let categoryId: String
    let confidence: Double
}

private struct AIParsedTransactionDTO: Decodable {
    let amount: Decimal?
    let kind: String?
    let categoryName: String?
    let accountName: String?
    let dateISO: String?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case amount, kind, categoryName, accountName, note
        case dateISO = "date"
    }

    func toModel() -> AIParsedTransaction {
        let parsedKind = kind.flatMap { TransactionKind(rawValue: $0) }
        let parsedDate = dateISO.flatMap { ISO8601DateFormatter().date(from: $0) }
        return AIParsedTransaction(
            amount: amount,
            kind: parsedKind,
            categoryName: categoryName,
            accountName: accountName,
            date: parsedDate,
            note: note
        )
    }
}

enum AICategorizeParsing {
    static func parseCategorySuggestion(_ json: String) throws -> AICategorySuggestion {
        let cleaned = stripMarkdownFences(json)
        guard let data = cleaned.data(using: .utf8) else {
            throw AIError.decodingFailed
        }
        return try JSONDecoder().decode(AICategorySuggestion.self, from: data)
    }

    static func parseTransactionResponse(_ json: String) throws -> AIParsedTransaction {
        let cleaned = stripMarkdownFences(json)
        guard let data = cleaned.data(using: .utf8) else {
            throw AIError.decodingFailed
        }
        return try JSONDecoder().decode(AIParsedTransactionDTO.self, from: data).toModel()
    }

    static func stripMarkdownFences(_ text: String) -> String {
        text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
