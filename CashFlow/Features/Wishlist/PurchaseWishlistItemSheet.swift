import SwiftUI
import SwiftData

struct PurchaseWishlistItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var privacy: PrivacyMode

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
        return "\(prefix)\(abs(delta).brl(masked: privacy.valuesHidden)) em relação ao estimado"
    }

    var body: some View {
        VStack(spacing: 0) {
            CFAmountHeader(
                title: "Valor pago",
                amount: $paidAmount,
                amountColor: CFTheme.expense
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            if let caption = differenceCaption {
                Text(caption)
                    .font(CFTheme.caption())
                    .foregroundStyle(paidAmount <= item.estimatedAmount ? CFTheme.income : CFTheme.warning)
                    .padding(.bottom, 14)
            } else {
                Spacer().frame(height: 8)
            }

            Divider()
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 460, height: 480)
        .cfCompactSheetToolbar(
            title: "Registrar compra",
            saveTitle: "Comprei",
            saveDisabled: !isValid,
            onCancel: { dismiss() },
            onSave: { confirm(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfSheetBackground()
        .tint(CFTheme.accent)
        .onAppear(perform: applyDefaults)
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                infoCard
                section(title: "Pagamento") {
                    labeledRow("Conta") { accountPicker }
                    labeledRow("Categoria") { categoryPicker }
                    labeledRow("Data") {
                        DateField(date: $paidDate)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.never)
    }

    private var infoCard: some View {
        HStack(spacing: 12) {
            CFIconBadge(
                symbolName: item.category?.symbolName ?? "cart.fill",
                tint: CFTheme.expense,
                size: 32
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                if let desiredBy = item.desiredBy {
                    Text("Desejo até \(desiredBy.cfRelativeOrAbsoluteDay())")
                        .font(CFTheme.caption())
                        .foregroundStyle(CFTheme.textSecondary)
                }
            }
            Spacer()
            Text(item.estimatedAmount.brl(masked: privacy.valuesHidden))
                .font(.callout.monospacedDigit())
                .foregroundStyle(CFTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CFTheme.surfaceElevated.opacity(0.5))
        )
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

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)
            VStack(spacing: 6) {
                content()
            }
        }
    }

    private func labeledRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(CFTheme.body())
                .foregroundStyle(CFTheme.textSecondary)
            Spacer(minLength: 8)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(CFTheme.surfaceElevated.opacity(0.38))
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            CFPillButton(title: "Cancelar", style: .ghost) { dismiss() }
                .keyboardShortcut(.cancelAction)
            CFPillButton(title: "Comprei", style: .primary) {
                confirm()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .opacity(isValid ? 1 : 0.5)
            .allowsHitTesting(isValid)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
