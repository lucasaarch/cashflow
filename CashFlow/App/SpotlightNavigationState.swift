import Combine
import SwiftUI

enum SpotlightTargetKind: CaseIterable {
    case transaction
    case goal
    case category
    case account
    case bill
    case receivable
    case recurringExpense
    case recurringIncome
    case wishlistItem
}

enum SpotlightTarget: Equatable, Hashable {
    case transaction(UUID)
    case goal(UUID)
    case category(UUID)
    case account(UUID)
    case bill(UUID)
    case receivable(UUID)
    case recurringExpense(UUID)
    case recurringIncome(UUID)
    case wishlistItem(UUID)

    var kind: SpotlightTargetKind {
        switch self {
        case .transaction: .transaction
        case .goal: .goal
        case .category: .category
        case .account: .account
        case .bill: .bill
        case .receivable: .receivable
        case .recurringExpense: .recurringExpense
        case .recurringIncome: .recurringIncome
        case .wishlistItem: .wishlistItem
        }
    }

    var entityID: UUID {
        switch self {
        case .transaction(let id),
             .goal(let id),
             .category(let id),
             .account(let id),
             .bill(let id),
             .receivable(let id),
             .recurringExpense(let id),
             .recurringIncome(let id),
             .wishlistItem(let id):
            id
        }
    }

    func entityID(matching kind: SpotlightTargetKind) -> UUID? {
        self.kind == kind ? entityID : nil
    }
}

@MainActor
final class SpotlightNavigationState: ObservableObject {
    @Published private(set) var activeTarget: SpotlightTarget?
    @Published private(set) var openDetailOnFocus = true

    func focus(_ result: SpotlightResult) {
        let target = result.target
        let opensDetail = result.opensDetailOnFocus
        DispatchQueue.main.async { [self] in
            activeTarget = target
            openDetailOnFocus = opensDetail
        }
    }

    func clearTarget() {
        DispatchQueue.main.async { [self] in
            activeTarget = nil
            openDetailOnFocus = true
        }
    }
}
