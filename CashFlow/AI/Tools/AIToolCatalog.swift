import Foundation

enum AIToolCatalog {
    static let all: [AIToolDefinition] = readTools + writeTools

    static let readTools: [AIToolDefinition] = [
        // A
        AIToolDefinition(name: "get_app_context", description: "Data/hora atual, mês de referência, moeda BRL e regras realizado vs previsto."),
        // B
        AIToolDefinition(
            name: "get_patrimony",
            description: "Patrimônio líquido, disponível, dívida de cartão, investido, reservado em metas e contas a pagar.",
            parameters: [.init(name: "as_of_date", type: "string", description: "Data ISO ou yyyy-MM-dd", required: false)]
        ),
        AIToolDefinition(
            name: "list_accounts",
            description: "Lista contas com saldo.",
            parameters: [
                .init(name: "kind", type: "string", description: "bank, creditCard, investment ou goal", required: false),
                .init(name: "include_archived", type: "boolean", description: "Incluir arquivadas", required: false),
                .init(name: "as_of_date", type: "string", description: "Data de referência", required: false)
            ]
        ),
        AIToolDefinition(
            name: "get_account",
            description: "Detalhe de uma conta por id ou nome.",
            parameters: [
                .init(name: "account_id", type: "string", description: "UUID da conta", required: false),
                .init(name: "account_name", type: "string", description: "Nome da conta", required: false),
                .init(name: "as_of_date", type: "string", description: "Data de referência", required: false)
            ]
        ),
        // C
        AIToolDefinition(
            name: "get_month_summary",
            description: "Fluxo do mês: realizado, previsto, a receber, saldos.",
            parameters: [.init(name: "reference_date", type: "string", description: "Data no mês de referência", required: false)]
        ),
        AIToolDefinition(
            name: "get_month_pace",
            description: "Ritmo de gastos, % da renda, dias restantes e orçamento diário.",
            parameters: [.init(name: "reference_date", type: "string", description: "Data no mês de referência", required: false)]
        ),
        AIToolDefinition(
            name: "get_dashboard_insight",
            description: "Resumo mensal da Gio salvo no painel Visão geral (texto em bullets). Use quando o usuário quiser conversar sobre o resumo do dashboard.",
            parameters: [
                .init(name: "month_key", type: "string", description: "Mês no formato yyyy-MM", required: false),
                .init(name: "reference_date", type: "string", description: "Qualquer data dentro do mês desejado", required: false)
            ]
        ),
        AIToolDefinition(
            name: "get_wishlist_insight",
            description: "Sugestão da Gio sobre a lista de desejos salva no painel Visão geral. Use quando o usuário quiser conversar sobre timing de compras.",
            parameters: [
                .init(name: "month_key", type: "string", description: "Mês no formato yyyy-MM", required: false),
                .init(name: "reference_date", type: "string", description: "Qualquer data dentro do mês desejado", required: false)
            ]
        ),
        AIToolDefinition(
            name: "compare_months",
            description: "Compara receita e despesa do mês atual vs anterior.",
            parameters: [.init(name: "reference_date", type: "string", description: "Data no mês de referência", required: false)]
        ),
        // D
        AIToolDefinition(
            name: "search_transactions",
            description: "Busca flexível de lançamentos. O parâmetro text procura na nota, categoria e conta. Sem datas, limita ao mês atual.",
            parameters: [
                .init(name: "date_from", type: "string", description: "Data inicial", required: false),
                .init(name: "date_to", type: "string", description: "Data final", required: false),
                .init(name: "kind", type: "string", description: "income ou expense", required: false),
                .init(name: "account_id", type: "string", description: "UUID da conta", required: false),
                .init(name: "account_name", type: "string", description: "Nome da conta", required: false),
                .init(name: "category_id", type: "string", description: "UUID da categoria", required: false),
                .init(name: "category_name", type: "string", description: "Nome da categoria", required: false),
                .init(name: "text", type: "string", description: "Texto na nota, categoria ou conta", required: false),
                .init(name: "include_transfers", type: "boolean", description: "Incluir transferências", required: false),
                .init(name: "status", type: "string", description: "realized, planned ou all", required: false),
                .init(name: "limit", type: "integer", description: "Máximo de resultados (default 30)", required: false)
            ]
        ),
        AIToolDefinition(
            name: "list_month_transactions",
            description: "Lançamentos do mês de referência.",
            parameters: [
                .init(name: "reference_date", type: "string", description: "Data no mês", required: false),
                .init(name: "status", type: "string", description: "realized, planned ou all", required: false),
                .init(name: "exclude_transfers", type: "boolean", description: "Excluir transferências", required: false)
            ]
        ),
        AIToolDefinition(
            name: "get_transaction",
            description: "Detalhe de um lançamento por ID.",
            parameters: [.init(name: "transaction_id", type: "string", description: "UUID", required: true)]
        ),
        AIToolDefinition(
            name: "list_recent_transactions",
            description: "Últimos lançamentos em N dias.",
            parameters: [
                .init(name: "days", type: "integer", description: "Dias (default 90)", required: false),
                .init(name: "limit", type: "integer", description: "Máximo (default 30)", required: false)
            ]
        ),
        // E
        AIToolDefinition(
            name: "list_bills",
            description: "Lista contas a pagar.",
            parameters: [
                .init(name: "status", type: "string", description: "pending, paid, cancelled ou all", required: false),
                .init(name: "overdue_only", type: "boolean", description: "Somente vencidas", required: false),
                .init(name: "due_before", type: "string", description: "Vence antes de", required: false),
                .init(name: "due_after", type: "string", description: "Vence depois de", required: false),
                .init(name: "account_id", type: "string", description: "UUID da conta", required: false),
                .init(name: "limit", type: "integer", description: "Máximo", required: false)
            ]
        ),
        AIToolDefinition(
            name: "get_bill",
            description: "Detalhe de conta a pagar.",
            parameters: [
                .init(name: "bill_id", type: "string", description: "UUID", required: false),
                .init(name: "bill_name", type: "string", description: "Nome", required: false)
            ]
        ),
        AIToolDefinition(
            name: "get_bills_summary",
            description: "Totais de contas a pagar pendentes e vencidas.",
            parameters: [.init(name: "reference_date", type: "string", description: "Mês de referência", required: false)]
        ),
        // F
        AIToolDefinition(
            name: "list_receivables",
            description: "Lista contas a receber.",
            parameters: [
                .init(name: "status", type: "string", description: "pending, received ou all", required: false),
                .init(name: "late_only", type: "boolean", description: "Somente atrasadas", required: false),
                .init(name: "expected_in_month", type: "boolean", description: "Somente no mês", required: false),
                .init(name: "reference_date", type: "string", description: "Mês de referência", required: false),
                .init(name: "limit", type: "integer", description: "Máximo", required: false)
            ]
        ),
        AIToolDefinition(
            name: "get_receivable",
            description: "Detalhe de conta a receber.",
            parameters: [
                .init(name: "receivable_id", type: "string", description: "UUID", required: false),
                .init(name: "receivable_name", type: "string", description: "Nome", required: false)
            ]
        ),
        AIToolDefinition(
            name: "get_receivables_summary",
            description: "Totais pendentes e atrasados no mês.",
            parameters: [.init(name: "reference_date", type: "string", description: "Mês de referência", required: false)]
        ),
        // G
        AIToolDefinition(
            name: "list_recurring_expenses",
            description: "Regras de despesa fixa.",
            parameters: [
                .init(name: "active_only", type: "boolean", description: "Somente ativas", required: false),
                .init(name: "include_paused", type: "boolean", description: "Incluir pausadas", required: false)
            ]
        ),
        AIToolDefinition(
            name: "list_recurring_incomes",
            description: "Regras de renda fixa.",
            parameters: [
                .init(name: "active_only", type: "boolean", description: "Somente ativas", required: false),
                .init(name: "include_paused", type: "boolean", description: "Incluir pausadas", required: false)
            ]
        ),
        AIToolDefinition(
            name: "get_recurring_expense",
            description: "Detalhe de despesa fixa.",
            parameters: [
                .init(name: "rule_id", type: "string", description: "UUID", required: false),
                .init(name: "name", type: "string", description: "Nome", required: false)
            ]
        ),
        AIToolDefinition(
            name: "get_recurring_income",
            description: "Detalhe de renda fixa.",
            parameters: [
                .init(name: "rule_id", type: "string", description: "UUID", required: false),
                .init(name: "name", type: "string", description: "Nome", required: false)
            ]
        ),
        // H
        AIToolDefinition(
            name: "list_goals",
            description: "Metas com progresso.",
            parameters: [
                .init(name: "active_only", type: "boolean", description: "Somente ativas (default true)", required: false),
                .init(name: "include_completed", type: "boolean", description: "Incluir concluídas", required: false)
            ]
        ),
        AIToolDefinition(
            name: "get_goal",
            description: "Detalhe completo de uma meta.",
            parameters: [
                .init(name: "goal_id", type: "string", description: "UUID", required: false),
                .init(name: "goal_name", type: "string", description: "Nome", required: false)
            ]
        ),
        // W
        AIToolDefinition(
            name: "list_wishlist",
            description: "Lista de desejos de compra com totais por prioridade."
        ),
        // I
        AIToolDefinition(
            name: "get_investments_summary",
            description: "Total investido, reservado em metas e aportes líquidos do mês.",
            parameters: [.init(name: "reference_date", type: "string", description: "Mês de referência", required: false)]
        ),
        AIToolDefinition(
            name: "list_fund_accounts",
            description: "Contas investment e goal com saldos.",
            parameters: [
                .init(name: "kind", type: "string", description: "investment ou goal", required: false),
                .init(name: "as_of_date", type: "string", description: "Data de referência", required: false)
            ]
        ),
        AIToolDefinition(
            name: "list_transfers",
            description: "Aportes, resgates e depósitos em meta.",
            parameters: [
                .init(name: "date_from", type: "string", description: "Data inicial", required: false),
                .init(name: "date_to", type: "string", description: "Data final", required: false),
                .init(name: "fund_kind", type: "string", description: "investment ou goal", required: false),
                .init(name: "direction", type: "string", description: "deposit ou withdraw", required: false),
                .init(name: "limit", type: "integer", description: "Máximo", required: false)
            ]
        ),
        // J
        AIToolDefinition(name: "list_credit_cards", description: "Cartões com saldo devedor e datas de fechamento/vencimento."),
        AIToolDefinition(
            name: "get_card_statement",
            description: "Fatura aberta de um cartão.",
            parameters: [
                .init(name: "account_id", type: "string", description: "UUID do cartão", required: false),
                .init(name: "account_name", type: "string", description: "Nome do cartão", required: false)
            ]
        ),
        // K
        AIToolDefinition(
            name: "list_categories",
            description: "Categorias cadastradas.",
            parameters: [.init(name: "kind", type: "string", description: "expense ou income", required: false)]
        ),
        AIToolDefinition(
            name: "get_category_breakdown",
            description: "Top categorias por despesa ou receita.",
            parameters: [
                .init(name: "reference_date", type: "string", description: "Mês de referência", required: false),
                .init(name: "period", type: "string", description: "3m, 6m, 12m ou ytd", required: false),
                .init(name: "kind", type: "string", description: "expense ou income", required: false),
                .init(name: "limit", type: "integer", description: "Máximo", required: false)
            ]
        ),
        AIToolDefinition(
            name: "get_expenses_by_account",
            description: "Gastos realizados por conta no mês.",
            parameters: [.init(name: "reference_date", type: "string", description: "Mês de referência", required: false)]
        ),
        // L
        AIToolDefinition(
            name: "get_cash_flow_series",
            description: "Entrada e saída por mês.",
            parameters: [
                .init(name: "period", type: "string", description: "3m, 6m, 12m ou ytd", required: true),
                .init(name: "reference_date", type: "string", description: "Data de referência", required: false)
            ]
        ),
        AIToolDefinition(
            name: "get_net_worth_series",
            description: "Patrimônio líquido por mês.",
            parameters: [
                .init(name: "period", type: "string", description: "3m, 6m, 12m ou ytd", required: true),
                .init(name: "reference_date", type: "string", description: "Data de referência", required: false)
            ]
        ),
        AIToolDefinition(
            name: "get_investment_flow_series",
            description: "Aportes líquidos por mês.",
            parameters: [
                .init(name: "period", type: "string", description: "3m, 6m, 12m ou ytd", required: true),
                .init(name: "reference_date", type: "string", description: "Data de referência", required: false)
            ]
        ),
        AIToolDefinition(
            name: "preview_write_action",
            description: "Valida argumentos de uma ação de escrita e retorna o resumo da confirmação, sem criar proposta nem alterar dados. Passe os mesmos parâmetros da ferramenta alvo além de action.",
            parameters: [
                .init(name: "action", type: "string", description: "Nome da ferramenta de escrita (ex.: pay_bill, create_transaction)", required: true)
            ]
        )
    ]

    static let writeTools: [AIToolDefinition] = [
        AIToolDefinition(
            name: "record_fund_transfer",
            description: "Aporte ou resgate entre banco e investimento/meta. Requer confirmação.",
            parameters: [
                .init(name: "direction", type: "string", description: "deposit ou withdraw", required: true),
                .init(name: "amount", type: "number", description: "Valor em reais", required: true),
                .init(name: "bank_account", type: "string", description: "Conta bancária", required: true),
                .init(name: "fund_account", type: "string", description: "Conta investimento/meta", required: true),
                .init(name: "date", type: "string", description: "Data", required: false),
                .init(name: "note", type: "string", description: "Nota", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "create_transaction",
            description: "Despesa ou receita avulsa. Requer confirmação.",
            parameters: [
                .init(name: "kind", type: "string", description: "income ou expense", required: true),
                .init(name: "amount", type: "number", description: "Valor", required: true),
                .init(name: "account", type: "string", description: "Conta", required: true),
                .init(name: "category", type: "string", description: "Categoria", required: false),
                .init(name: "date", type: "string", description: "Data", required: false),
                .init(name: "note", type: "string", description: "Nota", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "pay_bill",
            description: "Marcar conta a pagar como paga. Requer confirmação.",
            parameters: [
                .init(name: "bill", type: "string", description: "Nome ou ID da conta", required: true),
                .init(name: "amount", type: "number", description: "Valor pago", required: false),
                .init(name: "paid_date", type: "string", description: "Data do pagamento", required: false),
                .init(name: "account", type: "string", description: "Conta de saída", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "confirm_receivable",
            description: "Confirmar recebimento. Requer confirmação.",
            parameters: [
                .init(name: "receivable", type: "string", description: "Nome ou ID", required: true),
                .init(name: "amount", type: "number", description: "Valor recebido", required: false),
                .init(name: "received_date", type: "string", description: "Data", required: false),
                .init(name: "account", type: "string", description: "Conta de entrada", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "create_bill",
            description: "Nova conta a pagar. Requer confirmação.",
            parameters: [
                .init(name: "name", type: "string", description: "Nome", required: true),
                .init(name: "amount", type: "number", description: "Valor", required: true),
                .init(name: "due_date", type: "string", description: "Vencimento", required: true),
                .init(name: "account", type: "string", description: "Conta", required: false),
                .init(name: "category", type: "string", description: "Categoria", required: false),
                .init(name: "note", type: "string", description: "Nota", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "create_receivable",
            description: "Nova conta a receber. Requer confirmação.",
            parameters: [
                .init(name: "name", type: "string", description: "Nome", required: true),
                .init(name: "amount", type: "number", description: "Valor", required: true),
                .init(name: "expected_date", type: "string", description: "Data prevista", required: true),
                .init(name: "account", type: "string", description: "Conta", required: false),
                .init(name: "category", type: "string", description: "Categoria", required: false),
                .init(name: "note", type: "string", description: "Nota", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "reschedule_bill",
            description: "Alterar vencimento. Requer confirmação.",
            parameters: [
                .init(name: "bill", type: "string", description: "Nome ou ID", required: true),
                .init(name: "new_due_date", type: "string", description: "Novo vencimento", required: true)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "reschedule_receivable",
            description: "Alterar data prevista. Requer confirmação.",
            parameters: [
                .init(name: "receivable", type: "string", description: "Nome ou ID", required: true),
                .init(name: "new_expected_date", type: "string", description: "Nova data", required: true)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "pay_card_invoice",
            description: "Pagamento de fatura de cartão. Requer confirmação.",
            parameters: [
                .init(name: "card_account", type: "string", description: "Cartão", required: true),
                .init(name: "bank_account", type: "string", description: "Conta bancária", required: true),
                .init(name: "amount", type: "number", description: "Valor", required: true),
                .init(name: "date", type: "string", description: "Data", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "create_wishlist_item",
            description: "Adiciona item à lista de desejos. Requer confirmação.",
            parameters: [
                .init(name: "name", type: "string", description: "Nome", required: true),
                .init(name: "estimated_amount", type: "number", description: "Valor estimado", required: true),
                .init(name: "priority", type: "string", description: "low, medium, high ou urgent", required: false),
                .init(name: "category", type: "string", description: "Categoria de despesa", required: false),
                .init(name: "desired_by", type: "string", description: "Data desejada", required: false),
                .init(name: "note", type: "string", description: "Notas", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "update_wishlist_item",
            description: "Atualiza item da lista de desejos. Requer confirmação.",
            parameters: [
                .init(name: "item_id", type: "string", description: "UUID", required: false),
                .init(name: "item_name", type: "string", description: "Nome", required: false),
                .init(name: "name", type: "string", description: "Novo nome", required: false),
                .init(name: "estimated_amount", type: "number", description: "Novo valor", required: false),
                .init(name: "priority", type: "string", description: "Nova prioridade", required: false),
                .init(name: "category", type: "string", description: "Nova categoria", required: false),
                .init(name: "desired_by", type: "string", description: "Nova data desejada", required: false),
                .init(name: "note", type: "string", description: "Novas notas", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "delete_wishlist_item",
            description: "Remove item da lista sem registrar compra. Requer confirmação.",
            parameters: [
                .init(name: "item_id", type: "string", description: "UUID", required: false),
                .init(name: "item_name", type: "string", description: "Nome", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "purchase_wishlist_item",
            description: "Registra compra de item da lista (cria despesa e remove o item). Requer confirmação.",
            parameters: [
                .init(name: "item_id", type: "string", description: "UUID", required: false),
                .init(name: "item_name", type: "string", description: "Nome", required: false),
                .init(name: "amount", type: "number", description: "Valor pago", required: false),
                .init(name: "account", type: "string", description: "Conta", required: false),
                .init(name: "date", type: "string", description: "Data", required: false),
                .init(name: "category", type: "string", description: "Categoria", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "cancel_bill",
            description: "Cancela conta a pagar pendente (não vale para faturas de cartão). Requer confirmação.",
            parameters: [
                .init(name: "bill", type: "string", description: "Nome ou ID da conta", required: true)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "cancel_receivable",
            description: "Cancela conta a receber pendente. Requer confirmação.",
            parameters: [
                .init(name: "receivable", type: "string", description: "Nome ou ID", required: true)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "update_bill",
            description: "Atualiza conta a pagar pendente. Requer confirmação.",
            parameters: [
                .init(name: "bill", type: "string", description: "Nome ou ID", required: true),
                .init(name: "name", type: "string", description: "Novo nome", required: false),
                .init(name: "amount", type: "number", description: "Novo valor", required: false),
                .init(name: "due_date", type: "string", description: "Novo vencimento", required: false),
                .init(name: "account", type: "string", description: "Conta", required: false),
                .init(name: "category", type: "string", description: "Categoria", required: false),
                .init(name: "note", type: "string", description: "Nota", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "update_receivable",
            description: "Atualiza conta a receber pendente. Requer confirmação.",
            parameters: [
                .init(name: "receivable", type: "string", description: "Nome ou ID", required: true),
                .init(name: "name", type: "string", description: "Novo nome", required: false),
                .init(name: "amount", type: "number", description: "Novo valor", required: false),
                .init(name: "expected_date", type: "string", description: "Nova data prevista", required: false),
                .init(name: "account", type: "string", description: "Conta", required: false),
                .init(name: "category", type: "string", description: "Categoria", required: false),
                .init(name: "note", type: "string", description: "Nota", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "update_transaction",
            description: "Atualiza lançamento existente. Requer confirmação.",
            parameters: [
                .init(name: "transaction_id", type: "string", description: "UUID do lançamento", required: true),
                .init(name: "amount", type: "number", description: "Novo valor", required: false),
                .init(name: "kind", type: "string", description: "income ou expense", required: false),
                .init(name: "account", type: "string", description: "Conta", required: false),
                .init(name: "category", type: "string", description: "Categoria", required: false),
                .init(name: "date", type: "string", description: "Data", required: false),
                .init(name: "note", type: "string", description: "Nota", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "delete_transaction",
            description: "Exclui lançamento. Requer confirmação.",
            parameters: [
                .init(name: "transaction_id", type: "string", description: "UUID do lançamento", required: true)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "create_recurring_expense",
            description: "Cadastra despesa fixa mensal (gera lançamentos ou contas a pagar). Requer confirmação.",
            parameters: [
                .init(name: "name", type: "string", description: "Nome", required: true),
                .init(name: "amount", type: "number", description: "Valor mensal", required: true),
                .init(name: "day_of_month", type: "integer", description: "Dia do mês (1–31)", required: true),
                .init(name: "account", type: "string", description: "Conta bancária ou cartão", required: true),
                .init(name: "category", type: "string", description: "Categoria de despesa", required: true),
                .init(name: "start_date", type: "string", description: "Início (default hoje)", required: false),
                .init(name: "requires_confirmation", type: "boolean", description: "Gera contas a pagar em vez de lançamentos automáticos", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "create_recurring_income",
            description: "Cadastra renda fixa mensal (gera lançamentos ou contas a receber). Requer confirmação.",
            parameters: [
                .init(name: "name", type: "string", description: "Nome", required: true),
                .init(name: "amount", type: "number", description: "Valor mensal", required: true),
                .init(name: "day_of_month", type: "integer", description: "Dia do mês (1–31)", required: true),
                .init(name: "account", type: "string", description: "Conta bancária", required: true),
                .init(name: "category", type: "string", description: "Categoria de receita", required: true),
                .init(name: "start_date", type: "string", description: "Início (default hoje)", required: false),
                .init(name: "requires_confirmation", type: "boolean", description: "Gera contas a receber em vez de lançamentos automáticos", required: false)
            ],
            isWrite: true
        ),
        AIToolDefinition(
            name: "create_goal",
            description: "Cria meta financeira com conta dedicada. Requer confirmação.",
            parameters: [
                .init(name: "name", type: "string", description: "Nome da meta", required: true),
                .init(name: "target_amount", type: "number", description: "Valor alvo", required: true),
                .init(name: "deadline", type: "string", description: "Prazo", required: false),
                .init(name: "opening_balance", type: "number", description: "Saldo inicial da conta da meta", required: false),
                .init(name: "notes", type: "string", description: "Notas", required: false)
            ],
            isWrite: true
        )
    ]

    static func definition(named name: String) -> AIToolDefinition? {
        all.first { $0.name == name }
    }
}
