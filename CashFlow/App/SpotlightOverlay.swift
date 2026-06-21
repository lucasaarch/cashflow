// Busca global estilo Spotlight — overlay Liquid Glass.
import SwiftUI

struct SpotlightOverlay: View {
    let isPresented: Bool
    var onDismiss: () -> Void = {}
    var transactions: [Transaction] = []
    var goals: [FinancialGoal] = []
    var categories: [Category] = []
    var accounts: [Account] = []
    var bills: [Bill] = []
    var receivables: [Receivable] = []
    var recurringExpenses: [RecurringExpense] = []
    var recurringIncomes: [RecurringIncome] = []
    var wishlistItems: [WishlistItem] = []
    var onSelect: (SpotlightResult) -> Void = { _ in }
    var onQuickAction: ((SpotlightQuickAction) -> Void)?

    var body: some View {
        if isPresented {
            SpotlightOverlaySession(
                onDismiss: onDismiss,
                transactions: transactions,
                goals: goals,
                categories: categories,
                accounts: accounts,
                bills: bills,
                receivables: receivables,
                recurringExpenses: recurringExpenses,
                recurringIncomes: recurringIncomes,
                wishlistItems: wishlistItems,
                onSelect: onSelect,
                onQuickAction: onQuickAction
            )
        }
    }
}

/// Sessão efêmera — `@State` é descartado ao fechar, evitando glitch na reabertura.
private struct SpotlightOverlaySession: View {
    var onDismiss: () -> Void = {}
    var transactions: [Transaction] = []
    var goals: [FinancialGoal] = []
    var categories: [Category] = []
    var accounts: [Account] = []
    var bills: [Bill] = []
    var receivables: [Receivable] = []
    var recurringExpenses: [RecurringExpense] = []
    var recurringIncomes: [RecurringIncome] = []
    var wishlistItems: [WishlistItem] = []
    var onSelect: (SpotlightResult) -> Void = { _ in }
    var onQuickAction: ((SpotlightQuickAction) -> Void)?

    @State private var query: String = ""
    @State private var debouncedQuery: String = ""
    @State private var selectedResultID: String?
    @State private var debounceTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let maxResultsPerSection = 8
    private static let panelWidth: CGFloat = 680
    private static let expandedPanelHeight: CGFloat = 480
    private static let quickActionsPanelHeight: CGFloat = 220
    private static let searchBarHeight: CGFloat = 56
    private static let debounceMilliseconds = 150
    private static let panelCornerRadius = CFGlassMetrics.panelCornerRadius
    private static let resultsHorizontalInset: CGFloat = 12
    private static let resultsRowSpacing: CGFloat = 4

    private var normalizedQuery: String {
        SpotlightSearch.normalized(debouncedQuery)
    }

    private var hasQuery: Bool { !normalizedQuery.isEmpty }

    private var panelAnimation: Animation? {
        reduceMotion ? nil : CFMotion.quick
    }

    private var transactionResults: [Transaction] {
        SpotlightSearch.resultsMatchingAny(in: transactions, query: normalizedQuery, limit: Self.maxResultsPerSection) { txn in
            [txn.note, txn.category?.name ?? "", txn.account?.name ?? ""]
        }
    }

    private var goalResults: [FinancialGoal] {
        SpotlightSearch.resultsNamed(in: goals, query: normalizedQuery, limit: Self.maxResultsPerSection, name: \.name)
    }

    private var categoryResults: [Category] {
        SpotlightSearch.resultsNamed(in: categories, query: normalizedQuery, limit: Self.maxResultsPerSection, name: \.name)
    }

    private var accountResults: [Account] {
        SpotlightSearch.resultsNamed(in: accounts, query: normalizedQuery, limit: Self.maxResultsPerSection, name: \.name)
    }

    private var billResults: [Bill] {
        SpotlightSearch.results(in: bills, query: normalizedQuery, limit: Self.maxResultsPerSection) { bill in
            bill.status != .cancelled &&
            SpotlightSearch.matchesAny(
                normalizedQuery,
                bill.name,
                bill.category?.name ?? "",
                bill.account?.name ?? ""
            )
        }
    }

    private var receivableResults: [Receivable] {
        SpotlightSearch.results(in: receivables, query: normalizedQuery, limit: Self.maxResultsPerSection) { item in
            item.status != .cancelled &&
            SpotlightSearch.matchesAny(
                normalizedQuery,
                item.name,
                item.category?.name ?? "",
                item.account?.name ?? ""
            )
        }
    }

    private var recurringExpenseResults: [RecurringExpense] {
        SpotlightSearch.resultsMatchingAny(in: recurringExpenses, query: normalizedQuery, limit: Self.maxResultsPerSection) { rule in
            [rule.name, rule.category?.name ?? "", rule.account?.name ?? ""]
        }
    }

    private var recurringIncomeResults: [RecurringIncome] {
        SpotlightSearch.resultsMatchingAny(in: recurringIncomes, query: normalizedQuery, limit: Self.maxResultsPerSection) { rule in
            [rule.name, rule.category?.name ?? "", rule.account?.name ?? ""]
        }
    }

    private var wishlistResults: [WishlistItem] {
        SpotlightSearch.resultsNamed(in: wishlistItems, query: normalizedQuery, limit: Self.maxResultsPerSection, name: \.name)
    }

    private var flatResults: [SpotlightResult] {
        var results: [SpotlightResult] = []
        results += transactionResults.map { .transaction($0) }
        results += goalResults.map { .goal($0) }
        results += billResults.map { .bill($0) }
        results += receivableResults.map { .receivable($0) }
        results += recurringExpenseResults.map { .recurringExpense($0) }
        results += recurringIncomeResults.map { .recurringIncome($0) }
        results += wishlistResults.map { .wishlistItem($0) }
        results += categoryResults.map { .category($0) }
        results += accountResults.map { .account($0) }
        return results
    }

    private var hasResults: Bool { !flatResults.isEmpty }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                spotlightBackdrop
                    .transition(.opacity)

                spotlightPanel
                    .frame(width: Self.panelWidth)
                    .frame(height: panelHeight)
                    .padding(.top, topOffset(for: geo.size.height))
                    .frame(maxWidth: .infinity)
                    .transition(spotlightTransition)
            }
        }
        .animation(panelAnimation, value: hasQuery)
        .onExitCommand { dismiss() }
        .onAppear { searchFocused = true }
        .onChange(of: query) { _, newValue in
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(Self.debounceMilliseconds))
                guard !Task.isCancelled else { return }
                debouncedQuery = newValue
            }
        }
        .onChange(of: flatResults.map(\.id)) { _, ids in
            Task { @MainActor in
                if let selectedResultID, ids.contains(selectedResultID) { return }
                selectedResultID = ids.first
            }
        }
    }

    private var spotlightBackdrop: some View {
        Color.black.opacity(0.08)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
    }

    private var spotlightTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity
            .combined(with: .scale(scale: 0.96, anchor: .top))
            .combined(with: .offset(y: -10))
    }

    private func topOffset(for height: CGFloat) -> CGFloat {
        max(72, height * 0.14)
    }

    private var panelHeight: CGFloat {
        if hasQuery { return Self.expandedPanelHeight }
        if onQuickAction != nil { return Self.quickActionsPanelHeight }
        return Self.searchBarHeight
    }

    private var spotlightPanel: some View {
        VStack(spacing: 0) {
            searchBar
            if hasQuery {
                CFGlassPanelDivider()
                resultsArea
                if hasResults {
                    footerHints
                }
            } else if onQuickAction != nil {
                CFGlassPanelDivider()
                quickActionsArea
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassEffect(.regular, in: .rect(cornerRadius: Self.panelCornerRadius))
        .shadow(color: .black.opacity(0.14), radius: 28, y: 14)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.medium))
                .foregroundStyle(CFTheme.textSecondary)
                .symbolRenderingMode(.hierarchical)

            TextField("Buscar em tudo…", text: $query)
                .textFieldStyle(.plain)
                .font(.title3.weight(.regular))
                .focused($searchFocused)
                .onKeyPress(.downArrow) {
                    guard hasResults else { return .ignored }
                    moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    guard hasResults else { return .ignored }
                    moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.return) {
                    guard hasResults else { return .ignored }
                    selectFocusedResult()
                    return .handled
                }

            if !query.isEmpty {
                Button {
                    withAnimation(panelAnimation) {
                        query = ""
                        debouncedQuery = ""
                        selectedResultID = nil
                    }
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(CFTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding + 4)
        .frame(height: Self.searchBarHeight)
    }

    private var resultsArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if hasResults {
                        if !transactionResults.isEmpty {
                            section(title: "Lançamentos", items: transactionResults.map { .transaction($0) })
                        }
                        if !goalResults.isEmpty {
                            section(title: "Metas", items: goalResults.map { .goal($0) })
                        }
                        if !billResults.isEmpty {
                            section(title: "Contas a pagar", items: billResults.map { .bill($0) })
                        }
                        if !receivableResults.isEmpty {
                            section(title: "Contas a receber", items: receivableResults.map { .receivable($0) })
                        }
                        if !recurringExpenseResults.isEmpty {
                            section(title: "Despesas fixas", items: recurringExpenseResults.map { .recurringExpense($0) })
                        }
                        if !recurringIncomeResults.isEmpty {
                            section(title: "Rendas fixas", items: recurringIncomeResults.map { .recurringIncome($0) })
                        }
                        if !wishlistResults.isEmpty {
                            section(title: "Lista de desejos", items: wishlistResults.map { .wishlistItem($0) })
                        }
                        if !categoryResults.isEmpty {
                            section(title: "Categorias", items: categoryResults.map { .category($0) })
                        }
                        if !accountResults.isEmpty {
                            section(title: "Contas", items: accountResults.map { .account($0) })
                        }
                    } else {
                        noResultsView
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            .onChange(of: selectedResultID) { _, id in
                guard let id else { return }
                withAnimation(CFMotion.quick) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var footerHints: some View {
        HStack(spacing: 16) {
            Label("selecionar", systemImage: "return")
            Label("navegar", systemImage: "arrow.up.arrow.down")
            Label("fechar", systemImage: "escape")
        }
        .font(.caption2)
        .foregroundStyle(CFTheme.textTertiary)
        .labelStyle(.titleAndIcon)
        .symbolVariant(.fill)
        .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding + 4)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            CFGlassPanelDivider()
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 48)
            CFGlassSymbol(systemName: "magnifyingglass", tint: CFTheme.textTertiary, size: 40)
            Text("Nenhum resultado encontrado")
                .font(.subheadline)
                .foregroundStyle(CFTheme.textSecondary)
            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity)
    }

    private func dismiss() {
        debounceTask?.cancel()
        onDismiss()
    }

    private func moveSelection(by delta: Int) {
        let results = flatResults
        guard !results.isEmpty else { return }
        guard let currentID = selectedResultID,
              let index = results.firstIndex(where: { $0.id == currentID }) else {
            selectedResultID = results.first?.id
            return
        }
        let next = (index + delta + results.count) % results.count
        selectedResultID = results[next].id
    }

    private func selectFocusedResult() {
        guard let selectedResultID,
              let result = flatResults.first(where: { $0.id == selectedResultID }) else { return }
        onSelect(result)
        dismiss()
    }

    @ViewBuilder
    private func section(title: String, items: [SpotlightResult]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, Self.resultsHorizontalInset + 4)
                .padding(.top, 10)
                .padding(.bottom, 6)

            VStack(spacing: Self.resultsRowSpacing) {
                ForEach(items) { item in
                    resultRow(item)
                        .id(item.id)
                }
            }
        }
    }

    private func resultRow(_ item: SpotlightResult) -> some View {
        let isKeyboardSelected = selectedResultID == item.id

        return CFGlassRowButton {
            onSelect(item)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                item.iconView
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.body)
                        .foregroundStyle(CFTheme.textPrimary)
                        .lineLimit(1)
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(CFTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .cfGlassPickerOption(isSelected: isKeyboardSelected, tint: CFTheme.accent)
        .padding(.horizontal, Self.resultsHorizontalInset)
    }

    private var quickActionsArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ações rápidas")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding + 4)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ForEach(SpotlightQuickAction.allCases) { action in
                CFGlassRowButton {
                    performQuickAction(action)
                } label: {
                    HStack(spacing: 12) {
                        CFGlassSymbol(systemName: action.symbolName, tint: action.tint)
                        Text(action.title)
                            .font(.body)
                            .foregroundStyle(CFTheme.textPrimary)
                        Spacer(minLength: 0)
                        quickActionTrailingIcon(for: action)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func quickActionTrailingIcon(for action: SpotlightQuickAction) -> some View {
        switch action {
        case .openChat:
            Image(systemName: AIAssistantIdentity.toolbarSymbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CFTheme.textTertiary)
        case .registerExpense, .registerIncome:
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CFTheme.textTertiary)
        }
    }

    private func performQuickAction(_ action: SpotlightQuickAction) {
        dismiss()
        onQuickAction?(action)
    }
}

enum SpotlightQuickAction: String, CaseIterable, Identifiable {
    case registerExpense
    case registerIncome
    case openChat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .registerExpense: return "Registrar despesa"
        case .registerIncome: return "Registrar receita"
        case .openChat: return "Conversar com \(AIAssistantIdentity.name)"
        }
    }

    var symbolName: String {
        switch self {
        case .registerExpense: return "arrow.down.circle"
        case .registerIncome: return "arrow.up.circle"
        case .openChat: return "bubble.left.and.bubble.right"
        }
    }

    var tint: Color {
        switch self {
        case .registerExpense: return CFTheme.expense
        case .registerIncome: return CFTheme.income
        case .openChat: return CFTheme.accent
        }
    }
}

enum SpotlightResult: Identifiable {
    case transaction(Transaction)
    case goal(FinancialGoal)
    case category(Category)
    case account(Account)
    case bill(Bill)
    case receivable(Receivable)
    case recurringExpense(RecurringExpense)
    case recurringIncome(RecurringIncome)
    case wishlistItem(WishlistItem)

    var id: String {
        switch self {
        case .transaction(let t): return "txn-\(t.id)"
        case .goal(let g): return "goal-\(g.id)"
        case .category(let c): return "cat-\(c.id)"
        case .account(let a): return "acct-\(a.id)"
        case .bill(let b): return "bill-\(b.id)"
        case .receivable(let r): return "recv-\(r.id)"
        case .recurringExpense(let r): return "rexp-\(r.id)"
        case .recurringIncome(let r): return "rinc-\(r.id)"
        case .wishlistItem(let w): return "wish-\(w.id)"
        }
    }

    @ViewBuilder
    var iconView: some View {
        switch self {
        case .transaction(let t):
            spotlightBadge(
                symbol: t.category?.symbolName ?? "list.bullet.rectangle",
                tint: categoryTint(t.category)
            )
        case .goal:
            spotlightBadge(symbol: "flag.fill", tint: CFTheme.accent)
        case .category(let c):
            spotlightBadge(symbol: c.symbolName, tint: categoryTint(c))
        case .account(let a):
            spotlightBadge(symbol: a.symbolName, tint: Color(hex: a.colorHex))
        case .bill(let b):
            spotlightBadge(
                symbol: b.category?.symbolName ?? (b.isCardStatement ? "creditcard.fill" : "calendar.badge.clock"),
                tint: b.isOverdue() ? CFTheme.danger : CFTheme.expense
            )
        case .receivable(let r):
            spotlightBadge(
                symbol: r.category?.symbolName ?? "tray.and.arrow.down",
                tint: r.isLate() ? CFTheme.warning : CFTheme.income
            )
        case .recurringExpense(let r):
            spotlightBadge(
                symbol: r.category?.symbolName ?? "repeat.circle",
                tint: CFTheme.expense
            )
        case .recurringIncome(let r):
            spotlightBadge(
                symbol: r.category?.symbolName ?? "arrow.down.circle",
                tint: CFTheme.income
            )
        case .wishlistItem:
            spotlightBadge(symbol: "cart.fill", tint: CFTheme.accent)
        }
    }

    var title: String {
        switch self {
        case .transaction(let t): return t.note
        case .goal(let g): return g.name
        case .category(let c): return c.name
        case .account(let a): return a.name
        case .bill(let b): return b.name
        case .receivable(let r): return r.name
        case .recurringExpense(let r): return r.name
        case .recurringIncome(let r): return r.name
        case .wishlistItem(let w): return w.name
        }
    }

    var subtitle: String? {
        switch self {
        case .transaction(let t):
            let amount = t.amount.brl
            let date = t.occurredOn.formatted(date: .abbreviated, time: .omitted)
            let category = t.category?.name ?? "Sem categoria"
            return "\(amount) · \(date) · \(category)"
        case .goal(let g):
            return g.targetAmount.brl
        case .category:
            return nil
        case .account(let a):
            return a.kind.displayName
        case .bill(let b):
            let amount = b.amount.brl
            let date = b.dueDate.formatted(date: .abbreviated, time: .omitted)
            return "\(amount) · vence \(date)"
        case .receivable(let r):
            let amount = r.amount.brl
            let date = r.expectedDate.formatted(date: .abbreviated, time: .omitted)
            return "\(amount) · previsto \(date)"
        case .recurringExpense(let r):
            return "\(r.amount.brl) · dia \(r.dayOfMonth)"
        case .recurringIncome(let r):
            return "\(r.amount.brl) · dia \(r.dayOfMonth)"
        case .wishlistItem(let w):
            return w.estimatedAmount.brl
        }
    }

    var opensDetailOnFocus: Bool {
        switch self {
        case .category: return false
        case .account(let account):
            switch account.kind {
            case .bank, .creditCard: return false
            case .investment, .goal: return true
            }
        default: return true
        }
    }
}

extension SpotlightResult {
    var target: SpotlightTarget {
        switch self {
        case .transaction(let transaction): return .transaction(transaction.id)
        case .goal(let goal): return .goal(goal.id)
        case .category(let category): return .category(category.id)
        case .account(let account): return .account(account.id)
        case .bill(let bill): return .bill(bill.id)
        case .receivable(let receivable): return .receivable(receivable.id)
        case .recurringExpense(let rule): return .recurringExpense(rule.id)
        case .recurringIncome(let rule): return .recurringIncome(rule.id)
        case .wishlistItem(let item): return .wishlistItem(item.id)
        }
    }

    var sidebarDestination: SidebarDestination {
        switch self {
        case .transaction: return .transactions
        case .goal: return .goals
        case .category: return .categories
        case .account(let account):
            if account.kind == .investment || account.kind == .goal { return .investments }
            return .accounts
        case .bill: return .bills
        case .receivable: return .receivables
        case .recurringExpense: return .recurringExpenses
        case .recurringIncome: return .recurringIncomes
        case .wishlistItem: return .wishlist
        }
    }
}

@ViewBuilder
private func spotlightBadge(symbol: String, tint: Color) -> some View {
    CFGlassSymbol(systemName: symbol, tint: tint, size: 30)
}

private func categoryTint(_ category: Category?) -> Color {
    guard let category else { return CFTheme.textSecondary }
    return category.kind == .income ? CFTheme.income : CFTheme.expense
}
