import SwiftUI
import SwiftData

struct PurchaseWishlistItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @Query(filter: #Predicate<Category> { !$0.isArchived },
           sort: [SortDescriptor(\Category.sortOrder)])
    private var categories: [Category]

    let item: WishlistItem

    @State private var paidAmount: Decimal
    @State private var paidDate: Date
    @State private var accountID: UUID?
    @State private var categoryID: UUID?

    init(item: WishlistItem) {
        self.item = item
        _paidAmount = State(initialValue: item.estimatedAmount)
        _paidDate = State(initialValue: .now)
        _accountID = State(initialValue: nil)
        _categoryID = State(initialValue: item.category?.id)
    }

    private var spendableAccounts: [Account] {
        accounts.filter { $0.kind == .bank || $0.kind == .creditCard }
    }

    private var expenseCategories: [Category] {
        categories.filter { $0.kind == .expense }
    }

    private var isValid: Bool {
        paidAmount > 0 && accountID != nil
    }

    private var differenceCaption: String? {
        guard paidAmount != item.estimatedAmount, item.estimatedAmount > 0 else { return nil }
        let delta = paidAmount - item.estimatedAmount
        let prefix = delta > 0 ? "+" : "−"
        return "\(prefix)\(abs(delta).brl) em relação ao estimado"
    }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 460, height: 520)
        .cfCompactSheetToolbar(
            title: "Registrar compra",
            saveTitle: "Comprei",
            saveDisabled: !isValid,
            onCancel: { dismiss() },
            onSave: { confirm(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfGlassSheetChrome()
        .onAppear(perform: applyDefaults)
    }

    private var formContent: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 8) {
                        CFGlassSheetAmountHeader(
                            title: "Valor pago",
                            amount: $paidAmount,
                            amountColor: CFTheme.expense
                        )
                        if let caption = differenceCaption {
                            Text(caption)
                                .font(.callout)
                                .foregroundStyle(paidAmount <= item.estimatedAmount ? CFTheme.income : CFTheme.warning)
                                .padding(.horizontal, 4)
                        }
                    }

                    infoCard

                    CFGlassFormPanel(title: "Pagamento") {
                        VStack(spacing: 0) {
                            CFGlassLabeledField(label: "Conta") { accountPicker }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Categoria") { categoryPicker }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Data") {
                                DateField(date: $paidDate)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .scrollIndicators(.never)
    }

    private var infoCard: some View {
        CFGlassPanel {
            HStack(spacing: 12) {
                CFIconBadge(
                    symbolName: item.category?.symbolName ?? "cart.fill",
                    tint: CFTheme.expense,
                    size: 32
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.body)
                    if let desiredBy = item.desiredBy {
                        Text("Desejo até \(desiredBy.cfRelativeOrAbsoluteDay())")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(item.estimatedAmount.brl)
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
            .padding(.vertical, CFGlassMetrics.rowVerticalPadding)
        }
    }

    @ViewBuilder
    private var accountPicker: some View {
        CFSelectFieldOptional(
            selection: $accountID,
            options: spendableAccounts.map { account in
                CFSelectOption(
                    id: account.id,
                    title: account.name,
                    symbolName: account.symbolName,
                    tint: Color(hex: account.colorHex)
                )
            },
            placeholder: "Selecionar"
        )
    }

    @ViewBuilder
    private var categoryPicker: some View {
        CFSelectFieldOptional(
            selection: $categoryID,
            options: expenseCategories.map { category in
                CFSelectOption(
                    id: category.id,
                    title: category.name,
                    symbolName: category.symbolName,
                    tint: CFTheme.expense
                )
            },
            placeholder: "Opcional"
        )
    }

    private var footer: some View {
        CFGlassSheetFooter(
            confirmTitle: "Comprei",
            confirmDisabled: !isValid,
            onCancel: { dismiss() },
            onConfirm: { confirm(); dismiss() }
        )
    }

    private func applyDefaults() {
        if accountID == nil {
            if let lastID = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastUsedAccountID),
               let uuid = UUID(uuidString: lastID),
               spendableAccounts.contains(where: { $0.id == uuid }) {
                accountID = uuid
            } else {
                accountID = spendableAccounts.first?.id
            }
        }
    }

    private func confirm() {
        guard isValid,
              let accountID,
              let account = spendableAccounts.first(where: { $0.id == accountID })
        else { return }

        let category = categoryID.flatMap { id in expenseCategories.first(where: { $0.id == id }) }
        WishlistPurchaseRecorder.recordPurchase(
            item: item,
            amount: paidAmount,
            account: account,
            date: paidDate,
            category: category,
            modelContext: modelContext
        )
        UserDefaults.standard.set(accountID.uuidString, forKey: UserDefaultsKeys.lastUsedAccountID)
    }
}
