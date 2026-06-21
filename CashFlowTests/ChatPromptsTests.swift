import XCTest
@testable import CashFlow

final class ChatPromptsTests: XCTestCase {
    func testToolUserMessageKeepsFocusOnLatestUserMessage() {
        let prompt = ChatPrompts.userMessage(question: "Quanto economizo reduzindo Uber? Evito ficar muitos dias fora.")

        XCTAssertTrue(prompt.contains("Mensagem mais recente do usuário:"))
        XCTAssertTrue(prompt.contains("Responda diretamente à mensagem mais recente"))
        XCTAssertTrue(prompt.contains("Siga a intenção do usuário"))
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

        XCTAssertTrue(prompt.contains("flexível"))
        XCTAssertTrue(prompt.localizedCaseInsensitiveContains("use as ferramentas do CashFlow para responder com dados reais"))
        XCTAssertTrue(prompt.contains("Para que você serve"))
        XCTAssertTrue(prompt.contains("O que você pode fazer"))
        XCTAssertTrue(prompt.contains("responda só ao que foi pedido agora"))
        XCTAssertTrue(prompt.contains("Não monte overview"))
        XCTAssertTrue(prompt.contains("Perguntas fora de finanças"))
    }

    func testExternalMCPSystemPromptRequiresFastFailWhenUnavailable() {
        let prompt = ChatPrompts.systemForExternalMCPTools()

        XCTAssertTrue(prompt.contains("Modo MCP"))
        XCTAssertTrue(prompt.contains(MCPConfiguration.serverURL))
        XCTAssertTrue(prompt.localizedCaseInsensitiveContains("pare imediatamente"))
        XCTAssertTrue(prompt.localizedCaseInsensitiveContains("NUNCA invente"))
        XCTAssertTrue(prompt.localizedCaseInsensitiveContains("NUNCA estime"))
    }

    func testConversationalContinuationDetectsContextReply() {
        let message = """
        trabalho fica a 20km de distancia, eu levo macbook, iPad, iPhone. \
        Eh fora de questao usar transporte publico ou ir de a pé. \
        As contas a pagar são todas pra depois do recebimento
        """

        XCTAssertTrue(ChatPrompts.isConversationalContinuation(message))
    }

    func testConversationalContinuationDetectsCorrection() {
        let message = "nao pedi nenhuma ação, tava respondendo o que vc disse sobre usar transporte publico"

        XCTAssertTrue(ChatPrompts.isConversationalContinuation(message))
    }

    func testPlanningQuestionIsNotConversationalContinuation() {
        let message = "nao sei como vou sobreviver 14 dias uteis tendo que pegar uber todos os dias"

        XCTAssertFalse(ChatPrompts.isConversationalContinuation(message))
        XCTAssertTrue(ChatPrompts.looksLikeFinancialOrPlanningQuestion(message))
    }
}
