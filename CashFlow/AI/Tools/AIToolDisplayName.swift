import Foundation

enum AIToolDisplayName {
    static func label(for toolName: String) -> String {
        switch toolName {
        case "get_app_context": return "Contexto do app"
        case "get_patrimony": return "Patrimônio"
        case "list_accounts", "get_account": return "Contas"
        case "get_month_summary": return "Fluxo do mês"
        case "get_month_pace": return "Ritmo de gastos"
        case "get_dashboard_insight": return "Resumo da Gio"
        case "get_wishlist_insight": return "Sugestão da lista de desejos"
        case "compare_months": return "Comparar meses"
        case "search_transactions", "list_month_transactions": return "Lançamentos"
        case "get_bills_summary", "list_bills": return "Contas a pagar"
        case "get_receivables_summary", "list_receivables": return "Contas a receber"
        case "list_recurring_expenses": return "Despesas fixas"
        case "list_recurring_incomes": return "Rendas fixas"
        case "list_goals", "get_goal": return "Metas"
        case "list_wishlist": return "Lista de desejos"
        case "get_cash_flow_series": return "Histórico de fluxo"
        case "get_net_worth_series": return "Patrimônio ao longo do tempo"
        case "get_card_statement": return "Fatura do cartão"
        case "list_categories": return "Categorias"
        case "create_bill": return "Criar conta a pagar"
        case "create_receivable": return "Criar conta a receber"
        case "pay_bill": return "Pagar conta"
        case "confirm_receivable": return "Confirmar recebimento"
        case "create_transaction": return "Registrar lançamento"
        case "record_fund_transfer": return "Transferência"
        case "pay_card_invoice": return "Pagar fatura"
        case "reschedule_bill", "reschedule_receivable": return "Reagendar"
        case "create_wishlist_item": return "Adicionar desejo"
        case "update_wishlist_item": return "Atualizar desejo"
        case "delete_wishlist_item": return "Remover desejo"
        case "purchase_wishlist_item": return "Registrar compra"
        case "cancel_bill": return "Cancelar conta"
        case "cancel_receivable": return "Cancelar recebível"
        case "update_bill": return "Editar conta a pagar"
        case "update_receivable": return "Editar conta a receber"
        case "update_transaction": return "Editar lançamento"
        case "delete_transaction": return "Excluir lançamento"
        case "create_recurring_expense": return "Despesa fixa"
        case "create_recurring_income": return "Renda fixa"
        case "create_goal": return "Nova meta"
        case "preview_write_action": return "Pré-visualizar ação"
        default:
            if toolName.hasPrefix("get_") || toolName.hasPrefix("list_") {
                return "Consultar dados"
            }
            if toolName.hasPrefix("create_") || toolName.hasPrefix("update_") || toolName.hasPrefix("delete_") {
                return "Alterar dados"
            }
            return toolName.replacingOccurrences(of: "_", with: " ")
        }
    }

    static func confirmationTitle(for toolName: String) -> String {
        switch toolName {
        case "pay_bill": return "Pagar conta"
        case "confirm_receivable": return "Confirmar recebimento"
        case "create_transaction": return "Registrar lançamento"
        case "create_bill": return "Criar conta a pagar"
        case "create_receivable": return "Criar conta a receber"
        case "record_fund_transfer": return "Transferência"
        case "pay_card_invoice": return "Pagar fatura"
        case "reschedule_bill", "reschedule_receivable": return "Reagendar"
        case "cancel_bill": return "Cancelar conta"
        case "cancel_receivable": return "Cancelar recebível"
        case "update_bill": return "Editar conta a pagar"
        case "update_receivable": return "Editar conta a receber"
        case "update_transaction": return "Editar lançamento"
        case "delete_transaction": return "Excluir lançamento"
        case "create_recurring_expense": return "Despesa fixa"
        case "create_recurring_income": return "Renda fixa"
        case "create_goal": return "Nova meta"
        case "create_wishlist_item": return "Adicionar desejo"
        case "update_wishlist_item": return "Atualizar desejo"
        case "delete_wishlist_item": return "Remover desejo"
        case "purchase_wishlist_item": return "Registrar compra"
        default: return label(for: toolName)
        }
    }

    static func symbol(for toolName: String) -> String {
        if AIToolCatalog.definition(named: toolName)?.isWrite == true {
            return "square.and.pencil"
        }
        switch toolName {
        case "search_transactions", "list_month_transactions": return "magnifyingglass"
        case "get_dashboard_insight", "get_wishlist_insight": return "sparkles"
        case "list_wishlist", "create_wishlist_item", "purchase_wishlist_item": return "cart"
        case "list_goals", "get_goal": return "target"
        case "get_patrimony", "get_net_worth_series": return "chart.line.uptrend.xyaxis"
        default: return "arrow.triangle.branch"
        }
    }
}
