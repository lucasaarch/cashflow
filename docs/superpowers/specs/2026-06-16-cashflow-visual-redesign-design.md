# CashFlow Visual Redesign — Design Spec

**Date:** 2026-06-16  
**Status:** Approved  
**Scope:** Visual-only redesign. No functional or data model changes.

---

## Goal

Transform CashFlow from a functional SwiftUI-default macOS app into a premium, visually striking personal finance app. Functionality is frozen; every effort goes toward color, typography, depth, motion, and layout polish.

---

## Decisions Summary

| Decision | Choice |
|----------|--------|
| Visual personality | Premium Dark (Copilot Money, Linear, Arc) |
| Theme mode | System-adaptive — polished light and dark palettes |
| Accent color | Keep brand green; evolve tones per appearance mode |
| Motion | Expressive — springs, stagger, animated numbers |
| Layout | Reimagine content areas; keep native sidebar |
| Native integrations | `NavigationSplitView` + `List(.sidebar)` preserved; all other UI open for custom redesign |

---

## Approach

**Sidebar native + visual bridge + custom content (Approach 2)**

- Keep the native macOS sidebar unchanged in structure.
- Apply minimal bridge styling (tint, window background continuity).
- Rebuild all detail-column content with a unified design system so custom content feels cohesive with the native sidebar — not disconnected from it.

If the sidebar ever feels visually inconsistent after the content redesign, it may be replaced in a future iteration. Current preference is to keep it.

---

## Design System

New module: `Shared/DesignSystem/`

### Color Tokens (Asset Catalog + Swift)

| Token | Purpose |
|-------|---------|
| `BrandGreen` | Primary accent — evolved from current `#4ADE73`; darker/saturated in dark mode, softer in light mode |
| `SurfacePrimary` | Window / page background |
| `SurfaceSecondary` | Card backgrounds (light mode solid) |
| `SurfaceElevated` | Elevated cards, modals |
| `TextPrimary` / `TextSecondary` / `TextTertiary` | Text hierarchy |
| `SemanticIncome` | Positive values, income |
| `SemanticExpense` | Expenses, outflows |
| `SemanticWarning` | Pace warning state |
| `SemanticDanger` | Pace danger, negative balance |
| `SemanticDebt` | Credit card debt (replaces ad-hoc `.pink`) |
| `SurfaceGradientTop` / `SurfaceGradientBottom` | Subtle page gradients |

All hardcoded system colors (`.red`, `.green`, `.blue`, `.orange`, `.pink`) in views migrate to semantic tokens.

### Typography

| Role | Font | Size | Notes |
|------|------|------|-------|
| Hero amount | SF Pro Rounded | 44pt semibold | `.monospacedDigit()` |
| Title | SF Pro | 22pt semibold | Section headers |
| Headline | SF Pro | 17pt semibold | Card titles |
| Body | SF Pro | 15pt regular | Default text |
| Caption | SF Pro | 12pt regular | Labels, metadata |
| KPI values | SF Pro Rounded | 15pt medium | `.monospacedDigit()` |

### Materials

**Dark mode:**
- Cards: `.ultraThinMaterial` with green tint overlay (~4% opacity)
- Borders: `white @ 8%` opacity, 0.5pt
- Page background: gradient `#0D0F14` → `#111520`

**Light mode:**
- Cards: solid white (`SurfaceSecondary`)
- Shadow: `y: 4, blur: 16, opacity: 8%`
- Page background: gradient `#F5F5F7` → `#FAFAFA`

### Motion Presets (`Motion.swift`)

| Preset | Response | Damping | Use |
|--------|----------|---------|-----|
| `snappy` | 0.35 | 0.85 | Hover, toggles, small UI |
| `bouncy` | 0.50 | 0.70 | Card entrance, row appear |
| `gentle` | 0.60 | 0.90 | Month transitions, layout shifts |

**Patterns:**
- Dashboard cards: stagger entrance, 50ms delay per card
- Monetary values: `.contentTransition(.numericText())` with spring animation
- Progress bars: spring fill on appear
- Rows: hover scale 1.005 + shadow lift
- Month change: crossfade + slide on dashboard content

**Accessibility:** Respect `@Environment(\.accessibilityReduceMotion)` — disable stagger, springs, and numeric transitions when enabled.

### Base Components

| Component | Responsibility |
|-----------|----------------|
| `CFGlassCard` | Card container — glass (dark) or solid+shadow (light) |
| `CFMetricTile` | KPI tile with icon badge, label, animated value |
| `CFProgressBar` | Animated progress bar with spring fill |
| `CFIconBadge` | Circle/squircle icon container with tint background |
| `CFAnimatedAmount` | Monetary value with numeric text transition |
| `CFPillButton` | Rounded pill button (primary, ghost, destructive variants) |
| `CFEmptyState` | Empty state with gradient symbol, title, description, CTA |
| `CFInputField` | Custom text/currency input with focus ring |

---

## Screen Designs

### Sidebar (native, bridge only)

**Keep:**
- `NavigationSplitView` structure
- `List(.sidebar)` with sections (Visão, Movimentações, Cadastros)
- `SidebarCommands()` in app commands

**Apply:**
- `.tint(Color("BrandGreen"))` on root split view
- Unified `.background(SurfacePrimary)` on split view
- `navigationTitle("CashFlow")` — semibold weight

**Do not change:** selection binding, destinations, column width constraints.

---

### Dashboard (`MonthDashboardView`)

**Layout:**
- ScrollView with gradient page background
- Max content width ~900px, centered
- Adaptive grid:
  - Hero KPI: full width
  - Pace + Category breakdown: side-by-side when width > 700px, stacked otherwise
  - Account breakdown: full width

**Hero KPI card:**
- Large `CFGlassCard`, 24px padding
- "Saldo atual" — caption, uppercase, letter-spacing
- Balance — 44pt `CFAnimatedAmount`, animates on month change
- KPI tiles (Entrou / Saiu / Em cartões) — mini `CFMetricTile` inside hero
- Budget button — `CFPillButton` ghost variant, top-right

**Pace card:**
- Semantic colors for pace states (not raw `.blue`/`.orange`)
- Animated progress bars via `CFProgressBar`
- Subtle pulse on status icon when state is `danger`

**Category breakdown ("Maiores dores"):**
- Top category: subtle red border + glow highlight
- Progress bars with green-to-transparent gradient
- Stagger row entrance (50ms)

**Account breakdown:**
- Account color from `colorHex` via `CFIconBadge`
- Credit card totals use `SemanticDebt`

**Month navigator:**
- Custom pill in toolbar: `‹ Month Year ›`
- Hover states on chevrons
- Dashboard content crossfade + slide on month change

**Empty state:** `CFEmptyState` when no accounts exist.

---

### Transactions (`TransactionListView`)

Replace `List(.inset)` with custom timeline:

**Structure:**
- `ScrollView` + `LazyVStack`
- Sticky day headers: date pill (left) + day total (right)
- "Hoje" / "Ontem" badges with green accent

**Transaction row (`TransactionRow`):**
- Hover: background lift + scale 1.005
- `CFIconBadge` tinted by category (when available) or semantic income/expense
- Amount: `CFAnimatedAmount` or formatted text with semantic color
- Account + note in secondary line
- Tap to edit (unchanged behavior)
- `.contextMenu` preserved for edit/delete

**Toolbar:** Keep native `+` button (primary action).

**Empty states:** `CFEmptyState` variants for no accounts, no categories, no transactions.

---

### Categories & Accounts (`CategoriesView`, `AccountsView`)

Replace `List(.inset)` with custom scroll lists matching transaction row visual language.

**Row pattern:**
- `CFIconBadge` + name + subtle chevron
- Hover lift
- Context menu / swipe actions preserved (archive, edit)

**Accounts row extras:**
- Balance right-aligned via `CFAnimatedAmount`
- Credit card: `SemanticDebt` color, "A pagar" caption

**Empty states:** `CFEmptyState` with contextual copy and CTA.

---

### Sheets (`AddTransactionSheet`, `CategorySheet`, `AccountSheet`)

Replace `Form(.grouped)` with custom VStack layout.

**Structure (all sheets):**
1. Hero preview (top) — live preview of entity being created/edited
2. Form fields (middle) — scrollable custom inputs
3. Footer (bottom, fixed) — Cancel (ghost) + Save (primary pill)

**Add Transaction:**
- Centered amount field, 42pt Rounded, color shifts on kind change
- `TransactionKindSwitcher` — matched geometry effect + spring
- Category/account pickers as custom styled pickers
- Optional note field with expand animation
- `.presentationBackground(.ultraThinMaterial)` in dark mode

**Category / Account sheets:**
- Enhanced hero: large `CFIconBadge` with colored shadow
- Live name/kind/balance preview
- `CFInputField` for text fields
- `IconPickerField` and `ColorPicker` retained, restyled to match system
- Footer: Archive (destructive, edit only) + Cancel + Save

---

## Architecture

### Files to create

```
Shared/DesignSystem/
  Theme.swift
  Motion.swift
  CFGlassCard.swift
  CFMetricTile.swift
  CFProgressBar.swift
  CFIconBadge.swift
  CFAnimatedAmount.swift
  CFPillButton.swift
  CFEmptyState.swift
  CFInputField.swift
```

### Asset Catalog additions

```
Colors/
  BrandGreen.colorset          (light + dark variants)
  SurfacePrimary.colorset
  SurfaceSecondary.colorset
  SurfaceElevated.colorset
  TextPrimary.colorset
  TextSecondary.colorset
  TextTertiary.colorset
  SemanticIncome.colorset
  SemanticExpense.colorset
  SemanticWarning.colorset
  SemanticDanger.colorset
  SemanticDebt.colorset
  SurfaceGradientTop.colorset
  SurfaceGradientBottom.colorset
```

### Files to refactor (visual only)

| File | Changes |
|------|---------|
| `CashFlowApp.swift` | Apply root theme background |
| `RootSidebarView.swift` | Bridge styling only |
| `MonthDashboardView.swift` | Full visual rebuild |
| `DashboardCard.swift` | Replace with `CFGlassCard` or deprecate |
| `CategoryBreakdownCard.swift` | Design system components |
| `AccountBreakdownCard.swift` | Design system components |
| `TransactionListView.swift` | Custom timeline |
| `TransactionRow.swift` | Hover, badges, semantic colors |
| `AddTransactionSheet.swift` | Custom layout |
| `CategoriesView.swift` | Custom list + sheet restyle |
| `AccountsView.swift` | Custom list + sheet restyle |
| `TransactionKindSwitcher.swift` | Motion + visual polish |
| `CurrencyField.swift` | Focus ring styling |
| `IconPickerField.swift` | Match design system |

### Files unchanged

- All models (`Transaction`, `Category`, `Account`)
- Persistence layer (`DataReset`, `UserDefaultsKeys`)
- Business logic (`MonthSummary`, `Money`)

---

## Data Flow

No changes. Views continue to use `@Query`, `@Environment(\.modelContext)`, and existing computed properties. The redesign is a pure presentation layer refactor.

---

## Error Handling

No functional changes. Existing validation (disabled save when name empty, etc.) remains. Visual enhancement for invalid fields (red focus ring) is out of scope for v1.

---

## Testing Checklist

- [ ] Dark mode: all screens render correctly
- [ ] Light mode: all screens render correctly
- [ ] System Auto appearance: switches cleanly
- [ ] Dashboard grid: side-by-side at wide width, stacked at narrow
- [ ] Month navigation: animated transition, numbers update
- [ ] Transaction timeline: scroll performance with many items
- [ ] Sheet presentation: dark material background
- [ ] Hover states: rows and cards respond on macOS
- [ ] Reduce Motion enabled: no stagger/spring animations
- [ ] Empty states: all four screens show correct variant
- [ ] Sidebar: native selection and navigation unchanged

---

## Out of Scope

- New features or functionality
- Model or persistence changes
- Custom sidebar replacement
- iOS / iPadOS targets
- Custom app icon redesign (existing icon kept)
- Chart/graph additions

---

## Implementation Order (recommended)

1. Design system foundation (Theme, Motion, base components)
2. Asset catalog color tokens
3. Dashboard (highest visual impact)
4. Transaction list + row
5. Category and account lists
6. Sheets (transaction, category, account)
7. Sidebar bridge + root app styling
8. Polish pass: motion tuning, reduce-motion, edge cases
