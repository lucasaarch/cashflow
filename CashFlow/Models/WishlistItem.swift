import Foundation
import SwiftData

enum WishlistPriority: String, Codable, CaseIterable, Identifiable {
    case low, medium, high, urgent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Baixa"
        case .medium: return "Média"
        case .high: return "Alta"
        case .urgent: return "Urgente"
        }
    }

    var sortRank: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

@Model
final class WishlistItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var estimatedAmount: Decimal
    var priorityRaw: String
    var note: String
    var desiredBy: Date?
    var createdAt: Date

    var category: Category?

    var priority: WishlistPriority {
        get { WishlistPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        estimatedAmount: Decimal,
        priority: WishlistPriority = .medium,
        note: String = "",
        desiredBy: Date? = nil,
        createdAt: Date = .now,
        category: Category? = nil
    ) {
        self.id = id
        self.name = name
        self.estimatedAmount = estimatedAmount
        self.priorityRaw = priority.rawValue
        self.note = note
        self.desiredBy = desiredBy
        self.createdAt = createdAt
        self.category = category
    }
}
