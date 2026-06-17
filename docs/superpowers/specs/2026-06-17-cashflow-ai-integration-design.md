# CashFlow — Integração com IA

**Date:** 2026-06-17  
**Status:** Draft for review

## Overview

Add AI capabilities to CashFlow (macOS, SwiftUI + SwiftData) with support for three provider types: **OpenAI**, **Anthropic**, and **Local (Ollama)**. Users may save credentials for multiple providers but activate **one provider + one model** globally for all AI features.

### Features in scope

1. **AI Settings** — configure providers, test connection, discover models, select active provider/model
2. **Financial health chat** — sliding side panel accessible from any screen; persisted conversation history with per-thread and bulk delete
3. **Transaction automation** — natural-language entry and automatic category suggestion
4. **Dashboard insights** — on-demand AI-generated monthly summary and spending analysis

### Out of scope (v1)

- Generic open-ended assistant unrelated to personal finance
- Per-feature provider/model overrides
- Configurable privacy tiers (user chose full transaction data for cloud)
- iOS target (macOS only for now)
- AI-powered budget recommendations with regulatory investment advice

---

## Requirements summary

| Decision | Choice |
|----------|--------|
| Cloud data sent | Full transaction records when needed (description, amount, category, account, date, note) |
| Active provider | One global provider + model at a time; multiple providers may be configured |
| Chat history | Persisted locally; delete individual conversations or clear all |
| Chat UI | Sliding side panel overlay from any detail screen |
| Providers (v1) | OpenAI, Anthropic, Ollama |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  UI Layer                                               │
│  ├─ AISettingsView (sidebar: "Inteligência")            │
│  ├─ AIChatSidePanel (global overlay)                    │
│  ├─ AddTransactionSheet (+ NL input, auto-categorize)   │
│  └─ MonthDashboardView (+ insight cards)                │
├─────────────────────────────────────────────────────────┤
│  Feature Services                                       │
│  ├─ AIChatService        (threads, context, prompts)    │
│  ├─ AICategorizeService  (suggest category from text)   │
│  └─ AIInsightsService    (monthly summary generation)   │
├─────────────────────────────────────────────────────────┤
│  AIService (facade)                                     │
│  └─ resolve active provider + model, route requests     │
├─────────────────────────────────────────────────────────┤
│  AIProvider protocol                                    │
│  ├─ OpenAIProvider                                      │
│  ├─ AnthropicProvider                                   │
│  └─ OllamaProvider                                      │
├─────────────────────────────────────────────────────────┤
│  Persistence                                            │
│  ├─ Keychain → API keys (OpenAI, Anthropic)             │
│  ├─ UserDefaults → active provider, model, Ollama host  │
│  └─ SwiftData → ChatConversation, ChatMessage           │
└─────────────────────────────────────────────────────────┘
```

### Core rules

- All AI features go through `AIService`; UI never calls provider APIs directly.
- If no active provider + model is configured, AI features show a disabled/empty state with CTA to **Inteligência** settings.
- Provider adapters are stateless; configuration is injected per request from `AIConfiguration`.

### Delivery phases

| Phase | Scope |
|-------|--------|
| **1** | AI settings screen, provider adapters, Keychain storage, connection test, model discovery |
| **2** | Financial health chat side panel, SwiftData persistence, conversation management |
| **3** | Transaction NL entry + auto-categorization |
| **4** | Dashboard insight cards (on-demand generation) |

---

## Configuration & secure storage

### Sidebar entry

New destination: **Inteligência** (`sparkles` icon) → `AISettingsView`.

### Settings layout

Three provider cards + active selection block:

| Card | Fields | Storage |
|------|--------|---------|
| OpenAI | API key (masked), Test button | Keychain |
| Anthropic | API key (masked), Test button | Keychain |
| Local (Ollama) | Host, Port, Test button | UserDefaults |

**Active provider block:**
- `CFSelectField` — OpenAI / Anthropic / Local (only enabled if connected)
- `CFSelectField` — model list from last successful `listModels()` call
- Status badge: Connected / Error / Not configured

### API key UX

- Save to Keychain on explicit save or field commit
- When saved: show masked value (`••••••••sk-abc1`) with Replace / Remove actions
- Never log keys; never store in UserDefaults or SwiftData

### Keychain keys

```
com.cashflow.ai.openai.apiKey
com.cashflow.ai.anthropic.apiKey
```

### UserDefaults keys (`UserDefaultsKeys`)

```
ai.activeProvider    → "openai" | "anthropic" | "ollama"
ai.activeModelID     → String
ai.ollamaHost        → default "127.0.0.1"
ai.ollamaPort        → default 11434
```

### Connection test flow

1. Validate credentials / host+port
2. Call adapter `listModels()`
3. Cache model list in memory (with timestamp)
4. Show inline success or human-readable error (e.g. "Ollama não está rodando em 127.0.0.1:11434")

### Data reset

`DataReset` wipes AI UserDefaults keys and deletes Keychain entries for AI API keys.

---

## Provider adapters

### Protocol

```swift
protocol AIProvider {
    var id: AIProviderID { get }
    func validateConfiguration() async throws
    func listModels() async throws -> [AIModel]
    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse
    func stream(_ request: AICompletionRequest) -> AsyncThrowingStream<AIStreamChunk, Error>
}
```

### Provider specifics

| Provider | Model discovery | Chat endpoint |
|----------|-----------------|---------------|
| Ollama | `GET /api/tags` | `POST /api/chat` (SSE stream) |
| OpenAI | `GET /v1/models` (filter chat-capable) | `POST /v1/chat/completions` |
| Anthropic | Curated list + API where available | `POST /v1/messages` |

### Ollama defaults

- Base URL built from host + port (default `http://127.0.0.1:11434`)
- 5s timeout on connection test
- Clear error when daemon is unreachable

### Normalized types

```swift
struct AIModel: Identifiable, Hashable {
    let id: String
    let displayName: String
    let contextWindow: Int?
}

struct AIMessage {
    enum Role { case system, user, assistant }
    let role: Role
    let content: String
}
```

### Error types

```swift
enum AIError: LocalizedError {
    case noActiveProvider
    case notConfigured(AIProviderID)
    case invalidCredentials
    case networkUnavailable
    case modelNotFound(String)
    case providerError(String)
}
```

All errors surface user-facing Portuguese messages in UI.

---

## Financial health chat (side panel)

### Access

Toolbar button on all detail views (dashboard, transactions, categories, accounts). Opens a **trailing slide-over panel** (~380px wide) without changing sidebar selection. Panel state managed at `RootSidebarView` level via `@State` or environment object.

### Panel structure

```
┌─────────────────────────┐
│ Saúde financeira    [×] │
├─────────────────────────┤
│ [Conversas ▾]  [+ Nova] │
├─────────────────────────┤
│   Message list (scroll) │
├─────────────────────────┤
│ [Multiline input]  [➤]  │
└─────────────────────────┘
```

### SwiftData models

```swift
@Model final class ChatConversation {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var messages: [ChatMessage]
}

@Model final class ChatMessage {
    var id: UUID
    var roleRaw: String   // "user" | "assistant" | "system"
    var content: String
    var createdAt: Date
    var conversation: ChatConversation?
}
```

- Auto-title from first user message (truncated to ~40 chars)
- Conversation picker via `CFSelectFieldOptional`
- Context menu: rename, delete conversation
- Footer action: "Apagar todas as conversas" with confirmation alert

### Context sent to model

**System prompt (fixed):** CashFlow financial health assistant. Objective tone, focuses on spending patterns, budget pacing, and actionable habits. Does not provide regulated investment advice.

**User message context (appended as structured JSON or markdown block):**
- Reference month (current dashboard month or today)
- All transactions in last 90 days: amount, category name, account name, date, note
- Per-account balances
- Monthly budget (`monthlyIncomeCents`) and pace state if set
- Current conversation history (trimmed to fit model context window)

### Streaming

Responses stream token-by-token into the assistant bubble. Show typing indicator while waiting for first chunk.

### Empty states

- No AI configured → CTA button to open Inteligência settings
- No conversations → prompt to start first chat

---

## Transaction automation

### Natural-language entry

In `AddTransactionSheet`, add a secondary input above or beside the amount header:

- Placeholder: *"Ex: gastei 45 no mercado ontem"*
- On submit (Return or wand button): `AICategorizeService.parseTransaction(text:)` returns structured draft:
  ```swift
  struct AIParsedTransaction {
      var amount: Decimal?
      var kind: TransactionKind?      // income | expense
      var categoryName: String?
      var accountName: String?
      var date: Date?
      var note: String?
  }
  ```
- Apply parsed fields to `TransactionDraft`; user reviews before saving
- Fuzzy-match category/account names against existing records; show picker if ambiguous

### Auto-categorization

When user fills amount + note (or description) but no category:

- "Sugerir categoria" chip/button appears
- `AICategorizeService.suggestCategory(for:)` sends transaction context + list of user's categories (names + kinds) to model
- Returns best-match category ID + confidence; auto-select if high confidence, otherwise show suggestion pill user can tap to accept

### Prompt constraints

- Model must pick from existing category list only (no inventing categories in v1)
- Response format: JSON `{ "categoryId": "...", "confidence": 0.0–1.0 }` with fallback parsing

---

## Dashboard insights

### UI

New card on `MonthDashboardView`: **Resumo inteligente**

- Default: placeholder with "Gerar resumo" button
- After generation: 2–4 bullet insights + optional one-line recommendation
- "Atualizar" to regenerate; show last-generated timestamp
- Cached in UserDefaults keyed by month (`ai.insight.{yyyy-MM}`) to avoid re-fetching on every visit

### Content

`AIInsightsService.generateMonthlyInsight(referenceDate:)` sends:
- Current month transactions (full detail)
- Category breakdown totals
- Budget vs spent ratio and pace state
- Comparison hint vs previous month totals (computed locally, sent as numbers)

Output: short Portuguese prose, 150–300 words max, bullet-friendly structure.

### Empty/error states

- No AI configured → card hidden or shows setup CTA
- Generation failed → inline error with retry

---

## Cross-cutting concerns

### Networking

- New `AI/Networking` folder with shared `HTTPClient` (URLSession wrapper)
- All requests async/await; cancel on view disappear for streaming
- No third-party SDKs in v1 (raw REST)

### Prompt management

- Prompts live in `AI/Prompts/*.swift` as static templates with injection points
- Version prompts with constants for easy iteration

### Context window management

- `AIContextBuilder` truncates transaction lists oldest-first when approaching limit
- Always preserve: totals, budget summary, most recent 30 days of transactions

### Security

- API keys: Keychain only, kSecAttrAccessibleWhenUnlocked
- No analytics/logging of message content
- Chat data stays local in SwiftData (never synced to cloud except via chosen provider API call)

### Accessibility

- Side panel keyboard-dismissible (Escape)
- Streaming messages announced via accessibility label updates (summary, not every token)

---

## File structure (proposed)

```
CashFlow/
├── AI/
│   ├── Core/
│   │   ├── AIService.swift
│   │   ├── AIConfiguration.swift
│   │   ├── AIProvider.swift
│   │   ├── AIModel.swift
│   │   ├── AIError.swift
│   │   └── AIContextBuilder.swift
│   ├── Providers/
│   │   ├── OpenAIProvider.swift
│   │   ├── AnthropicProvider.swift
│   │   └── OllamaProvider.swift
│   ├── Services/
│   │   ├── AIChatService.swift
│   │   ├── AICategorizeService.swift
│   │   └── AIInsightsService.swift
│   ├── Prompts/
│   │   ├── ChatPrompts.swift
│   │   ├── CategorizePrompts.swift
│   │   └── InsightsPrompts.swift
│   └── Networking/
│       └── HTTPClient.swift
├── Features/
│   ├── AI/
│   │   ├── AISettingsView.swift
│   │   └── AIChatSidePanel.swift
│   └── … (existing feature integrations)
├── Models/
│   ├── ChatConversation.swift
│   └── ChatMessage.swift
└── Persistence/
    ├── SecureStore.swift
    └── UserDefaultsKeys.swift (extended)
```

---

## Testing strategy

| Layer | Approach |
|-------|----------|
| Provider adapters | Unit tests with mocked URLSession responses (JSON fixtures per provider) |
| AIService | Test provider resolution, error mapping, config gating |
| Context builder | Test truncation logic with large transaction sets |
| Feature services | Test JSON parsing for categorization responses |
| UI | Manual QA checklist per phase; no snapshot tests in v1 |

---

## Open questions (resolved)

All brainstorming decisions captured in Requirements summary above. No open TBDs for v1 implementation.
