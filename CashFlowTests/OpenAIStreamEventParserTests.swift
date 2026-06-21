import XCTest
@testable import CashFlow

final class OpenAIStreamEventParserTests: XCTestCase {
    func testParsesContentChunk() {
        var parser = OpenAIStreamEventParser()
        let line = #"data: {"choices":[{"delta":{"content":"Olá"}}]}"#
        let chunk = parser.parseSSELine(line)
        XCTAssertEqual(chunk?.content, "Olá")
        XCTAssertNil(chunk?.toolCallEvent)
    }

    func testParsesToolStartedAndCompletedWithMatchingCallID() {
        var parser = OpenAIStreamEventParser()
        let started = #"data: {"choices":[{"delta":{}}],"x_tool_call":{"name":"get_month_summary","server":"cashflow","status":"started"}}"#
        let completed = #"data: {"choices":[{"delta":{}}],"x_tool_call":{"name":"get_month_summary","server":"cashflow","status":"completed"}}"#

        let startChunk = parser.parseSSELine(started)
        XCTAssertEqual(startChunk?.toolCallEvent?.name, "get_month_summary")
        XCTAssertEqual(startChunk?.toolCallEvent?.status, .started)
        let callID = startChunk?.toolCallEvent?.callID
        XCTAssertNotNil(callID)

        let completeChunk = parser.parseSSELine(completed)
        XCTAssertEqual(completeChunk?.toolCallEvent?.status, .completed)
        XCTAssertEqual(completeChunk?.toolCallEvent?.callID, callID)
    }

    func testIgnoresNonCashflowServer() {
        var parser = OpenAIStreamEventParser()
        let line = #"data: {"x_tool_call":{"name":"get_month_summary","server":"other","status":"started"}}"#
        XCTAssertNil(parser.parseSSELine(line))
    }

    func testParsesDoneAsFinished() {
        var parser = OpenAIStreamEventParser()
        let chunk = parser.parseSSELine("data: [DONE]")
        XCTAssertTrue(chunk?.isFinished == true)
    }

    func testIgnoresInvalidJSON() {
        var parser = OpenAIStreamEventParser()
        XCTAssertNil(parser.parseSSELine("data: not-json"))
    }

    func testParallelToolsGetDistinctCallIDs() {
        var parser = OpenAIStreamEventParser()
        let a = parser.parseSSELine(#"data: {"x_tool_call":{"name":"list_bills","server":"cashflow","status":"started"}}"#)
        let b = parser.parseSSELine(#"data: {"x_tool_call":{"name":"get_month_pace","server":"cashflow","status":"started"}}"#)
        XCTAssertNotEqual(a?.toolCallEvent?.callID, b?.toolCallEvent?.callID)
    }
}
