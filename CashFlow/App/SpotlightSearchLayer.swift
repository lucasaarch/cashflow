import SwiftData
import SwiftUI

/// Camada global de busca Spotlight — renderizada acima do conteúdo e do chat da IA.
struct SpotlightSearchLayer: View {
    @EnvironmentObject private var spotlightState: SpotlightPresentationState
    @EnvironmentObject private var spotlightNavigation: SpotlightNavigationState
    @EnvironmentObject private var sidebarNavigation: SidebarNavigationState
    @EnvironmentObject private var chatPanelState: AIChatPanelState

    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse)])
    private var transactions: [Transaction]

    @Query(sort: [SortDescriptor(\FinancialGoal.createdAt, order: .reverse)])
    private var goals: [FinancialGoal]

    @Query(sort: [SortDescriptor(\Category.sortOrder)])
    private var categories: [Category]

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @Query(sort: [SortDescriptor(\Bill.dueDate)])
    private var bills: [Bill]

    @Query(sort: [SortDescriptor(\Receivable.expectedDate)])
    private var receivables: [Receivable]

    @Query(sort: [SortDescriptor(\RecurringExpense.createdAt)])
    private var recurringExpenses: [RecurringExpense]

    @Query(sort: [SortDescriptor(\RecurringIncome.createdAt)])
    private var recurringIncomes: [RecurringIncome]

    @Query(sort: [SortDescriptor(\WishlistItem.createdAt, order: .reverse)])
    private var wishlistItems: [WishlistItem]

    var body: some View {
        SpotlightOverlay(
            isPresented: spotlightState.isPresented,
            onDismiss: { spotlightState.close() },
            transactions: transactions,
            goals: goals,
            categories: activeCategories,
            accounts: accounts,
            bills: bills,
            receivables: receivables,
            recurringExpenses: recurringExpenses,
            recurringIncomes: recurringIncomes,
            wishlistItems: wishlistItems,
            onSelect: handleSelection,
            onQuickAction: handleQuickAction
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(1_000)
        .allowsHitTesting(spotlightState.isPresented)
    }

    private var activeCategories: [Category] {
        categories.filter { !$0.isArchived }
    }

    private func handleSelection(_ result: SpotlightResult) {
        DispatchQueue.main.async { [spotlightNavigation, sidebarNavigation] in
            spotlightNavigation.focus(result)
            sidebarNavigation.navigate(to: result.sidebarDestination)
        }
    }

    private func handleQuickAction(_ action: SpotlightQuickAction) {
        switch action {
        case .registerExpense:
            chatPanelState.openToRegisterExpense()
        case .registerIncome:
            chatPanelState.openToRegisterIncome()
        case .openChat:
            chatPanelState.openFresh()
        }
    }
}
