# Lista de desejos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a wishlist of discretionary purchases with UI, purchase-to-transaction flow, and Gio integration (chat tools + proactive dashboard suggestions).

**Architecture:** New SwiftData `WishlistItem` domain separate from `FinancialGoal`. `WishlistPurchaseRecorder` centralizes purchase logic for UI and AI tools. `WishlistSortOrder` provides testable list ordering. Gio reads/writes via `AIToolReaders`/`AIToolWriters`; dashboard panel uses cached monthly suggestions like `DashboardInsightPanel`.

**Tech Stack:** SwiftUI, SwiftData, existing AI tool stack (`AIToolCatalog`, `AIAgentLoop`), macOS 26.5+, iOS 17+, iPadOS 17+.

## Global Constraints

- UI copy in **português do Brasil**
- Reuse design system: `CFTheme`, `CFPanel`, `CFEmptyState`, `cfPageBackground()`, `cfSheetBackground()`, `CFAmountHeader`, `CFSelectFieldOptional`, `cfAdaptiveSheetNavigation()`
- Multiplatform: sidebar on regular/macOS; `AdaptiveRootView` compact lists must include new destination
- Build after every task: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme CashFlow -project CashFlow.xcodeproj -destination 'platform=macOS' build`
- iOS build when touching navigation/UI: `-destination 'generic/platform=iOS Simulator' build`
- Test after logic tasks: `xcodebuild ... test`
- `CashFlow/` uses `PBXFileSystemSynchronizedRootGroup` — new Swift files auto-include; test files go in `CashFlowTests/`

**Spec:** `docs/superpowers/specs/2026-06-17-lista-desejos-design.md`

---

## File Map

| File | Responsibility |
|------|----------------|
| `Models/WishlistItem.swift` | SwiftData model + `WishlistPriority` enum |
| `Models/WishlistSortOrder.swift` | Sort comparator for list UI |
| `Models/WishlistPurchaseRecorder.swift` | Create expense transaction + delete item |
| `Features/Wishlist/WishlistListView.swift` | Main list screen |
| `Features/Wishlist/AddWishlistItemSheet.swift` | Create/edit sheet |
| `Features/Wishlist/PurchaseWishlistItemSheet.swift` | "Comprei" confirmation sheet |
| `Features/Dashboard/DashboardWishlistPanel.swift` | Dashboard total + Gio suggestions |
| `AI/Services/AIWishlistInsightService.swift` | Generate + cache wishlist insight bullets |
| `AI/Tools/AIToolCatalog.swift` | 5 new tool definitions |
| `AI/Tools/AIToolReaders.swift` | `list_wishlist` |
| `AI/Tools/AIToolWriters.swift` | create/update/delete/purchase |
| `AI/Tools/AIToolResolver.swift` | `wishlistItem(in:id:name:)` |
| `AI/Tools/AIToolFormatters.swift` | JSON helper for wishlist items |
| `AI/Tools/AIToolContext.swift` | Add `wishlistItems` field |
| `AI/Tools/AIToolInsightContext.swift` | Include wishlist section |
| `AI/Prompts/ChatPrompts.swift` | Wishlist tool guidance |
| `AI/Agent/AIAgentLoop.swift` | Write nudge string update |
| `App/SidebarNavigation.swift` | `.wishlist` destination |
| `App/RootSidebarView.swift` | Sidebar row after Metas |
| `App/AdaptiveRootView.swift` | Compact overview row |
| `Persistence/ModelContainerFactory.swift` | Register `WishlistItem` |
| `Persistence/UserDefaultsKeys.swift` | Wishlist insight cache keys |
| `Preview/PreviewSupport.swift` | Seed sample wishlist items |
| `CashFlowTests/WishlistSortOrderTests.swift` | Sort tests |
| `CashFlowTests/WishlistPurchaseRecorderTests.swift` | Purchase tests |
| `CashFlowTests/AIToolReadersTests.swift` | `list_wishlist` test |
| `CashFlowTests/AIToolWritersTests.swift` | `purchase_wishlist_item` test |

---

## Task 1: Model, sort order, and container registration

**Files:**
- Create: `CashFlow/Models/WishlistItem.swift`
- Create: `CashFlow/Models/WishlistSortOrder.swift`
- Create: `CashFlowTests/WishlistSortOrderTests.swift`
- Modify: `CashFlow/Persistence/ModelContainerFactory.swift`
- Modify: `CashFlow/Preview/PreviewSupport.swift` (schema + optional seed)

**Interfaces:**
- Produces: `WishlistItem`, `WishlistPriority`, `WishlistSortOrder.sorted(_:)`

- [ ] **Step 1: Write failing sort test**

`CashFlowTests/WishlistSortOrderTests.swift`:

```swift
import XCTest
import SwiftData
@testable import CashFlow

@MainActor
final class WishlistSortOrderTests: XCTestCase {
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = ModelContainerFactory.make(inMemory: true).mainContext
    }

    func testSortsByPriorityThenDesiredBy() throws {
        let cal = Calendar.current
        let soon = cal.date(byAdding: .day, value: 3, to: .now)!
        let later = cal.date(byAdding: .day, value: 30, to: .now)!

        let low = WishlistItem(name: "Calça", estimatedAmount: 200, priority: .low)
        let urgentSoon = WishlistItem(name: "Fone", estimatedAmount: 800, priority: .urgent, desiredBy: soon)
        let urgentLater = WishlistItem(name: "Cadeira", estimatedAmount: 1200, priority: .urgent, desiredBy: later)
        let highNoDate = WishlistItem(name: "Mouse", estimatedAmount: 300, priority: .high)

        context.insert(low)
        context.insert(urgentSoon)
        context.insert(urgentLater)
        context.insert(highNoDate)

        let sorted = WishlistSortOrder.sorted([low, urgentSoon, urgentLater, highNoDate])

        XCTAssertEqual(sorted.map(\.name), ["Fone", "Cadeira", "Mouse", "Calça"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/lukearch/Projects/My/CashFlow
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
 xcodebuild -scheme CashFlow -project CashFlow.xcodeproj \
 -destination 'platform=macOS' test \
 -only-testing:CashFlowTests/WishlistSortOrderTests 2>&1 | tail -20
```

Expected: FAIL — `WishlistSortOrder` not found

- [ ] **Step 3: Implement model and sort**

`CashFlow/Models/WishlistItem.swift`:

```swift
import Foundation
import SwiftData

enum WishlistPriority: String, Codable, CaseIterable, Identifiable {
    case low, medium, high, urgent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Baixa"
        case .medium: return "Média"
        case .high: return "Alta"
        case .urgent: return "Urgente"
        }
    }

    var sortRank: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

@Model
final class WishlistItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var estimatedAmount: Decimal
    var priorityRaw: String
    var note: String
    var desiredBy: Date?
    var createdAt: Date

    var category: Category?

    var priority: WishlistPriority {
        get { WishlistPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        estimatedAmount: Decimal,
        priority: WishlistPriority = .medium,
        note: String = "",
        desiredBy: Date? = nil,
        createdAt: Date = .now,
        category: Category? = nil
    ) {
        self.id = id
        self.name = name
        self.estimatedAmount = estimatedAmount
        self.priorityRaw = priority.rawValue
        self.note = note
        self.desiredBy = desiredBy
        self.createdAt = createdAt
        self.category = category
    }
}
```

`CashFlow/Models/WishlistSortOrder.swift`:

```swift
import Foundation

enum WishlistSortOrder {
    static func sorted(_ items: [WishlistItem]) -> [WishlistItem] {
        items.sorted { lhs, rhs in
            if lhs.priority.sortRank != rhs.priority.sortRank {
                return lhs.priority.sortRank < rhs.priority.sortRank
            }
            switch (lhs.desiredBy, rhs.desiredBy) {
            case let (l?, r?): return l < r
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return lhs.createdAt > rhs.createdAt
            }
        }
    }
}
```

- [ ] **Step 4: Register in container**

In `ModelContainerFactory.swift`, add `WishlistItem.self` to the `schema` array (after `FinancialGoal.self`).

In `PreviewSupport.swift`, add `WishlistItem.self` to preview `Schema` array.

- [ ] **Step 5: Run test and build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
 xcodebuild -scheme CashFlow -project CashFlow.xcodeproj \
 -destination 'platform=macOS' test \
 -only-testing:CashFlowTests/WishlistSortOrderTests 2>&1 | tail -15
```

Expected: `** TEST SUCCEEDED **`

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
 xcodebuild -scheme CashFlow -project CashFlow.xcodeproj \
 -destination 'platform=macOS' build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add CashFlow/Models/WishlistItem.swift CashFlow/Models/WishlistSortOrder.swift \
  CashFlow/Persistence/ModelContainerFactory.swift CashFlow/Preview/PreviewSupport.swift \
  CashFlowTests/WishlistSortOrderTests.swift
git commit -m "feat: add WishlistItem model and sort order"
```

---

## Task 2: WishlistPurchaseRecorder

**Files:**
- Create: `CashFlow/Models/WishlistPurchaseRecorder.swift`
- Create: `CashFlowTests/WishlistPurchaseRecorderTests.swift`

**Interfaces:**
- Consumes: `WishlistItem`, `Transaction`, `Account`, `Category`
- Produces: `WishlistPurchaseRecorder.recordPurchase(...) -> Transaction`

- [ ] **Step 1: Write failing purchase test**

`CashFlowTests/WishlistPurchaseRecorderTests.swift`:

```swift
import XCTest
import SwiftData
@testable import CashFlow

@MainActor
final class WishlistPurchaseRecorderTests: XCTestCase {
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = ModelContainerFactory.make(inMemory: true).mainContext
    }

    func testRecordPurchaseCreatesTransactionAndDeletesItem() throws {
        let account = Account(name: "Banco", kind: .bank, sortOrder: 0)
        let category = Category(name: "Roupas", kind: .expense, sortOrder: 0)
        context.insert(account)
        context.insert(category)

        let item = WishlistItem(name: "Calça", estimatedAmount: 250, priority: .medium, category: category)
        context.insert(item)
        try context.save()

        let itemID = item.id
        let txn = WishlistPurchaseRecorder.recordPurchase(
            item: item,
            amount: 280,
            account: account,
            date: .now,
            category: category,
            modelContext: context
        )
        try context.save()

        XCTAssertEqual(txn.kind, .expense)
        XCTAssertEqual(txn.amount, 280)
        XCTAssertEqual(txn.account?.id, account.id)
        XCTAssertEqual(txn.category?.id, category.id)
        XCTAssertTrue(txn.note.contains("Calça"))

        let remaining = try context.fetch(FetchDescriptor<WishlistItem>())
        XCTAssertTrue(remaining.isEmpty || !remaining.contains(where: { $0.id == itemID }))
    }
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
 xcodebuild -scheme CashFlow -project CashFlow.xcodeproj \
 -destination 'platform=macOS' test \
 -only-testing:CashFlowTests/WishlistPurchaseRecorderTests 2>&1 | tail -15
```

- [ ] **Step 3: Implement recorder**

`CashFlow/Models/WishlistPurchaseRecorder.swift`:

```swift
import Foundation
import SwiftData

enum WishlistPurchaseRecorder {
    @discardableResult
    static func recordPurchase(
        item: WishlistItem,
        amount: Decimal,
        account: Account,
        date: Date,
        category: Category?,
        modelContext: ModelContext
    ) -> Transaction {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let trimmedNote = item.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let memo = trimmedNote.isEmpty ? item.name : "\(item.name) — \(trimmedNote)"

        let txn = Transaction(
            amount: amount,
            kind: .expense,
            occurredOn: normalizedDate,
            note: memo,
            category: category ?? item.category,
            account: account
        )
        modelContext.insert(txn)
        modelContext.delete(item)
        return txn
    }
}
```

- [ ] **Step 4: Run test — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add CashFlow/Models/WishlistPurchaseRecorder.swift CashFlowTests/WishlistPurchaseRecorderTests.swift
git commit -m "feat: add WishlistPurchaseRecorder"
```

---

## Task 3: Add and purchase sheets

**Files:**
- Create: `CashFlow/Features/Wishlist/AddWishlistItemSheet.swift`
- Create: `CashFlow/Features/Wishlist/PurchaseWishlistItemSheet.swift`

**Interfaces:**
- Consumes: `WishlistItem`, `WishlistPriority`, `WishlistPurchaseRecorder`
- Produces: `AddWishlistItemSheet`, `PurchaseWishlistItemSheet`

- [ ] **Step 1: Implement AddWishlistItemSheet**

Mirror `AddReceivableSheet` structure. Key fields:

```swift
// Required: name non-empty, estimatedAmount > 0
// Priority picker: Picker("Prioridade", selection: $priority) { ForEach(WishlistPriority.allCases) ... }
// Category: CFSelectFieldOptional over expense categories (optional — spec allows nil)
// desiredBy: Toggle "Data desejada" + DateField when enabled
// note: multiline TextField
// save(): insert or update WishlistItem in modelContext
```

Sheet title: `"Novo desejo"` / `"Editar desejo"`. Amount header uses `CFTheme.expense`.

- [ ] **Step 2: Implement PurchaseWishlistItemSheet**

Mirror `PayBillSheet` / `ConfirmReceivableSheet`:

```swift
struct PurchaseWishlistItemSheet: View {
    let item: WishlistItem
    @State private var paidAmount: Decimal  // init from item.estimatedAmount
    @State private var paidDate: Date = .now
    @State private var accountID: UUID?     // default: UserDefaults lastUsedAccountID or first bank
    @State private var categoryID: UUID?    // default: item.category?.id

    private func confirm() {
        guard let account = accounts.first(where: { $0.id == accountID }),
              paidAmount > 0 else { return }
        let category = categories.first { $0.id == categoryID }
        WishlistPurchaseRecorder.recordPurchase(
            item: item,
            amount: paidAmount,
            account: account,
            date: paidDate,
            category: category,
            modelContext: modelContext
        )
        if let accountID { UserDefaults.standard.set(accountID.uuidString, forKey: UserDefaultsKeys.lastUsedAccountID) }
    }
}
```

Toolbar: title `"Registrar compra"`, save `"Comprei"`, `amountColor: CFTheme.expense`.

- [ ] **Step 3: Build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
 xcodebuild -scheme CashFlow -project CashFlow.xcodeproj \
 -destination 'platform=macOS' build 2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'
```

- [ ] **Step 4: Commit**

```bash
git add CashFlow/Features/Wishlist/
git commit -m "feat: add wishlist add and purchase sheets"
```

---

## Task 4: WishlistListView and navigation

**Files:**
- Create: `CashFlow/Features/Wishlist/WishlistListView.swift`
- Modify: `CashFlow/App/SidebarNavigation.swift`
- Modify: `CashFlow/App/RootSidebarView.swift`
- Modify: `CashFlow/App/AdaptiveRootView.swift`

**Interfaces:**
- Produces: `SidebarDestination.wishlist`, `WishlistListView`

- [ ] **Step 1: Add sidebar destination**

In `SidebarNavigation.swift`:

```swift
// enum SidebarDestination — add case wishlist
case wishlist

// title: "Lista de desejos"
// symbolName: "cart.fill"

// SidebarDetailView switch:
case .wishlist:
    WishlistListView()
```

- [ ] **Step 2: RootSidebarView — add row after Metas**

In Section `"Visão"` after Metas label:

```swift
Label("Lista de desejos", systemImage: "cart.fill")
    .tag(SidebarDestination.wishlist)
```

Optional badge: show count when non-empty (`@Query private var wishlistItems: [WishlistItem]`).

- [ ] **Step 3: AdaptiveRootView compact overview**

In `CompactOverviewTab` Section `"Visão"`, add `destinationRow(.wishlist)` after `.goals`.

- [ ] **Step 4: Implement WishlistListView**

```swift
struct WishlistListView: View {
    @Query private var items: [WishlistItem]
  // @State showingAdd, editingItem, purchasingItem

    private var sortedItems: [WishlistItem] {
        WishlistSortOrder.sorted(items)
    }

    private var totalEstimated: Decimal {
        items.reduce(0) { $0 + $1.estimatedAmount }
    }

    // emptyState: CFEmptyState symbol "cart", title "Nenhum desejo cadastrado",
    //   message explaining Gio helps with timing, action "Adicionar desejo"
    // content: optional summary pill with total; LazyVStack of rows
    // row: name, CFAnimatedAmount or .brl for estimate, priority pill, category, RelativeDate for desiredBy
    // context menu: Editar, Comprei, Excluir
    // sheets: AddWishlistItemSheet, PurchaseWishlistItemSheet
}
```

Priority pill colors: urgent → `CFTheme.danger`, high → `CFTheme.warning`, medium → `CFTheme.accent`, low → `CFTheme.textSecondary`.

- [ ] **Step 5: Build macOS + iOS**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
 xcodebuild -scheme CashFlow -project CashFlow.xcodeproj \
 -destination 'platform=macOS' build 2>&1 | tail -5

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
 xcodebuild -scheme CashFlow -project CashFlow.xcodeproj \
 -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5
```

- [ ] **Step 6: Commit**

```bash
git add CashFlow/Features/Wishlist/WishlistListView.swift \
  CashFlow/App/SidebarNavigation.swift CashFlow/App/RootSidebarView.swift \
  CashFlow/App/AdaptiveRootView.swift
git commit -m "feat: add Lista de desejos screen and navigation"
```

---

## Task 5: AI tool context and list_wishlist reader

**Files:**
- Modify: `CashFlow/AI/Tools/AIToolContext.swift`
- Modify: `CashFlow/AI/Tools/AIToolFormatters.swift`
- Modify: `CashFlow/AI/Tools/AIToolReaders.swift`
- Modify: `CashFlow/AI/Tools/AIToolCatalog.swift`
- Modify: `CashFlow/AI/Tools/AIToolInsightContext.swift`
- Modify: `CashFlow/AI/Services/AIChatService.swift`
- Modify: `CashFlow/AI/Services/AIInsightsService.swift`
- Modify: `CashFlow/Features/AI/AIChatSidePanel.swift`
- Modify: `CashFlow/Features/Dashboard/MonthDashboardView.swift` (pass wishlist to insight panel later — add query now)
- Modify: `CashFlowTests/AIToolReadersTests.swift`

**Interfaces:**
- Produces: `AIToolContext.wishlistItems: [WishlistItem]`, `list_wishlist` tool

- [ ] **Step 1: Extend AIToolContext**

```swift
struct AIToolContext {
    // ... existing fields ...
    let wishlistItems: [WishlistItem]
}
```

Update all 3 call sites (`AIChatService` ×2, `AIInsightsService` ×1) and `AIToolReadersTests.makeToolContext()` to pass `wishlistItems: []` or fetched items.

In `AIChatSidePanel`, add:

```swift
@Query(sort: [SortDescriptor(\WishlistItem.createdAt, order: .reverse)])
private var wishlistItems: [WishlistItem]
```

Pass `wishlistItems` into `chatService.send(...)` and `confirmPendingWrite(...)` — update method signatures if needed (check all call sites in `AIChatSidePanel`).

- [ ] **Step 2: Add formatter**

In `AIToolFormatters.swift`:

```swift
static func wishlistItemJSON(_ item: WishlistItem) -> [String: AIToolJSONValue] {
    var obj: [String: AIToolJSONValue] = [
        "id": .string(item.id.uuidString),
        "name": .string(item.name),
        "estimated_amount": .from(item.estimatedAmount),
        "priority": .string(item.priority.rawValue),
        "note": .string(item.note)
    ]
    if let desiredBy = item.desiredBy {
        obj["desired_by"] = .string(desiredBy.formatted(date: .abbreviated, time: .omitted))
    }
    if let category = item.category {
        obj["category"] = .string(category.name)
    }
    return obj
}
```

- [ ] **Step 3: Implement list_wishlist reader**

In `AIToolReaders.execute` switch, add `case "list_wishlist": return listWishlist(context)`.

```swift
private static func listWishlist(_ context: AIToolContext) -> AIToolResultPayload {
    let sorted = WishlistSortOrder.sorted(context.wishlistItems)
    let items = sorted.map { AIToolJSONValue.object(AIToolFormatters.wishlistItemJSON($0)) }
    let total = sorted.reduce(Decimal.zero) { $0 + $1.estimatedAmount }
    let byPriority = Dictionary(grouping: sorted, by: \.priority.rawValue)
        .mapValues { $0.reduce(Decimal.zero) { $0 + $1.estimatedAmount } }
    var priorityTotals: [String: AIToolJSONValue] = [:]
    for (key, value) in byPriority {
        priorityTotals[key] = .from(value)
    }
    return .success(.object([
        "items": .array(items),
        "total_estimated": .from(total),
        "count": .int(sorted.count),
        "totals_by_priority": .object(priorityTotals)
    ]))
}
```

- [ ] **Step 4: Catalog entry**

In `AIToolCatalog.swift` read tools section:

```swift
AIToolDefinition(
    name: "list_wishlist",
    description: "Lista de desejos de compra com totais por prioridade.",
    parameters: []
),
```

- [ ] **Step 5: Insight context section**

In `AIToolInsightContext.compactSnapshot`, after receivables block:

```swift
if !context.wishlistItems.isEmpty,
   let wishlist = try? AIToolReaders.execute(name: "list_wishlist", args: [:], context: context),
   wishlist.ok, let data = wishlist.data {
    sections.append("=== LISTA DE DESEJOS ===\n\(jsonLine(data))")
}
```

- [ ] **Step 6: Add reader test**

In `AIToolReadersTests`:

```swift
func testListWishlistReturnsItems() throws {
    let item = WishlistItem(name: "Fone", estimatedAmount: 800, priority: .high)
    context.insert(item)
    try context.save()

    let toolContext = makeToolContext()
    let result = try AIToolReaders.execute(name: "list_wishlist", args: [:], context: toolContext)
    XCTAssertTrue(result.ok)
}
```

Update `makeToolContext()` to fetch wishlist items:

```swift
let wishlistItems = (try? context.fetch(FetchDescriptor<WishlistItem>())) ?? []
// pass wishlistItems: wishlistItems
```

- [ ] **Step 7: Run tests + build + commit**

```bash
git commit -m "feat: add list_wishlist AI tool"
```

---

## Task 6: AI write tools for wishlist

**Files:**
- Modify: `CashFlow/AI/Tools/AIToolResolver.swift`
- Modify: `CashFlow/AI/Tools/AIToolWriters.swift`
- Modify: `CashFlow/AI/Tools/AIToolCatalog.swift`
- Modify: `CashFlow/AI/Agent/AIAgentLoop.swift`
- Create: `CashFlowTests/AIToolWritersTests.swift` (if missing) or extend existing

**Interfaces:**
- Produces: `create_wishlist_item`, `update_wishlist_item`, `delete_wishlist_item`, `purchase_wishlist_item`
- Consumes: `WishlistPurchaseRecorder`, `AIToolResolver.wishlistItem`

- [ ] **Step 1: Add resolver**

In `AIToolResolver.swift`:

```swift
static func wishlistItem(in items: [WishlistItem], id: UUID?, name: String?) throws -> WishlistItem {
    if let id, let match = items.first(where: { $0.id == id }) { return match }
    guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw AIToolResolverError.missingIdentifier("item da lista de desejos")
    }
    let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let matches = items.filter { $0.name.lowercased() == normalized }
    if matches.count == 1 { return matches[0] }
    // partial + ambiguous + notFound — same pattern as bill resolver
    ...
}
```

- [ ] **Step 2: Catalog write tools**

```swift
AIToolDefinition(
    name: "create_wishlist_item",
    description: "Adiciona item à lista de desejos.",
    parameters: [
        .init(name: "name", type: "string", description: "Nome do item", required: true),
        .init(name: "estimated_amount", type: "number", description: "Valor estimado em reais", required: true),
        .init(name: "priority", type: "string", description: "low, medium, high ou urgent", required: false),
        .init(name: "category", type: "string", description: "Categoria de despesa", required: false),
        .init(name: "desired_by", type: "string", description: "Data desejada ISO ou dd/MM/yyyy", required: false),
        .init(name: "note", type: "string", description: "Notas", required: false)
    ]
),
// update_wishlist_item: item_id or item_name + optional fields
// delete_wishlist_item: item_id or item_name
// purchase_wishlist_item: item_id or item_name, optional amount, account, date, category
```

- [ ] **Step 3: Implement writers**

`createWishlistItem`:

```swift
let name = try requireString(args, key: "name")
let amount = try requireDecimal(args, key: "estimated_amount")
guard amount > 0 else { throw ... }
let priority = WishlistPriority(rawValue: AIToolJSON.string(args, key: "priority") ?? "") ?? .medium
let category = try? AIToolResolver.category(in: context.categories, id: nil, name: AIToolJSON.string(args, key: "category"), kind: .expense)
let desiredBy = AIToolJSON.date(args, key: "desired_by", calendar: context.calendar)
let note = AIToolJSON.string(args, key: "note") ?? ""
let item = WishlistItem(name: name, estimatedAmount: amount, priority: priority, note: note, desiredBy: desiredBy, category: category)
context.modelContext.insert(item)
return .success(.object(["id": .string(item.id.uuidString), "name": .string(item.name)]))
```

`purchaseWishlistItem`:

```swift
let item = try AIToolResolver.wishlistItem(
    in: context.wishlistItems,
    id: AIToolJSON.uuid(args, key: "item_id"),
    name: AIToolJSON.string(args, key: "item_name")
)
let amount = AIToolJSON.decimal(args, key: "amount") ?? item.estimatedAmount
let account = try AIToolResolver.account(in: context.accounts, id: nil, name: AIToolJSON.string(args, key: "account"))
let date = AIToolJSON.date(args, key: "date", calendar: context.calendar) ?? context.now
let category = try? AIToolResolver.category(...)
let txn = WishlistPurchaseRecorder.recordPurchase(item: item, amount: amount, account: account, date: date, category: category ?? item.category, modelContext: context.modelContext)
return .success(.object(["transaction_id": .string(txn.id.uuidString), "amount": .from(amount)]))
```

Add `buildSummary` cases for all 4 write tools (Portuguese summaries for confirmation UI).

Update `AIAgentLoop.writeNudge` string to include wishlist tools.

- [ ] **Step 4: Write purchase tool test**

```swift
func testPurchaseWishlistItemCreatesTransactionAndRemovesItem() throws {
    let account = Account(name: "Banco", kind: .bank, sortOrder: 0)
    context.insert(account)
    let item = WishlistItem(name: "Fone", estimatedAmount: 500, priority: .medium)
    context.insert(item)
    try context.save()

    let toolContext = makeToolContext()
    let result = try AIToolWriters.execute(
        name: "purchase_wishlist_item",
        args: ["item_name": "Fone", "account": "Banco"],
        context: toolContext
    )
    XCTAssertTrue(result.ok)
    let remaining = try context.fetch(FetchDescriptor<WishlistItem>())
    XCTAssertTrue(remaining.isEmpty)
}
```

- [ ] **Step 5: AIChatSidePanel status labels**

In `toolStatusLabel`, add:

```swift
case let name where name.contains("wishlist"):
    return "Consultando lista de desejos…"
```

For write tools in confirmation flow, existing write confirmation should work via `buildSummary`.

- [ ] **Step 6: Tests + build + commit**

```bash
git commit -m "feat: add wishlist AI write tools"
```

---

## Task 7: Chat prompts

**Files:**
- Modify: `CashFlow/AI/Prompts/ChatPrompts.swift`

- [ ] **Step 1: Add wishlist guidance to baseSystem**

After existing write-tool bullets in `ChatPrompts.swift`:

```swift
- Lista de desejos (compras não urgentes): use list_wishlist para consultar; create_wishlist_item para cadastrar; purchase_wishlist_item quando o usuário confirmar que comprou ("comprei o fone").
- Ao avaliar timing de compra: considere saldo realizado do mês, contas a pagar pendentes e metas — não recomende compra se o fluxo estiver apertado.
- Respeite prioridade (urgent > high > medium > low) e desired_by ao sugerir ordem.
```

- [ ] **Step 2: Build + commit**

```bash
git commit -m "feat: add wishlist guidance to chat prompts"
```

---

## Task 8: Dashboard wishlist panel and insight service

**Files:**
- Create: `CashFlow/AI/Services/AIWishlistInsightService.swift`
- Create: `CashFlow/Features/Dashboard/DashboardWishlistPanel.swift`
- Modify: `CashFlow/Persistence/UserDefaultsKeys.swift`
- Modify: `CashFlow/Features/Dashboard/MonthDashboardView.swift`

**Interfaces:**
- Produces: `AIWishlistInsightService.generateInsight(...)`, `DashboardWishlistPanel`

- [ ] **Step 1: Cache keys**

In `UserDefaultsKeys.swift`:

```swift
static func aiWishlistInsightCacheKey(monthKey: String) -> String {
    "ai.wishlistInsight.\(monthKey)"
}
static func aiWishlistInsightCachedAtKey(monthKey: String) -> String {
    "ai.wishlistInsight.\(monthKey).cachedAt"
}
```

- [ ] **Step 2: AIWishlistInsightService**

```swift
enum WishlistInsightPrompts {
    static let system = """
    Você sugere timing de compras da lista de desejos em português do Brasil.
    Formato: 1 a 2 bullets começando com "- ".
    Máximo 120 palavras. Não dê conselhos de investimento regulados.

    Regras:
    - Identifique itens que cabem na folga discrecional DESTE mês (saldo realizado positivo após obrigações).
    - Destaque itens com desired_by próximo.
    - Se o fluxo estiver apertado, diga para esperar — NÃO empurre compras mesmo de itens urgentes.
    - Não invente valores; use apenas os dados fornecidos.
    """
}

enum AIWishlistInsightService {
    static func cachedInsight(monthKey: String) -> String? { ... }
    static func cacheInsight(_ text: String, monthKey: String) { ... }

    @MainActor
    static func generateInsight(
        summary: MonthSummary,
        overview: FinancialOverview,
        wishlistItems: [WishlistItem],
        goals: [FinancialGoal],
        transactions: [Transaction],
        accounts: [Account],
        bills: [Bill],
        receivables: [Receivable],
        recurringExpenses: [RecurringExpense],
        recurringIncomes: [RecurringIncome],
        categories: [Category],
        monthlyIncomeCents: Int,
        modelContext: ModelContext,
        aiService: AIService
    ) async throws -> String {
        guard !wishlistItems.isEmpty else { return "" }
        let toolContext = AIToolContext(..., wishlistItems: wishlistItems)
        let wishlistSnapshot = AIToolInsightContext.compactSnapshot(context: toolContext)
        // Include month summary + patrimony lines similar to AIInsightsService
        return try await aiService.complete(messages: [
            AIMessage(role: .system, content: WishlistInsightPrompts.system),
            AIMessage(role: .user, content: contextBlock)
        ], maxTokens: 300)
    }
}
```

- [ ] **Step 3: DashboardWishlistPanel**

Mirror `DashboardInsightPanel` structure:

```swift
struct DashboardWishlistPanel: View {
    let referenceDate: Date
    let summary: MonthSummary
    let overview: FinancialOverview
    let wishlistItems: [WishlistItem]
    // ... other deps for generateInsight

    private var totalEstimated: Decimal {
        wishlistItems.reduce(0) { $0 + $1.estimatedAmount }
    }

    var body: some View {
        if wishlistItems.isEmpty {
            CFPanel {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Lista de desejos", systemImage: "cart.fill")
                    Text("Cadastre compras que você quer fazer eventualmente — a \(AIAssistantIdentity.name) ajuda a escolher o melhor momento.")
                        .font(CFTheme.caption())
                        .foregroundStyle(CFTheme.textSecondary)
                }
            }
        } else if aiService.configuration.isReady {
            CFPanel {
                // header: "Lista de desejos" + refresh button
                // total row: "Total estimado" + amount
                // body: CFTypewriter with cached insight OR skeleton OR "Gerar sugestão" button
            }
            .onAppear(perform: loadCachedInsight)
        }
    }
}
```

- [ ] **Step 4: Wire into MonthDashboardView**

Add `@Query private var wishlistItems: [WishlistItem]` and in `rightColumn`, insert `DashboardWishlistPanel` **above** `DashboardInsightPanel`:

```swift
DashboardWishlistPanel(
    referenceDate: referenceDate,
    summary: summary,
    overview: overview,
    wishlistItems: wishlistItems,
    goals: goals,
    transactions: transactions,
    accounts: accounts,
    bills: bills,
    receivables: receivables,
    recurringExpenses: recurringExpenses,
    recurringIncomes: recurringIncomes,
    categories: categories,
    monthlyIncomeCents: monthlyIncomeCents
)
```

- [ ] **Step 5: Preview seed (optional)**

In `PreviewSupport.seed`, add 1–2 sample `WishlistItem` entries for dashboard previews.

- [ ] **Step 6: Build macOS + iOS + full test suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
 xcodebuild -scheme CashFlow -project CashFlow.xcodeproj \
 -destination 'platform=macOS' test 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git commit -m "feat: add dashboard wishlist panel and Gio suggestions"
```

---

## Spec Coverage Checklist

| Spec requirement | Task |
|------------------|------|
| `WishlistItem` model | Task 1 |
| Sort order | Task 1 |
| No purchase history | Task 2 (delete on purchase) |
| Add/edit sheet with all fields | Task 3 |
| Purchase sheet → transaction | Task 3 |
| Sidebar navigation | Task 4 |
| `list_wishlist` | Task 5 |
| Write tools (4) | Task 6 |
| Chat prompts | Task 7 |
| Dashboard panel + proactive insight | Task 8 |
| `AIToolInsightContext` inclusion | Task 5 |
| Tests | Tasks 1, 2, 5, 6 |

## Out of Scope (confirmed not in plan)

- Purchase history
- Goal linking
- Installments on list
- Push notifications
- Structured product URLs
