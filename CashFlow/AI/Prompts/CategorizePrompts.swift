import Foundation

enum CategorizePrompts {
    static let parseTransaction = """
    Extraia um lançamento financeiro do texto do usuário. Responda APENAS JSON válido com as chaves:
    amount (número decimal), kind ("income" ou "expense"), categoryName, accountName, date (ISO8601 ou null), note.
    """

    static func suggestCategory(categories: [(id: String, name: String, kind: String)], amount: Decimal, kind: String, note: String) -> String {
        let list = categories.map { "- id: \($0.id), nome: \($0.name), tipo: \($0.kind)" }.joined(separator: "\n")
        return """
        Escolha a melhor categoria para este lançamento.
        Valor: \(amount)
        Tipo: \(kind)
        Nota: \(note)
        Categorias disponíveis:
        \(list)
        Responda APENAS JSON: {"categoryId":"...","confidence":0.0}
        """
    }
}
