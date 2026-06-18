# CashFlow — Lista de desejos

**Date:** 2026-06-17  
**Status:** Draft for review

## Overview

Add a **Lista de desejos** feature: a queue of discretionary purchases the user wants to make eventually (not necessarily now). **Gio** helps decide *when* to buy each item based on priority, estimated value, optional desired date, cash flow, and pending obligations.

This is intentionally separate from **Metas** (long-term savings/investment toward a known target, e.g. saving R$ 12k for a MacBook M6 Pro next year).

### Distinction from Metas

| Metas | Lista de desejos |
|-------|------------------|
| Accumulate/invest leftover money over time | Decide *when* to spend |
| Target amount with progress tracking | Estimated price, no dedicated savings account |
| Long-horizon, specific big purchase | Flexible timing; may be urgent or sporadic |
| Example: M6 Pro fund | Example: new pants, headphones, desk chair |

---

## Requirements summary

| Decision | Choice |
|----------|--------|
| Domain | New SwiftData model `WishlistItem` (not a Goal subtype) |
| Fields | Name, estimated amount, priority, category (optional), desired-by date (optional), notes |
| On purchase | Delete item + create expense `Transaction` automatically |
| Purchase history | None — repeatable items (e.g. "nova calça") would clutter |
| Gio — chat | Answer timing questions using tools + financial context |
| Gio — dashboard | Panel with list total + 1–2 proactive suggestions |
| Gio — proactive | Suggest good buying windows when cash flow allows; never push purchases when tight |
| Urgency alerts when cash tight | Out of scope (user chose C, not D) |
| Link to Metas | Out of scope (v1) |

---

## Data model

### `WishlistItem` (SwiftData `@Model`)

```swift
enum WishlistPriority: String, Codable, CaseIterable {
    case low, medium, high, urgent
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

    var priority: WishlistPriority { get/set via priorityRaw }
}
```

**Design notes:**

- No `status` or `purchasedAt` — purchasing deletes the record.
- `category` is optional but encouraged in the add sheet; reuses existing `Category` model.
- `desiredBy` is optional structured date for "before the trip in July", Black Friday, etc.
- Register in `ModelContainerFactory` alongside `Receivable`, `Bill`, `FinancialGoal`.

### Sort order (list UI)

1. Priority: urgent → high → medium → low
2. Within same priority: `desiredBy` ascending (nil last)
3. Tie-break: `createdAt` descending

---

## UI

### Navigation

- New `SidebarDestination.wishlist` — title **Lista de desejos**, symbol `cart.fill`
- Placement: Finanças group, after **Metas** (or adjacent to consumption-related items)
- `WishlistListView` as detail destination

### List view

- Empty state: CFEmptyState with CTA "Adicionar desejo"
- Cards/rows: name, estimated amount (privacy-aware), priority pill, category badge, desired-by if set
- Swipe/context actions: Edit, **Comprei**, Excluir
- Toolbar: "Novo desejo"

### Add / Edit sheet (`AddWishlistItemSheet`)

| Field | Required |
|-------|----------|
| Nome | Yes |
| Valor estimado | Yes |
| Prioridade | Yes (default: média) |
| Categoria | No |
| Data desejada | No (toggle to enable) |
| Notas | No |

Follow sheet patterns from `AddReceivableSheet` / `CategoriesView`.

### Purchase sheet (`PurchaseWishlistItemSheet`)

Triggered by **Comprei**:

| Field | Default |
|-------|---------|
| Valor | `estimatedAmount` |
| Conta | Last-used or first liquid account |
| Data | Today |
| Categoria | Item's category |

On confirm:

1. Create `Transaction` (expense, negative amount) on selected account
2. `modelContext.delete(wishlistItem)`
3. Save context

No confirmation dialog beyond the sheet itself.

---

## Gio integration

### AI tools (catalog + readers/writers)

| Tool | Type | Purpose |
|------|------|---------|
| `list_wishlist` | read | Active items, totals by priority, items with `desiredBy` soon |
| `create_wishlist_item` | write | Add item from chat |
| `update_wishlist_item` | write | Change fields |
| `delete_wishlist_item` | write | Remove without purchase |
| `purchase_wishlist_item` | write | Create transaction + delete item (same as UI) |

Include wishlist summary in `AIToolInsightContext.compactSnapshot` when non-empty.

### Chat prompts (`ChatPrompts`)

Add guidance:

- Use `list_wishlist` when user asks about buying timing, priorities, or the list
- Use `purchase_wishlist_item` when user confirms they bought something ("comprei o fone")
- Never recommend buying when realized month balance is negative and pending bills are high
- Respect priority and `desiredBy` when ranking suggestions

### Dashboard panel (`DashboardWishlistPanel`)

New panel on `MonthDashboardView` (shown when list non-empty or always with empty CTA):

- **Total estimado** da lista ativa
- **Sugestão da Gio** — 1–2 bullets, cached per month (reuse insight cache pattern or dedicated keys in `UserDefaultsKeys`)
- Link/action: "Ver lista" → navigate to wishlist

### Proactive suggestion logic (generation prompt)

When generating wishlist insight, provide Gio:

- `MonthSummary` (realized vs expected)
- `FinancialOverview` (liquid balance, pending bills)
- Compact wishlist snapshot
- Active goals summary (for context — savings commitments reduce discretionary room)

Prompt intent:

- Identify items that fit *this month's* discretionary room (realized surplus after obligations)
- Flag items with `desiredBy` approaching
- Say "espere" when cash flow is tight — do not push urgent items when it would strain finances
- Max 2 bullets, Portuguese, no investment advice

Regenerate: on dashboard refresh (same as monthly insight) or when wishlist changes significantly (optional v1: only manual refresh + monthly cache).

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  UI Layer                                               │
│  ├─ WishlistListView                                    │
│  ├─ AddWishlistItemSheet                                │
│  ├─ PurchaseWishlistItemSheet                             │
│  └─ DashboardWishlistPanel (MonthDashboardView)         │
├─────────────────────────────────────────────────────────┤
│  Models                                                 │
│  └─ WishlistItem + WishlistPriority                     │
├─────────────────────────────────────────────────────────┤
│  AI Layer                                               │
│  ├─ AIToolCatalog (5 tools)                             │
│  ├─ AIToolReaders / AIToolWriters                       │
│  ├─ AIToolInsightContext (+ wishlist snapshot)          │
│  ├─ AIWishlistInsightService (or extend AIInsights)     │
│  └─ ChatPrompts (wishlist guidance)                     │
├─────────────────────────────────────────────────────────┤
│  Persistence                                            │
│  └─ SwiftData → WishlistItem                            │
└─────────────────────────────────────────────────────────┘
```

### Purchase flow (UI and tool share logic)

Extract a small helper (e.g. `WishlistPurchaseRecorder`) mirroring patterns like `FundTransferRecorder`:

```swift
enum WishlistPurchaseRecorder {
    static func recordPurchase(
        item: WishlistItem,
        amount: Decimal,
        account: Account,
        date: Date,
        category: Category?,
        modelContext: ModelContext
    ) throws -> Transaction
}
```

Both `PurchaseWishlistItemSheet` and `purchase_wishlist_item` tool call this.

---

## Out of scope (v1)

- Purchase history / archive of bought items
- Linking wishlist items to Metas or goal accounts
- Installment planning on the list (purchase creates a single transaction)
- Push notifications
- Structured URL/product link field (use notes)
- Urgency override alerts when cash flow is tight
- Price tracking / external APIs (Amazon, etc.)

---

## Testing

| Test | Coverage |
|------|----------|
| `WishlistSortOrderTests` | Priority + desiredBy ordering |
| `WishlistPurchaseRecorderTests` | Transaction created, item deleted |
| `AIToolReadersTests` | `list_wishlist` snapshot shape |
| `AIToolWritersTests` | `purchase_wishlist_item` end-to-end |

---

## Delivery phases

| Phase | Scope |
|-------|--------|
| **1** | `WishlistItem` model, container registration, list + add/edit + purchase sheets, sidebar |
| **2** | AI tools (read/write), chat prompt updates, `WishlistPurchaseRecorder` |
| **3** | Dashboard panel + wishlist insight generation + cache |

---

## Open questions (resolved)

| Question | Answer |
|----------|--------|
| Relation to Metas | Separate domains |
| Fields | Name, amount, priority, category, notes, optional desiredBy |
| On purchase | Delete + auto transaction, no history |
| Gio behavior | Chat + dashboard + proactive suggestions (not tight-cash urgency push) |
| Approach | New `WishlistItem` model (recommended option A) |
