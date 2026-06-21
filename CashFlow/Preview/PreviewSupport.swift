import SwiftData
import SwiftUI

#if DEBUG

@MainActor
enum PreviewData {
    static let aiService = AIService()
    static let chatPanelState = AIChatPanelState()
    static let sidebarNavigation = SidebarNavigationState()
    static let spotlightState = SpotlightPresentationState()
    static let spotlightNavigation = SpotlightNavigationState()

    static let container: ModelContainer = {
        let schema = Schema([
            AppSettings.self,
            Transaction.self,
            Category.self,
            Account.self,
            InstallmentPlan.self,
            RecurringExpense.self,
            Bill.self,
            FinancialGoal.self,
            WishlistItem.self,
            ChatConversation.self,
            ChatMessage.self,
            ChatToolActivity.self,
            AIWriteActionLogEntry.self,
            AIPendingWriteProposal.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        seed(into: container.mainContext)
        return container
    }()

    private static var _bankAccount: Account!
    private static var _creditCard: Account!
    private static var _walletAccount: Account!
    private static var _marketCategory: Category!
    private static var _salaryCategory: Category!
    private static var _cardPaymentCategory: Category!

    static var bankAccount: Account { _ = container; return _bankAccount }
    static var creditCard: Account { _ = container; return _creditCard }
    static var walletAccount: Account { _ = container; return _walletAccount }
    static var marketCategory: Category { _ = container; return _marketCategory }
    static var salaryCategory: Category { _ = container; return _salaryCategory }
    static var cardPaymentCategory: Category { _ = container; return _cardPaymentCategory }

    static func seed(into context: ModelContext) {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: .now))!

        _marketCategory = Category(
            name: "Mercado",
            symbolName: "cart.fill",
            kind: .expense,
            sortOrder: 0
        )
        _salaryCategory = Category(
            name: "Salário",
            symbolName: "banknote.fill",
            kind: .income,
            sortOrder: 0
        )
        _cardPaymentCategory = Category(
            name: "Pagamento cartão",
            symbolName: "arrow.left.arrow.right",
            kind: .expense,
            sortOrder: 1
        )

        _bankAccount = Account(
            name: "Banco Inter",
            kind: .bank,
            colorHex: "#F97316",
            symbolName: "building.columns.fill",
            sortOrder: 0,
            openingBalance: 3200,
            openingDate: startOfMonth
        )
        _creditCard = Account(
            name: "Cartão Nubank",
            kind: .creditCard,
            colorHex: "#8B5CF6",
            symbolName: "creditcard.fill",
            sortOrder: 1,
            openingBalance: -1500,
            openingDate: startOfMonth,
            closingDay: 5,
            dueDay: 12
        )
        _walletAccount = Account(
            name: "Carteira",
            kind: .bank,
            colorHex: "#22C55E",
            symbolName: "wallet.pass.fill",
            sortOrder: 2,
            openingBalance: 120,
            openingDate: startOfMonth
        )

        context.insert(_marketCategory)
        context.insert(_salaryCategory)
        context.insert(_cardPaymentCategory)
        context.insert(_bankAccount)
        context.insert(_creditCard)
        context.insert(_walletAccount)

        let transactions: [Transaction] = [
            Transaction(
                amount: 4500,
                kind: .income,
                occurredOn: startOfMonth,
                note: "Salário março",
                category: _salaryCategory,
                account: _bankAccount
            ),
            Transaction(
                amount: 187.45,
                kind: .expense,
                occurredOn: calendar.date(byAdding: .day, value: -2, to: .now)!,
                note: "Compras da semana",
                category: _marketCategory,
                account: _creditCard
            ),
            Transaction(
                amount: 62.90,
                kind: .expense,
                occurredOn: calendar.date(byAdding: .day, value: -1, to: .now)!,
                note: "Almoço",
                category: _marketCategory,
                account: _walletAccount
            ),
            Transaction(
                amount: 250,
                kind: .expense,
                occurredOn: calendar.date(byAdding: .day, value: -4, to: .now)!,
                category: _cardPaymentCategory,
                account: _bankAccount
            )
        ]
        transactions.forEach { context.insert($0) }

        context.insert(AppSettings())

        try? context.save()
    }

    static var sampleTransactions: [Transaction] {
        let descriptor = FetchDescriptor<Transaction>()
        return (try? container.mainContext.fetch(descriptor)) ?? []
    }

    static var monthSummary: MonthSummary {
        MonthSummary(
            referenceDate: .now,
            transactions: sampleTransactions
        )
    }
}

extension View {
    func previewCashFlow(width: CGFloat = 900, height: CGFloat = 700) -> some View {
        modelContainer(PreviewData.container)
            .environmentObject(PreviewData.aiService)
            .environmentObject(PreviewData.chatPanelState)
            .environmentObject(PreviewData.sidebarNavigation)
            .environmentObject(PreviewData.spotlightState)
            .environmentObject(PreviewData.spotlightNavigation)
            .frame(width: width, height: height)
    }

    func previewSheet(width: CGFloat, height: CGFloat) -> some View {
        modelContainer(PreviewData.container)
            .environmentObject(PreviewData.aiService)
            .frame(width: width, height: height)
    }
}

#endif
