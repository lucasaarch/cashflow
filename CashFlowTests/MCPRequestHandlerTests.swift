import XCTest
import SwiftData
@testable import CashFlow

@MainActor
final class MCPRequestHandlerTests: XCTestCase {
    private var container: ModelContainer!
    private var handler: MCPRequestHandler!

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.make(inMemory: true)
        handler = MCPRequestHandler(container: container)
        MCPWriteProposalStore.shared.clear()
        UserDefaults.standard.removeObject(forKey: "mcp.writeProposals.applied")
        UserDefaults.standard.removeObject(forKey: "mcp.writeProposals.cancelled")
    }

    func testToolsListExposesReadAndWriteTools() throws {
        _ = handler.handle(makeJSONRPCRequest(method: "initialize", id: 1))

        let response = handler.handle(makeJSONRPCRequest(method: "tools/list", id: 2))
        let payload = try decodeJSONResponse(response)
        let result = payload["result"] as? [String: Any]
        let tools = result?["tools"] as? [[String: Any]] ?? []
        let names = Set(tools.compactMap { $0["name"] as? String })

        XCTAssertEqual(names, Set(AIToolCatalog.all.map(\.name)))
        XCTAssertTrue(names.contains("create_transaction"))
        XCTAssertTrue(names.contains("pay_bill"))

        let payBill = tools.first { ($0["name"] as? String) == "pay_bill" }
        let description = payBill?["description"] as? String ?? ""
        XCTAssertTrue(description.contains("Apenas cria uma proposta"))

        let payBillAnnotations = payBill?["annotations"] as? [String: Any]
        XCTAssertEqual(payBillAnnotations?["readOnlyHint"] as? Bool, true)

        let getAppContext = tools.first { ($0["name"] as? String) == "get_app_context" }
        XCTAssertNil(getAppContext?["annotations"])

        for writeTool in AIToolCatalog.writeTools {
            let entry = tools.first { ($0["name"] as? String) == writeTool.name }
            let annotations = entry?["annotations"] as? [String: Any]
            XCTAssertEqual(
                annotations?["readOnlyHint"] as? Bool,
                true,
                "Expected readOnlyHint for \(writeTool.name)"
            )
        }
    }

    func testToolsCallPreviewWriteActionReturnsSummary() throws {
        _ = handler.handle(makeJSONRPCRequest(method: "initialize", id: 1))

        let response = handler.handle(
            makeJSONRPCRequest(
                method: "tools/call",
                id: 2,
                params: [
                    "name": "preview_write_action",
                    "arguments": [
                        "action": "create_bill",
                        "name": "Aluguel",
                        "amount": 1500,
                        "due_date": "2026-07-05"
                    ]
                ]
            )
        )

        let payload = try decodeJSONResponse(response)
        let result = payload["result"] as? [String: Any]
        let content = result?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String ?? ""

        XCTAssertEqual(result?["isError"] as? Bool, false)
        XCTAssertTrue(text.contains("Aluguel"))
        XCTAssertTrue(text.contains("1.500"))
    }

    func testToolsCallReadToolReturnsJSON() throws {
        _ = handler.handle(makeJSONRPCRequest(method: "initialize", id: 1))

        let response = handler.handle(
            makeJSONRPCRequest(
                method: "tools/call",
                id: 2,
                params: [
                    "name": "get_app_context",
                    "arguments": [:]
                ]
            )
        )

        let payload = try decodeJSONResponse(response)
        let result = payload["result"] as? [String: Any]
        let content = result?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String
        let isError = result?["isError"] as? Bool

        XCTAssertEqual(isError, false)
        XCTAssertNotNil(text)
        XCTAssertTrue(text?.contains("\"ok\"") == true)
    }

    func testToolsCallWriteToolReturnsPendingProposal() throws {
        _ = handler.handle(makeJSONRPCRequest(method: "initialize", id: 1))

        let response = handler.handle(
            makeJSONRPCRequest(
                method: "tools/call",
                id: 2,
                params: [
                    "name": "pay_bill",
                    "arguments": ["bill": "Conta de luz"]
                ]
            )
        )

        let payload = try decodeJSONResponse(response)
        let result = payload["result"] as? [String: Any]
        let isError = result?["isError"] as? Bool
        let content = result?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String ?? ""

        XCTAssertEqual(isError, false)
        XCTAssertTrue(text.contains("\"status\":\"pending_confirmation\""))
        XCTAssertTrue(text.contains("\"action\":\"pay_bill\""))
        XCTAssertTrue(text.contains("confirmation_id"))
        XCTAssertEqual(MCPWriteProposalStore.shared.pendingWrite?.toolName, "pay_bill")
        XCTAssertEqual(MCPWriteProposalStore.shared.pendingWrite?.source, .mcp)
    }

    func testApplyWriteProposalIsIdempotent() throws {
        _ = handler.handle(makeJSONRPCRequest(method: "initialize", id: 1))

        let response = handler.handle(
            makeJSONRPCRequest(
                method: "tools/call",
                id: 2,
                params: [
                    "name": "pay_bill",
                    "arguments": ["bill": "Inexistente"]
                ]
            )
        )

        let payload = try decodeJSONResponse(response)
        let result = payload["result"] as? [String: Any]
        let content = result?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String ?? ""
        let proposalData = text.data(using: .utf8)!
        let proposal = try JSONDecoder().decode(MCPWriteProposalResponse.self, from: proposalData)
        guard let pending = MCPWriteProposalStore.shared.pendingWrite else {
            return XCTFail("Expected pending write")
        }

        XCTAssertThrowsError(try MCPWriteProposalService.apply(pending, container: container))

        MCPWriteProposalService.markApplied(pending.id, container: container)
        XCTAssertNoThrow(try MCPWriteProposalService.apply(pending, container: container))
        XCTAssertEqual(proposal.confirmationID, pending.id.uuidString)
    }

    private func makeJSONRPCRequest(method: String, id: Int, params: [String: Any] = [:]) -> MCPHTTPRequest {
        var body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "id": id
        ]
        if !params.isEmpty {
            body["params"] = params
        }
        let data = try! JSONSerialization.data(withJSONObject: body)
        return MCPHTTPRequest(method: "POST", path: MCPConfiguration.endpointPath, headers: ["accept": "application/json"], body: data)
    }

    private func decodeJSONResponse(_ response: MCPHTTPResponse) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: response.body)
        return object as? [String: Any] ?? [:]
    }
}

final class MCPJSONSchemaTests: XCTestCase {
    func testBuildsObjectSchemaWithRequiredFields() {
        let definition = AIToolDefinition(
            name: "sample",
            description: "Sample tool",
            parameters: [
                .init(name: "required_field", type: "string", description: "Required", required: true),
                .init(name: "optional_field", type: "integer", description: "Optional", required: false)
            ]
        )

        let schema = MCPJSONSchema.build(from: definition)
        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        let requiredField = properties?["required_field"] as? [String: Any]
        let optionalField = properties?["optional_field"] as? [String: Any]

        XCTAssertEqual(requiredField?["type"] as? String, "string")
        XCTAssertEqual(optionalField?["type"] as? String, "integer")
        XCTAssertEqual(schema["required"] as? [String], ["required_field"])
    }
}
