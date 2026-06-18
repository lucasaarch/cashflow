import Foundation
import SwiftData

enum AIToolInsightContext {
    static func compactSnapshot(context: AIToolContext) -> String {
        var sections: [String] = []

        if let patrimony = try? AIToolReaders.execute(name: "get_patrimony", args: [:], context: context),
           patrimony.ok, let data = patrimony.data {
            sections.append("=== PATRIMÔNIO ===\n\(jsonLine(data))")
        }

        if let month = try? AIToolReaders.execute(name: "get_month_summary", args: [:], context: context),
           month.ok, let data = month.data {
            sections.append("=== FLUXO DO MÊS ===\n\(jsonLine(data))")
        }

        if let pace = try? AIToolReaders.execute(name: "get_month_pace", args: [:], context: context),
           pace.ok, let data = pace.data {
            sections.append("=== RITMO ===\n\(jsonLine(data))")
        }

        if let goals = try? AIToolReaders.execute(name: "list_goals", args: ["active_only": true], context: context),
           goals.ok, let data = goals.data {
            sections.append("=== METAS ===\n\(jsonLine(data))")
        }

        if let bills = try? AIToolReaders.execute(name: "get_bills_summary", args: [:], context: context),
           bills.ok, let data = bills.data {
            sections.append("=== CONTAS A PAGAR ===\n\(jsonLine(data))")
        }

        if let receivables = try? AIToolReaders.execute(name: "get_receivables_summary", args: [:], context: context),
           receivables.ok, let data = receivables.data {
            sections.append("=== CONTAS A RECEBER ===\n\(jsonLine(data))")
        }

        if !context.wishlistItems.isEmpty,
           let wishlist = try? AIToolReaders.execute(name: "list_wishlist", args: [:], context: context),
           wishlist.ok, let data = wishlist.data {
            sections.append("=== LISTA DE DESEJOS ===\n\(jsonLine(data))")
        }

        return sections.joined(separator: "\n\n")
    }

    private static func jsonLine(_ value: AIToolJSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}
