import XCTest
@testable import CashFlow

final class ChatPromptsTests: XCTestCase {
    func testToolUserMessageKeepsFocusOnLatestUserMessage() {
        let prompt = ChatPrompts.userMessage(question: "Quanto economizo reduzindo Uber? Evito ficar muitos dias fora.")

        XCTAssertTrue(prompt.contains("Mensagem mais recente do usuário:"))
        XCTAssertTrue(prompt.contains("Responda diretamente à mensagem mais recente"))
        XCTAssertTrue(prompt.contains("Use o histórico apenas para manter o fio da conversa"))
    }

    func testFallbackUserMessageUsesContextOnlyWhenRelevant() {
        let prompt = ChatPrompts.userMessage(
            question: "E se eu dormir fora só alguns dias?",
            context: "Saldo do mês: -R$ 392,69"
        )

        XCTAssertTrue(prompt.contains("Contexto financeiro:"))
        XCTAssertTrue(prompt.contains("Use o contexto financeiro apenas quando ele ajudar"))
        XCTAssertTrue(prompt.contains("E se eu dormir fora só alguns dias?"))
    }

    func testSystemPromptDiscouragesUnrequestedMonthDump() {
        let prompt = ChatPrompts.system()

        XCTAssertTrue(prompt.contains("responda SOMENTE o que a mensagem mais recente pediu"))
        XCTAssertTrue(prompt.contains("Não despeje resumo geral do mês"))
        XCTAssertTrue(prompt.contains("responda esse ponto diretamente"))
    }
}
