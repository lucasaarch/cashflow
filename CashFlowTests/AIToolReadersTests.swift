import SwiftData
import XCTest
@testable import CashFlow

@MainActor
final class AIToolReadersTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var insightTestMonthKeys: [String] = []

    override func setUp() {
        super.setUp()
        container = PreviewData.container
        context = container.mainContext
        insightTestMonthKeys = []
    }

    override func tearDown() {
        for monthKey in insightTestMonthKeys {
            AIInsightsService.clearCachedInsight(monthKey: monthKey)
            AIWishlistInsightService.clearCachedInsight(monthKey: monthKey)
        }
        insightTestMonthKeys = []
        super.tearDown()
    }

    private func cacheDashboardInsight(_ text: String, monthKey: String) {
        insightTestMonthKeys.append(monthKey)
        AIInsightsService.cacheInsight(text, monthKey: monthKey)
    }

    private func cacheWishlistInsight(_ text: String, monthKey: String) {
        insightTestMonthKeys.append(monthKey)
        AIWishlistInsightService.cacheInsight(text, monthKey: monthKey)
    }

    func testGetAppContext() throws {
        let toolContext = makeToolContext()
        let result = try AIToolReaders.execute(name: "get_app_context", args: [:], context: toolContext)
        XCTAssertTrue(result.ok)
        XCTAssertNotNil(result.data)
    }

    func testGetPatrimony() throws {
        let toolContext = makeToolContext()
        let result = try AIToolReaders.execute(name: "get_patrimony", args: [:], context: toolContext)
        XCTAssertTrue(result.ok)
    }

    func testGetMonthSummary() throws {
        let toolContext = makeToolContext()
        let result = try AIToolReaders.execute(name: "get_month_summary", args: [:], context: toolContext)
        XCTAssertTrue(result.ok)
    }

    func testListAccounts() throws {
        let toolContext = makeToolContext()
        let result = try AIToolReaders.execute(name: "list_accounts", args: [:], context: toolContext)
        XCTAssertTrue(result.ok)
    }

    func testGetAccountByName() throws {
        let toolContext = makeToolContext()
        let result = try AIToolReaders.execute(
            name: "get_account",
            args: ["account_name": PreviewData.bankAccount.name],
            context: toolContext
        )
        XCTAssertTrue(result.ok)
    }

    func testListGoals() throws {
        let toolContext = makeToolContext()
        let result = try AIToolReaders.execute(name: "list_goals", args: [:], context: toolContext)
        XCTAssertTrue(result.ok)
    }

    func testListWishlistReturnsItems() throws {
        let item = WishlistItem(name: "Fone", estimatedAmount: 800, priority: .high)
        context.insert(item)
        try context.save()

        let toolContext = makeToolContext()
        let result = try AIToolReaders.execute(name: "list_wishlist", args: [:], context: toolContext)
        XCTAssertTrue(result.ok)
    }

    func testUnknownToolThrows() {
        let toolContext = makeToolContext()
        XCTAssertThrowsError(try AIToolReaders.execute(name: "nonexistent_tool", args: [:], context: toolContext))
    }

    func testCashFlowSeriesRequiresPeriod() {
        let toolContext = makeToolContext()
        XCTAssertThrowsError(try AIToolReaders.execute(name: "get_cash_flow_series", args: [:], context: toolContext))
    }

    func testCashFlowSeriesWithPeriod() throws {
        let toolContext = makeToolContext()
        let result = try AIToolReaders.execute(
            name: "get_cash_flow_series",
            args: ["period": "3m"],
            context: toolContext
        )
        XCTAssertTrue(result.ok)
    }

    func testSearchTransactionsMatchesNoteCategoryAndAccount() throws {
        let transport = Category(name: "Transporte", symbolName: "car.fill", kind: .expense, sortOrder: 2)
        context.insert(transport)

        let account = Account(
            name: "Banco Inter",
            kind: .bank,
            colorHex: "#F97316",
            symbolName: "building.columns.fill",
            sortOrder: 0,
            openingBalance: 0,
            openingDate: .now
        )
        context.insert(account)

        let uber = Transaction(
            amount: 38.40,
            kind: .expense,
            occurredOn: .now,
            note: "Uber Trabalho -> Casa",
            category: transport,
            account: account
        )
        context.insert(uber)

        let toolContext = makeToolContext()
        let byText = try AIToolReaders.execute(
            name: "search_transactions",
            args: ["text": "uber", "kind": "expense"],
            context: toolContext
        )
        XCTAssertTrue(byText.ok)
        if case .object(let payload) = byText.data {
            if case .int(let count) = payload["count"] {
                XCTAssertGreaterThan(count, 0)
            } else {
                XCTFail("count ausente")
            }
        } else {
            XCTFail("payload inválido")
        }

        let byCategory = try AIToolReaders.execute(
            name: "search_transactions",
            args: ["category_name": "transporte", "kind": "expense"],
            context: toolContext
        )
        XCTAssertTrue(byCategory.ok)
    }

    func testGetDashboardInsightReturnsCachedSummary() throws {
        let monthKey = "2099-01"
        cacheDashboardInsight("- Gastou acima do ritmo.\n- Saldo negativo.", monthKey: monthKey)

        var toolContext = makeToolContext()
        toolContext.dashboardInsightMonthKey = monthKey
        let result = try AIToolReaders.execute(name: "get_dashboard_insight", args: [:], context: toolContext)
        XCTAssertTrue(result.ok)
        if case .object(let payload) = result.data {
            if case .bool(let available) = payload["available"] {
                XCTAssertTrue(available)
            } else {
                XCTFail("available ausente")
            }
            if case .string(let key) = payload["month_key"] {
                XCTAssertEqual(key, monthKey)
            } else {
                XCTFail("month_key ausente")
            }
            if case .string(let insight) = payload["insight"] {
                XCTAssertTrue(insight.contains("ritmo"))
            } else {
                XCTFail("insight ausente")
            }
        } else {
            XCTFail("payload inválido")
        }
    }

    func testGetDashboardInsightUsesContextMonthKey() throws {
        cacheDashboardInsight("Resumo de teste.", monthKey: "2099-02")

        var context = makeToolContext()
        context.dashboardInsightMonthKey = "2099-02"
        let result = try AIToolReaders.execute(name: "get_dashboard_insight", args: [:], context: context)
        XCTAssertTrue(result.ok)
        if case .object(let payload) = result.data {
            if case .string(let key) = payload["month_key"] {
                XCTAssertEqual(key, "2099-02")
            } else {
                XCTFail("month_key ausente")
            }
            if case .string(let insight) = payload["insight"] {
                XCTAssertEqual(insight, "Resumo de teste.")
            } else {
                XCTFail("insight ausente")
            }
        } else {
            XCTFail("payload inválido")
        }
    }

    func testGetWishlistInsightReturnsCachedSuggestion() throws {
        let monthKey = "2099-03"
        cacheWishlistInsight("- Espere o fim do mês.\n- Item X cabe na folga.", monthKey: monthKey)

        var toolContext = makeToolContext()
        toolContext.wishlistInsightMonthKey = monthKey
        let result = try AIToolReaders.execute(name: "get_wishlist_insight", args: [:], context: toolContext)
        XCTAssertTrue(result.ok)
        if case .object(let payload) = result.data {
            if case .bool(let available) = payload["available"] {
                XCTAssertTrue(available)
            } else {
                XCTFail("available ausente")
            }
            if case .string(let insight) = payload["insight"] {
                XCTAssertTrue(insight.contains("folga"))
            } else {
                XCTFail("insight ausente")
            }
        } else {
            XCTFail("payload inválido")
        }
    }

    func testGetWishlistInsightUsesContextMonthKey() throws {
        cacheWishlistInsight("Sugestão de teste.", monthKey: "2099-04")

        var context = makeToolContext()
        context.wishlistInsightMonthKey = "2099-04"
        let result = try AIToolReaders.execute(name: "get_wishlist_insight", args: [:], context: context)
        XCTAssertTrue(result.ok)
        if case .object(let payload) = result.data {
            if case .string(let key) = payload["month_key"] {
                XCTAssertEqual(key, "2099-04")
            } else {
                XCTFail("month_key ausente")
            }
            if case .string(let insight) = payload["insight"] {
                XCTAssertEqual(insight, "Sugestão de teste.")
            } else {
                XCTFail("insight ausente")
            }
        } else {
            XCTFail("payload inválido")
        }
    }

    private func makeToolContext() -> AIToolContext {
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let bills = (try? context.fetch(FetchDescriptor<Bill>())) ?? []
        let goals = (try? context.fetch(FetchDescriptor<FinancialGoal>())) ?? []
        let wishlistItems = (try? context.fetch(FetchDescriptor<WishlistItem>())) ?? []
        let categories = (try? context.fetch(FetchDescriptor<CashFlow.Category>())) ?? []
        return AIToolContext(
            modelContext: context,
            transactions: transactions,
            accounts: accounts,
            bills: bills,
            receivables: [],
            goals: goals,
            recurringExpenses: [],
            recurringIncomes: [],
            categories: categories,
            wishlistItems: wishlistItems
        )
    }
}
