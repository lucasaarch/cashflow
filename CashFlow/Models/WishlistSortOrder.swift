import Foundation

enum WishlistSortOrder {
    static func sorted(_ items: [WishlistItem]) -> [WishlistItem] {
        items.sorted { lhs, rhs in
            if lhs.priority.sortRank != rhs.priority.sortRank {
                return lhs.priority.sortRank < rhs.priority.sortRank
            }
            switch (lhs.desiredBy, rhs.desiredBy) {
            case let (l?, r?): return l < r
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return lhs.createdAt > rhs.createdAt
            }
        }
    }
}
