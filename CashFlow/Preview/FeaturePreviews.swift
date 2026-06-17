import SwiftData
import SwiftUI

#if DEBUG

// MARK: - Cadastros

#Preview("Contas") {
    AccountsView()
        .previewCashFlow()
}

#Preview("Categorias") {
    CategoriesView()
        .previewCashFlow()
}

// MARK: - Movimentações

#Preview("Lançamentos") {
    TransactionListView()
        .previewCashFlow()
}

#Preview("Novo lançamento") {
    AddTransactionSheet()
        .previewSheet(width: 440, height: 440)
        .environmentObject(PreviewData.aiService)
}

#Preview("Linha de lançamento") {
    if let transaction = PreviewData.sampleTransactions.first {
        TransactionRow(transaction: transaction)
            .padding(20)
            .previewCashFlow(width: 520, height: 120)
    }
}

// MARK: - Dashboard

#Preview("Visão geral") {
    MonthDashboardView()
        .previewCashFlow(width: 1100, height: 900)
}

#Preview("Card categorias") {
    CategoryBreakdownCard(
        aggregates: PreviewData.monthSummary.expensesByCategory,
        totalExpense: PreviewData.monthSummary.totalExpense
    )
    .padding(20)
    .previewCashFlow(width: 420, height: 320)
}

#Preview("Card contas") {
    AccountBreakdownCard(aggregates: PreviewData.monthSummary.expensesByAccount)
        .padding(20)
        .previewCashFlow(width: 420, height: 280)
}

// MARK: - Cartão / fatura

#Preview("Fatura aberta — só saldo inicial") {
    CardInvoiceSheet(account: PreviewData.creditCard)
        .previewSheet(width: 520, height: 400)
}

#Preview("Pagar fatura") {
    PayInvoiceSheet(card: PreviewData.creditCard, maxAmount: 1500)
        .previewSheet(width: 480, height: 420)
}

// MARK: - Inteligência

#Preview("Configuração IA") {
    AISettingsView()
        .previewSheet(width: 520, height: 560)
        .environmentObject(PreviewData.aiService)
}

#Preview("Chat IA") {
    AIChatSidePanel(aiService: PreviewData.aiService)
        .previewCashFlow(width: 360, height: 640)
}

// MARK: - App shell

#Preview("App") {
    RootSidebarView()
        .previewCashFlow(width: 1100, height: 760)
}

#endif
