# CashFlow AI Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add multi-provider AI (OpenAI, Anthropic, Ollama) to CashFlow with settings UI, financial health chat side panel, transaction automation, and dashboard insights.

**Architecture:** Provider protocol + `AIService` facade; API keys in Keychain; prefs in UserDefaults; chat in SwiftData. Feature services (`AIChatService`, `AICategorizeService`, `AIInsightsService`) build prompts/context and call `AIService`. UI uses existing design system (`CFSelectField`, `CFGlassCard`, `cfSheetBackground`).

**Tech Stack:** SwiftUI, SwiftData, Security.framework (Keychain), URLSession (REST), macOS 14+, no third-party AI SDKs.

**Spec:** `docs/superpowers/specs/2026-06-17-cashflow-ai-integration-design.md`

**Build command (after every task):**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme CashFlow -project CashFlow.xcodeproj -destination 'platform=macOS' build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

**Test command (after Task 1):**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme CashFlow -project CashFlow.xcodeproj -destination 'platform=macOS' test 2>&1 | tail -30
```
Expected: `** TEST SUCCEEDED **`

**Note:** Project uses `PBXFileSystemSynchronizedRootGroup` — new Swift files under `CashFlow/` auto-include. **Exception:** the `CashFlowTests` target must be added manually in Xcode (Task 1).

---

## File Map

| File | Responsibility |
|------|----------------|
| `AI/Core/AIProviderID.swift` | Provider enum + display metadata |
| `AI/Core/AIModel.swift` | Normalized model + message + request/response types |
| `AI/Core/AIError.swift` | Typed errors with PT-BR descriptions |
| `AI/Core/AIConfiguration.swift` | Read/write active provider, model, Ollama host/port |
| `AI/Core/AIService.swift` | Facade routing to active provider adapter |
| `AI/Core/AIContextBuilder.swift` | Build/truncate financial context for prompts |
| `AI/Networking/HTTPClient.swift` | URLSession wrapper + mockable protocol |
| `AI/Providers/OllamaProvider.swift` | Ollama REST adapter |
| `AI/Providers/OpenAIProvider.swift` | OpenAI REST adapter |
| `AI/Providers/AnthropicProvider.swift` | Anthropic REST adapter |
| `AI/Services/AIChatService.swift` | Chat threads, streaming, persistence |
| `AI/Services/AICategorizeService.swift` | NL parse + category suggestion |
| `AI/Services/AIInsightsService.swift` | Monthly insight generation + cache |
| `AI/Prompts/ChatPrompts.swift` | System/user prompt templates for chat |
| `AI/Prompts/CategorizePrompts.swift` | NL + categorization prompts |
| `AI/Prompts/InsightsPrompts.swift` | Dashboard insight prompt |
| `Persistence/SecureStore.swift` | Keychain get/set/delete for API keys |
| `Persistence/UserDefaultsKeys.swift` | Extended with `ai.*` keys |
| `Persistence/DataReset.swift` | Wipe AI prefs + Keychain on reset |
| `Models/ChatConversation.swift` | SwiftData conversation model |
| `Models/ChatMessage.swift` | SwiftData message model |
| `Features/AI/AISettingsView.swift` | Provider configuration screen |
| `Features/AI/AIChatSidePanel.swift` | Sliding chat overlay |
| `Features/AI/AIChatPanelState.swift` | Observable panel visibility + navigation |
| `App/RootSidebarView.swift` | Sidebar entry + global chat toolbar + overlay |
| `Features/Transactions/AddTransactionSheet.swift` | NL input + suggest category |
| `Features/Dashboard/MonthDashboardView.swift` | Insight card |
| `CashFlowApp.swift` | Register chat models in Schema |

---

## Phase 1 — Foundation & Settings

### Task 1: Test target + core AI types

**Files:**
- Create: `CashFlowTests/AIErrorTests.swift`
- Create: `CashFlow/AI/Core/AIProviderID.swift`
- Create: `CashFlow/AI/Core/AIModel.swift`
- Create: `CashFlow/AI/Core/AIError.swift`
- Modify: Xcode project (add `CashFlowTests` target manually)

- [ ] **Step 1: Add CashFlowTests target in Xcode**

1. File → New → Target → **Unit Testing Bundle**
2. Product name: `CashFlowTests`, target to test: `CashFlow`
3. Create `CashFlowTests/` group at repo root (sibling of `CashFlow/`)

- [ ] **Step 2: Write failing test for AIError**

`CashFlowTests/AIErrorTests.swift`:
```swift
import XCTest
@testable import CashFlow

final class AIErrorTests: XCTestCase {
    func testNoActiveProviderDescription() {
        let error = AIError.noActiveProvider
        XCTAssertEqual(error.errorDescription, "Nenhum provedor de IA está ativo. Configure em Inteligência.")
    }

    func testOllamaUnreachableDescription() {
        let error = AIError.networkUnavailable(host: "127.0.0.1", port: 11434)
        XCTAssertTrue(error.errorDescription?.contains("11434") == true)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme CashFlow -project CashFlow.xcodeproj -destination 'platform=macOS' test -only-testing:CashFlowTests/AIErrorTests 2>&1 | tail -15
```
Expected: FAIL — `AIError` not found

- [ ] **Step 4: Implement core types**

`CashFlow/AI/Core/AIProviderID.swift`:
```swift
import Foundation

enum AIProviderID: String, CaseIterable, Codable, Hashable {
    case openai
    case anthropic
    case ollama

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .ollama: return "Local (Ollama)"
        }
    }

    var symbolName: String {
        switch self {
        case .openai: return "brain.head.profile"
        case .anthropic: return "sparkles"
        case .ollama: return "server.rack"
        }
    }
}
```

`CashFlow/AI/Core/AIModel.swift`:
```swift
import Foundation

struct AIModel: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let contextWindow: Int?
}

enum AIMessageRole: String, Codable {
    case system, user, assistant
}

struct AIMessage: Hashable {
    let role: AIMessageRole
    let content: String
}

struct AICompletionRequest {
    let modelID: String
    let messages: [AIMessage]
    let temperature: Double
    let maxTokens: Int?

    init(modelID: String, messages: [AIMessage], temperature: Double = 0.4, maxTokens: Int? = nil) {
        self.modelID = modelID
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

struct AICompletionResponse {
    let content: String
}

struct AIStreamChunk {
    let content: String
    let isFinished: Bool
}
```

`CashFlow/AI/Core/AIError.swift`:
```swift
import Foundation

enum AIError: LocalizedError, Equatable {
    case noActiveProvider
    case notConfigured(AIProviderID)
    case invalidCredentials
    case networkUnavailable(host: String, port: Int)
    case modelNotFound(String)
    case providerError(String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .noActiveProvider:
            return "Nenhum provedor de IA está ativo. Configure em Inteligência."
        case .notConfigured(let id):
            return "\(id.displayName) não está configurado."
        case .invalidCredentials:
            return "Credenciais inválidas. Verifique sua chave de API."
        case .networkUnavailable(let host, let port):
            return "Não foi possível conectar em \(host):\(port). Verifique se o serviço está rodando."
        case .modelNotFound(let model):
            return "Modelo não encontrado: \(model)."
        case .providerError(let message):
            return message
        case .decodingFailed:
            return "Resposta inválida do provedor de IA."
        }
    }
}
```

- [ ] **Step 5: Run tests**

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add CashFlow/AI/Core CashFlowTests
git commit -m "feat(ai): add core AI types and error tests"
```

---

### Task 2: SecureStore + UserDefaults keys

**Files:**
- Create: `CashFlow/Persistence/SecureStore.swift`
- Modify: `CashFlow/Persistence/UserDefaultsKeys.swift`
- Create: `CashFlow/AI/Core/AIConfiguration.swift`
- Test: `CashFlowTests/AIConfigurationTests.swift`

- [ ] **Step 1: Write failing test for configuration defaults**

`CashFlowTests/AIConfigurationTests.swift`:
```swift
import XCTest
@testable import CashFlow

final class AIConfigurationTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.aiOllamaHost)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.aiOllamaPort)
        super.tearDown()
    }

    func testOllamaDefaults() {
        let config = AIConfiguration(defaults: .standard)
        XCTAssertEqual(config.ollamaHost, "127.0.0.1")
        XCTAssertEqual(config.ollamaPort, 11434)
    }
}
```

- [ ] **Step 2: Run test — expect FAIL**

- [ ] **Step 3: Implement SecureStore + keys + configuration**

`CashFlow/Persistence/UserDefaultsKeys.swift` — append:
```swift
    static let aiActiveProvider = "ai.activeProvider"
    static let aiActiveModelID = "ai.activeModelID"
    static let aiOllamaHost = "ai.ollamaHost"
    static let aiOllamaPort = "ai.ollamaPort"
    static func aiInsightCacheKey(monthKey: String) -> String { "ai.insight.\(monthKey)" }
```

`CashFlow/Persistence/SecureStore.swift`:
```swift
import Foundation
import Security

enum SecureStore {
  enum Key: String {
    case openAIAPIKey = "com.cashflow.ai.openai.apiKey"
    case anthropicAPIKey = "com.cashflow.ai.anthropic.apiKey"
  }

  static func save(_ value: String, for key: Key) throws {
    let data = Data(value.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key.rawValue,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
    ]
    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else { throw AIError.providerError("Falha ao salvar credencial (\(status)).") }
  }

  static func read(_ key: Key) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key.rawValue,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func delete(_ key: Key) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key.rawValue
    ]
    SecItemDelete(query as CFDictionary)
  }

  static func maskedValue(for key: Key) -> String? {
    guard let value = read(key), !value.isEmpty else { return nil }
    let suffix = String(value.suffix(4))
    return "••••••••" + suffix
  }
}
```

`CashFlow/AI/Core/AIConfiguration.swift`:
```swift
import Foundation

struct AIConfiguration {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var activeProvider: AIProviderID? {
        get {
            guard let raw = defaults.string(forKey: UserDefaultsKeys.aiActiveProvider) else { return nil }
            return AIProviderID(rawValue: raw)
        }
        set { defaults.set(newValue?.rawValue, forKey: UserDefaultsKeys.aiActiveProvider) }
    }

    var activeModelID: String? {
        get { defaults.string(forKey: UserDefaultsKeys.aiActiveModelID) }
        set { defaults.set(newValue, forKey: UserDefaultsKeys.aiActiveModelID) }
    }

    var ollamaHost: String {
        get { defaults.string(forKey: UserDefaultsKeys.aiOllamaHost) ?? "127.0.0.1" }
        set { defaults.set(newValue, forKey: UserDefaultsKeys.aiOllamaHost) }
    }

    var ollamaPort: Int {
        get {
            let value = defaults.integer(forKey: UserDefaultsKeys.aiOllamaPort)
            return value == 0 ? 11434 : value
        }
        set { defaults.set(newValue, forKey: UserDefaultsKeys.aiOllamaPort) }
    }

    var isReady: Bool {
        guard let provider = activeProvider, let model = activeModelID, !model.isEmpty else { return false }
        return isConfigured(provider)
    }

    func isConfigured(_ provider: AIProviderID) -> Bool {
        switch provider {
        case .openai: return SecureStore.read(.openAIAPIKey) != nil
        case .anthropic: return SecureStore.read(.anthropicAPIKey) != nil
        case .ollama: return !ollamaHost.isEmpty && ollamaPort > 0
        }
    }

    func ollamaBaseURL() -> URL? {
        URL(string: "http://\(ollamaHost):\(ollamaPort)")
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add CashFlow/Persistence/SecureStore.swift CashFlow/Persistence/UserDefaultsKeys.swift CashFlow/AI/Core/AIConfiguration.swift CashFlowTests/AIConfigurationTests.swift
git commit -m "feat(ai): add SecureStore and AIConfiguration"
```

---

### Task 3: HTTPClient + AIProvider protocol

**Files:**
- Create: `CashFlow/AI/Networking/HTTPClient.swift`
- Create: `CashFlow/AI/Core/AIProvider.swift`
- Test: `CashFlowTests/HTTPClientTests.swift`

- [ ] **Step 1: Write failing HTTPClient test with URLProtocol stub**

`CashFlowTests/HTTPClientTests.swift`:
```swift
import XCTest
@testable import CashFlow

final class MockURLProtocol: URLProtocol {
  static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    guard let handler = MockURLProtocol.handler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
    }
  do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }
  override func stopLoading() {}
}

final class HTTPClientTests: XCTestCase {
  func testGETDecodesJSON() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.httpMethod, "GET")
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, Data("{\"ok\":true}".utf8))
    }
    let client = HTTPClient(session: URLSession(configuration: config))
    struct Payload: Decodable { let ok: Bool }
    let result: Payload = try await client.get(Payload.self, url: URL(string: "http://test.local/tags")!)
    XCTAssertTrue(result.ok)
  }
}
```

- [ ] **Step 2: Run test — expect FAIL**

- [ ] **Step 3: Implement HTTPClient + protocol**

`CashFlow/AI/Networking/HTTPClient.swift`:
```swift
import Foundation

struct HTTPClient {
    let session: URLSession
    let defaultTimeout: TimeInterval

    init(session: URLSession = .shared, defaultTimeout: TimeInterval = 30) {
        self.session = session
        self.defaultTimeout = defaultTimeout
    }

    func get<T: Decodable>(_ type: T.Type, url: URL, headers: [String: String] = [:], timeout: TimeInterval? = nil) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: timeout ?? defaultTimeout)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func postJSON<Body: Encodable, Response: Decodable>(_ responseType: Response.Type, url: URL, body: Body, headers: [String: String] = [:], timeout: TimeInterval? = nil) async throws -> Response {
        var request = URLRequest(url: url, timeoutInterval: timeout ?? defaultTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    func postStream(url: URL, body: Data, headers: [String: String] = [:], timeout: TimeInterval? = nil) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: url, timeoutInterval: timeout ?? defaultTimeout)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
                    request.httpBody = body
                    let (bytes, response) = try await session.bytes(for: request)
                    try validate(response: response, data: nil)
                    for try await line in bytes.lines {
                        continuation.yield(Data(line.utf8))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func validate(response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else { throw AIError.providerError("Resposta inválida.") }
        guard (200...299).contains(http.statusCode) else {
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            if http.statusCode == 401 { throw AIError.invalidCredentials }
            throw AIError.providerError(body.isEmpty ? "HTTP \(http.statusCode)" : body)
        }
    }
}
```

`CashFlow/AI/Core/AIProvider.swift`:
```swift
import Foundation

protocol AIProvider {
    var id: AIProviderID { get }
    func validateConfiguration() async throws
    func listModels() async throws -> [AIModel]
    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse
    func stream(_ request: AICompletionRequest) -> AsyncThrowingStream<AIStreamChunk, Error>
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add CashFlow/AI/Networking CashFlow/AI/Core/AIProvider.swift CashFlowTests/HTTPClientTests.swift
git commit -m "feat(ai): add HTTPClient and AIProvider protocol"
```

---

### Task 4: Ollama provider

**Files:**
- Create: `CashFlow/AI/Providers/OllamaProvider.swift`
- Test: `CashFlowTests/OllamaProviderTests.swift`

- [ ] **Step 1: Write failing test for model listing**

`CashFlowTests/OllamaProviderTests.swift`:
```swift
import XCTest
@testable import CashFlow

final class OllamaProviderTests: XCTestCase {
  func testListModelsParsesTags() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    MockURLProtocol.handler = { _ in
      let response = HTTPURLResponse(url: URL(string: "http://127.0.0.1:11434/api/tags")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      let json = #"{"models":[{"name":"llama3.2","model":"llama3.2:latest"}]}"#
      return (response, Data(json.utf8))
    }
    var aiConfig = AIConfiguration(defaults: .standard)
    aiConfig.ollamaHost = "127.0.0.1"
    aiConfig.ollamaPort = 11434
    let provider = OllamaProvider(configuration: aiConfig, client: HTTPClient(session: URLSession(configuration: config)))
    let models = try await provider.listModels()
    XCTAssertEqual(models.first?.id, "llama3.2:latest")
  }
}
```

- [ ] **Step 2: Run test — expect FAIL**

- [ ] **Step 3: Implement OllamaProvider**

`CashFlow/AI/Providers/OllamaProvider.swift` — implement:
- `GET {base}/api/tags` → map `models[].model` to `AIModel`
- `POST {base}/api/chat` with `{ model, messages, stream: false }` for `complete`
- `POST {base}/api/chat` with `stream: true` — parse NDJSON lines `{"message":{"content":"..."},"done":false}`
- `validateConfiguration()` calls `listModels()` with 5s timeout
- On `URLError.cannotConnectToHost` throw `AIError.networkUnavailable(host:port:)`

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add CashFlow/AI/Providers/OllamaProvider.swift CashFlowTests/OllamaProviderTests.swift
git commit -m "feat(ai): add Ollama provider adapter"
```

---

### Task 5: OpenAI + Anthropic providers

**Files:**
- Create: `CashFlow/AI/Providers/OpenAIProvider.swift`
- Create: `CashFlow/AI/Providers/AnthropicProvider.swift`
- Test: `CashFlowTests/OpenAIProviderTests.swift`

- [ ] **Step 1: Write failing OpenAI models test**

Mock `GET https://api.openai.com/v1/models` returning `{ "data": [{ "id": "gpt-4o-mini" }] }`. Filter ids containing `gpt` or `o`.

- [ ] **Step 2: Implement OpenAIProvider**

- Auth header: `Authorization: Bearer {key}` from `SecureStore.read(.openAIAPIKey)`
- `POST /v1/chat/completions` — map `AIMessageRole` → OpenAI roles
- Stream: SSE lines prefixed `data: `, parse `choices[0].delta.content`

- [ ] **Step 3: Implement AnthropicProvider**

- Auth: `x-api-key` + `anthropic-version: 2023-06-01`
- `listModels()` returns curated list: `claude-sonnet-4-20250514`, `claude-3-5-haiku-20241022` (ids as `AIModel`)
- `POST /v1/messages` with `system` extracted from messages

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add CashFlow/AI/Providers CashFlowTests/OpenAIProviderTests.swift
git commit -m "feat(ai): add OpenAI and Anthropic provider adapters"
```

---

### Task 6: AIService facade

**Files:**
- Create: `CashFlow/AI/Core/AIService.swift`
- Test: `CashFlowTests/AIServiceTests.swift`

- [ ] **Step 1: Write failing test — no active provider throws**

```swift
func testCompleteWithoutProviderThrows() async {
    let config = AIConfiguration(defaults: UserDefaults(suiteName: "AIServiceTests")!)
    config.activeProvider = nil
    let service = AIService(configuration: config)
    do {
        _ = try await service.complete(messages: [AIMessage(role: .user, content: "oi")])
        XCTFail()
    } catch let error as AIError {
        XCTAssertEqual(error, .noActiveProvider)
    }
}
```

- [ ] **Step 2: Implement AIService**

`AIService` resolves provider from `activeProvider`, injects `activeModelID` into requests, exposes:
```swift
@MainActor
final class AIService: ObservableObject {
    let configuration: AIConfiguration
    func listModels(for provider: AIProviderID) async throws -> [AIModel]
    func complete(messages: [AIMessage], temperature: Double = 0.4, maxTokens: Int? = nil) async throws -> String
    func stream(messages: [AIMessage]) -> AsyncThrowingStream<AIStreamChunk, Error>
    private func makeProvider(_ id: AIProviderID) throws -> AIProvider
}
```

Register as `@StateObject` or environment object in `CashFlowApp`.

- [ ] **Step 3: Run tests — expect PASS**

- [ ] **Step 4: Commit**

```bash
git add CashFlow/AI/Core/AIService.swift CashFlowTests/AIServiceTests.swift CashFlow/CashFlowApp.swift
git commit -m "feat(ai): add AIService facade"
```

---

### Task 7: AI Settings UI + sidebar

**Files:**
- Create: `CashFlow/Features/AI/AISettingsView.swift`
- Modify: `CashFlow/App/RootSidebarView.swift`
- Modify: `CashFlow/CashFlowApp.swift`
- Modify: `CashFlow/Persistence/DataReset.swift`

- [ ] **Step 1: Add sidebar destination**

`RootSidebarView.swift`:
```swift
enum SidebarDestination: Hashable {
    case dashboard, transactions, categories, accounts, intelligence
}
```
Add section:
```swift
Section("Inteligência") {
    Label("Inteligência", systemImage: "sparkles")
        .tag(SidebarDestination.intelligence)
}
```
Detail case: `AISettingsView()`

Inject `@EnvironmentObject var aiService: AIService` from `CashFlowApp`:
```swift
RootSidebarView()
    .environmentObject(aiService)
```

- [ ] **Step 2: Build AISettingsView**

Layout using existing design system:
- Three `CFGlassCard` provider sections (OpenAI key field + Salvar/Testar, Anthropic same, Ollama host/port fields)
- Active provider `CFSelectField` — options only for configured providers
- Model `CFSelectField` populated after successful test
- Status text inline (Connected / error message)
- On Test: `listModels(for:)`, cache in `@State private var cachedModels: [AIProviderID: [AIModel]]`

API key field: `SecureField` when editing; show `SecureStore.maskedValue` + "Substituir"/"Remover" when saved.

- [ ] **Step 3: Extend DataReset**

In `wipeStoreIfNeeded()` also:
```swift
defaults.removeObject(forKey: UserDefaultsKeys.aiActiveProvider)
defaults.removeObject(forKey: UserDefaultsKeys.aiActiveModelID)
defaults.removeObject(forKey: UserDefaultsKeys.aiOllamaHost)
defaults.removeObject(forKey: UserDefaultsKeys.aiOllamaPort)
SecureStore.delete(.openAIAPIKey)
SecureStore.delete(.anthropicAPIKey)
```

- [ ] **Step 4: Build + manual QA**

1. Open Inteligência → enter Ollama host/port → Testar
2. Select provider + model → relaunch app → settings persist
3. Save OpenAI key → masked display

- [ ] **Step 5: Commit**

```bash
git add CashFlow/Features/AI CashFlow/App/RootSidebarView.swift CashFlow/CashFlowApp.swift CashFlow/Persistence/DataReset.swift
git commit -m "feat(ai): add Inteligência settings screen"
```

---

## Phase 2 — Financial Health Chat

### Task 8: Chat SwiftData models

**Files:**
- Create: `CashFlow/Models/ChatConversation.swift`
- Create: `CashFlow/Models/ChatMessage.swift`
- Modify: `CashFlow/CashFlowApp.swift`

- [ ] **Step 1: Add models**

`ChatConversation`:
```swift
@Model final class ChatConversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.conversation)
    var messages: [ChatMessage] = []
}
```

`ChatMessage`:
```swift
@Model final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var roleRaw: String
    var content: String
    var createdAt: Date
    var conversation: ChatConversation?
    var role: AIMessageRole { get/set via roleRaw }
}
```

- [ ] **Step 2: Register in Schema + bump DataReset wipe token**

Add `ChatConversation.self`, `ChatMessage.self` to `Schema([...])`.
Bump `DataReset.wipeToken` to `fresh_start_2026_06_17_ai`.

- [ ] **Step 3: Build — expect SUCCESS**

- [ ] **Step 4: Commit**

```bash
git add CashFlow/Models/ChatConversation.swift CashFlow/Models/ChatMessage.swift CashFlow/CashFlowApp.swift CashFlow/Persistence/DataReset.swift
git commit -m "feat(ai): add chat SwiftData models"
```

---

### Task 9: AIContextBuilder + ChatPrompts

**Files:**
- Create: `CashFlow/AI/Prompts/ChatPrompts.swift`
- Create: `CashFlow/AI/Core/AIContextBuilder.swift`
- Test: `CashFlowTests/AIContextBuilderTests.swift`

- [ ] **Step 1: Write failing truncation test**

Given 200 fake transactions, `AIContextBuilder.financialSnapshot(...)` output must prioritize last 30 days and include budget summary under 12_000 characters.

- [ ] **Step 2: Implement ChatPrompts**

```swift
enum ChatPrompts {
    static let system = """
    Você é o assistente de saúde financeira do CashFlow. Analise padrões de gastos, ritmo vs orçamento e hábitos. \
    Seja objetivo e prático em português do Brasil. Não dê conselhos de investimento regulados.
    """
    static func userMessage(question: String, context: String) -> String {
        "Contexto financeiro:\n\(context)\n\nPergunta do usuário:\n\(question)"
    }
}
```

- [ ] **Step 3: Implement AIContextBuilder**

Input: `[Transaction]`, `[Account]`, `monthlyIncomeCents`, `referenceDate`.
Output markdown/JSON block with: account balances, budget, pace, transactions (truncate oldest beyond char budget).

- [ ] **Step 4: Run tests — PASS**

- [ ] **Step 5: Commit**

---

### Task 10: AIChatService

**Files:**
- Create: `CashFlow/AI/Services/AIChatService.swift`

- [ ] **Step 1: Implement service**

Methods:
```swift
@MainActor
final class AIChatService {
    func createConversation() -> ChatConversation
    func deleteConversation(_ conversation: ChatConversation)
    func deleteAllConversations()
    func sendMessage(_ text: String, in conversation: ChatConversation, context: ModelContext) async throws
}
```

`sendMessage`:
1. Insert user `ChatMessage`
2. Build messages array: system + last 20 messages + new user with context
3. Stream via `aiService.stream`
4. Append assistant message updating content as chunks arrive
5. Auto-title from first user message if title == "Nova conversa"

- [ ] **Step 2: Manual test with Ollama/local provider**

- [ ] **Step 3: Commit**

```bash
git add CashFlow/AI/Services/AIChatService.swift
git commit -m "feat(ai): add AIChatService with streaming"
```

---

### Task 11: Chat side panel + global toolbar

**Files:**
- Create: `CashFlow/Features/AI/AIChatPanelState.swift`
- Create: `CashFlow/Features/AI/AIChatSidePanel.swift`
- Modify: `CashFlow/App/RootSidebarView.swift`

- [ ] **Step 1: AIChatPanelState**

```swift
@MainActor
final class AIChatPanelState: ObservableObject {
    @Published var isOpen = false
    func toggle() { isOpen.toggle() }
    func close() { isOpen = false }
}
```

Inject via `.environmentObject` from `CashFlowApp`.

- [ ] **Step 2: Build AIChatSidePanel**

- Width 380, trailing slide with `CFMotion.snappy`
- Header: "Saúde financeira" + close button
- Conversation `CFSelectFieldOptional` + "Nova" button
- `ScrollView` message bubbles (user right/assistant left)
- Input `TextField` multiline + send button
- Footer: "Apagar todas as conversas" with `.alert`
- Empty state when `!aiService.configuration.isReady` → button navigates to `.intelligence`

- [ ] **Step 3: RootSidebarView overlay**

Wrap detail in `ZStack(alignment: .trailing)`:
```swift
detailView
if chatPanelState.isOpen {
    AIChatSidePanel()
        .transition(.move(edge: .trailing))
}
```
Add toolbar to detail:
```swift
.toolbar {
  ToolbarItem(placement: .primaryAction) {
    Button { chatPanelState.toggle() } label: {
      Label("Saúde financeira", systemImage: "sparkles")
    }
  }
}
```
Apply toolbar on each root detail view OR use a wrapper `DetailContainer` — prefer single wrapper in `RootSidebarView` around `detailView`.

Keyboard: `.onExitCommand { chatPanelState.close() }` on panel.

- [ ] **Step 4: Manual QA checklist**

- [ ] Panel opens from all 4 screens
- [ ] Streaming works
- [ ] Conversations persist across relaunch
- [ ] Delete one / delete all works

- [ ] **Step 5: Commit**

```bash
git add CashFlow/Features/AI CashFlow/App/RootSidebarView.swift CashFlow/CashFlowApp.swift
git commit -m "feat(ai): add financial health chat side panel"
```

---

## Phase 3 — Transaction Automation

### Task 12: AICategorizeService

**Files:**
- Create: `CashFlow/AI/Prompts/CategorizePrompts.swift`
- Create: `CashFlow/AI/Services/AICategorizeService.swift`
- Create: `CashFlow/AI/Core/AIParsedTransaction.swift`
- Test: `CashFlowTests/AICategorizeServiceTests.swift`

- [ ] **Step 1: Write failing JSON parse test**

```swift
func testParsesCategorySuggestionJSON() throws {
    let json = #"{"categoryId":"ABC","confidence":0.91}"#
    let result = try AICategorizeService.parseCategorySuggestion(json)
    XCTAssertEqual(result.categoryId, "ABC")
    XCTAssertEqual(result.confidence, 0.91, accuracy: 0.001)
}
```

- [ ] **Step 2: Implement AIParsedTransaction + service**

```swift
struct AIParsedTransaction: Equatable {
    var amount: Decimal?
    var kind: TransactionKind?
    var categoryName: String?
    var accountName: String?
    var date: Date?
    var note: String?
}

struct AICategorySuggestion: Equatable {
    let categoryId: String
    let confidence: Double
}
```

`parseTransaction(text:)` → prompt model for JSON fields.
`suggestCategory(amount:kind:note:categories:)` → prompt with category id+name list, parse `AICategorySuggestion`.

Strip markdown fences from model output before `JSONDecoder`.

- [ ] **Step 3: Run tests — PASS**

- [ ] **Step 4: Commit**

---

### Task 13: AddTransactionSheet AI integration

**Files:**
- Modify: `CashFlow/Features/Transactions/AddTransactionSheet.swift`

- [ ] **Step 1: Add NL input row below header**

```swift
HStack(spacing: 8) {
    TextField("Ex: gastei 45 no mercado ontem", text: $naturalLanguageInput)
        .textFieldStyle(.plain)
        .font(CFTheme.body())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .cfFieldChrome(isFocused: $nlFocused)
    Button { Task { await applyNaturalLanguage() } } label: {
        Image(systemName: "wand.and.stars")
    }
    .buttonStyle(.plain)
    .disabled(naturalLanguageInput.trimmingCharacters(in: .whitespaces).isEmpty || isParsingNL)
}
```

`applyNaturalLanguage()` calls `AICategorizeService.parseTransaction`, maps category/account by case-insensitive name match, sets `draft` fields.

- [ ] **Step 2: Add "Sugerir categoria" chip**

Show when `draft.category == nil && draft.amount > 0`. On tap, call `suggestCategory`. If `confidence >= 0.8`, auto-select; else show `CFPillButton` "Usar {category.name}".

- [ ] **Step 3: Disabled state when AI not configured**

Hide wand button / show help text linking to Inteligência.

- [ ] **Step 4: Manual QA**

- [ ] "gastei 32 no mercado ontem" fills amount, expense, category Mercado, date yesterday
- [ ] Suggest category works with note "Uber trabalho"

- [ ] **Step 5: Commit**

```bash
git add CashFlow/Features/Transactions/AddTransactionSheet.swift
git commit -m "feat(ai): add NL entry and category suggestion to transaction sheet"
```

---

## Phase 4 — Dashboard Insights

### Task 14: AIInsightsService + insight card

**Files:**
- Create: `CashFlow/AI/Prompts/InsightsPrompts.swift`
- Create: `CashFlow/AI/Services/AIInsightsService.swift`
- Modify: `CashFlow/Features/Dashboard/MonthDashboardView.swift`

- [ ] **Step 1: Implement AIInsightsService**

```swift
@MainActor
final class AIInsightsService {
    func cachedInsight(monthKey: String) -> String?
    func generateInsight(summary: MonthSummary, transactions: [Transaction], previousMonthExpense: Decimal) async throws -> String
}
```

Cache via `UserDefaultsKeys.aiInsightCacheKey(monthKey:)` where `monthKey = "yyyy-MM"`.

Prompt includes: totals, category breakdown, pace, previous month comparison numbers.

- [ ] **Step 2: Add card to MonthDashboardView**

`CFGlassCard` titled **Resumo inteligente**:
- If `!aiService.configuration.isReady` → setup CTA
- Else if no cache → `CFPillButton("Gerar resumo")`
- Else → bullet list (split by `\n- `) + timestamp + "Atualizar"
- Loading state + error retry

- [ ] **Step 3: Manual QA**

- [ ] Generate insight for current month
- [ ] Navigate away and back — cached text shows
- [ ] "Atualizar" replaces cache

- [ ] **Step 4: Commit**

```bash
git add CashFlow/AI/Services/AIInsightsService.swift CashFlow/AI/Prompts/InsightsPrompts.swift CashFlow/Features/Dashboard/MonthDashboardView.swift
git commit -m "feat(ai): add intelligent monthly insight card"
```

---

## Final verification

- [ ] **Run full test suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme CashFlow -project CashFlow.xcodeproj -destination 'platform=macOS' test 2>&1 | tail -30
```

- [ ] **Manual end-to-end checklist**

| # | Check |
|---|-------|
| 1 | Configure Ollama → test → select model |
| 2 | Configure OpenAI key → test → switch active provider |
| 3 | Chat panel streams response with financial context |
| 4 | Delete single conversation + delete all |
| 5 | NL transaction entry populates draft |
| 6 | Category suggestion accepts/rejects |
| 7 | Dashboard insight generates + caches |
| 8 | DataReset clears AI keys and prefs |

- [ ] **Final commit if any loose ends**

```bash
git commit -m "chore(ai): complete integration verification" --allow-empty
```

---

## Spec coverage checklist

| Spec section | Task |
|--------------|------|
| AI Settings + Keychain | 2, 7 |
| Provider adapters | 4, 5 |
| AIService facade | 6 |
| Chat side panel | 11 |
| Chat persistence | 8, 10 |
| Context + prompts | 9 |
| NL entry + categorization | 12, 13 |
| Dashboard insights | 14 |
| DataReset wipe | 7, 8 |
| Accessibility (Escape closes panel) | 11 |
| Streaming | 4, 5, 10 |

All spec requirements mapped. No TBDs.
