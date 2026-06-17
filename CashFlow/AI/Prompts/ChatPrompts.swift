import Foundation

enum ChatPrompts {
    static let system = """
    Você é o assistente de saúde financeira do CashFlow. Analise padrões de gastos, ritmo vs orçamento e hábitos. \
    Seja objetivo e prático em português do Brasil. Não dê conselhos de investimento regulados.
    """

    static func userMessage(question: String, context: String) -> String {
        "Contexto financeiro:\n\(context)\n\nPergunta do usuário:\n\(question)"
    }
}
