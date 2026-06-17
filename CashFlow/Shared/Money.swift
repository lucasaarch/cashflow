import Foundation

enum Money {
    static let locale = Locale(identifier: "pt_BR")
    static let currencyCode = "BRL"
}

extension Decimal {
    var brl: String {
        formatted(.currency(code: Money.currencyCode).locale(Money.locale))
    }
}
