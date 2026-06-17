# CashFlow Visual Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform CashFlow into a premium, system-adaptive macOS app with expressive motion — visual-only, no model/persistence changes.

**Architecture:** Introduce `Shared/DesignSystem/` with color tokens (Asset Catalog), motion presets, and reusable components. Refactor detail-column views to consume the design system. Keep native `NavigationSplitView` sidebar with bridge styling only.

**Tech Stack:** SwiftUI, SwiftData (unchanged), macOS 14+, Asset Catalog colorsets, `@Environment(\.colorScheme)`, `@Environment(\.accessibilityReduceMotion)`.

**Spec:** `docs/superpowers/specs/2026-06-16-cashflow-visual-redesign-design.md`

**Build command (use after every task):**
```bash
xcodebuild -scheme CashFlow -project CashFlow.xcodeproj -destination 'platform=macOS' build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

**Note:** Project uses `PBXFileSystemSynchronizedRootGroup` — new Swift files under `CashFlow/` are picked up automatically. No `pbxproj` edits needed for new source files.

---

## File Map

| File | Responsibility |
|------|----------------|
| `Shared/DesignSystem/Theme.swift` | Color/font/spacing tokens, page background modifier |
| `Shared/DesignSystem/Motion.swift` | Spring presets, stagger helper, reduce-motion wrapper |
| `Shared/DesignSystem/CFGlassCard.swift` | Glass (dark) / solid+shadow (light) card |
| `Shared/DesignSystem/CFIconBadge.swift` | Icon in tinted circle/squircle |
| `Shared/DesignSystem/CFAnimatedAmount.swift` | Monetary value with numeric transition |
| `Shared/DesignSystem/CFProgressBar.swift` | Spring-animated progress bar |
| `Shared/DesignSystem/CFMetricTile.swift` | KPI tile (icon + label + value) |
| `Shared/DesignSystem/CFPillButton.swift` | Pill button variants |
| `Shared/DesignSystem/CFEmptyState.swift` | Empty state with gradient symbol |
| `Shared/DesignSystem/CFInputField.swift` | Styled text input with focus ring |
| `Shared/DesignSystem/CFHoverRow.swift` | Row hover lift wrapper (macOS) |
| `Shared/DesignSystem/CFPageBackground.swift` | Gradient page background |
| `Assets.xcassets/*.colorset` | Semantic color tokens (light + dark) |

---

### Task 1: Color Tokens in Asset Catalog

**Files:**
- Create: `CashFlow/Assets.xcassets/BrandGreen.colorset/Contents.json`
- Create: `CashFlow/Assets.xcassets/SurfacePrimary.colorset/Contents.json`
- Create: `CashFlow/Assets.xcassets/SurfaceSecondary.colorset/Contents.json`
- Create: `CashFlow/Assets.xcassets/SurfaceElevated.colorset/Contents.json`
- Create: `CashFlow/Assets.xcassets/TextPrimary.colorset/Contents.json`
- Create: `CashFlow/Assets.xcassets/TextSecondary.colorset/Contents.json`
- Create: `CashFlow/Assets.xcassets/TextTertiary.colorset/Contents.json`
- Create: `CashFlow/Assets.xcassets/SemanticIncome.colorset/Contents.json`
- Create: `CashFlow/Assets.xcassets/SemanticExpense.colorset/Contents.json`
- Create: `CashFlow/Assets.xcassets/SemanticWarning.colorset/Contents.json`
- Create: `CashFlow/Assets.xcassets/SemanticDanger.colorset/Contents.json`
- Create: `CashFlow/Assets.xcassets/SemanticDebt.colorset/Contents.json`
- Create: `CashFlow/Assets.xcassets/SurfaceGradientTop.colorset/Contents.json`
- Create: `CashFlow/Assets.xcassets/SurfaceGradientBottom.colorset/Contents.json`

- [ ] **Step 1: Create BrandGreen colorset**

`CashFlow/Assets.xcassets/BrandGreen.colorset/Contents.json`:
```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.451", "green" : "0.871", "red" : "0.290" }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [{ "appearance" : "luminosity", "value" : "dark" }],
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.400", "green" : "0.900", "red" : "0.220" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 2: Create surface and text colorsets**

Use this template pattern for each file — adjust RGB values per token:

| Colorset | Light (universal) | Dark (luminosity: dark) |
|----------|-------------------|-------------------------|
| `SurfacePrimary` | `#F5F5F7` (0.961, 0.961, 0.969) | `#0D0F14` (0.051, 0.059, 0.078) |
| `SurfaceSecondary` | `#FFFFFF` (1, 1, 1) | `#161922` (0.086, 0.098, 0.133) |
| `SurfaceElevated` | `#FFFFFF` (1, 1, 1) | `#1C2030` (0.110, 0.125, 0.188) |
| `TextPrimary` | `#1D1D1F` (0.114, 0.114, 0.122) | `#F9FAFB` (0.976, 0.980, 0.984) |
| `TextSecondary` | `#6B7280` (0.420, 0.447, 0.502) | `#9CA3AF` (0.612, 0.639, 0.686) |
| `TextTertiary` | `#9CA3AF` (0.612, 0.639, 0.686) | `#6B7280` (0.420, 0.447, 0.502) |
| `SurfaceGradientTop` | same as SurfacePrimary light | same as SurfacePrimary dark |
| `SurfaceGradientBottom` | `#FAFAFA` (0.980, 0.980, 0.980) | `#111520` (0.067, 0.082, 0.125) |

Example `SurfacePrimary.colorset/Contents.json`:
```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.969", "green" : "0.961", "red" : "0.961" }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [{ "appearance" : "luminosity", "value" : "dark" }],
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.078", "green" : "0.059", "red" : "0.051" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 3: Create semantic colorsets**

| Colorset | Light | Dark |
|----------|-------|------|
| `SemanticIncome` | `#22C55E` (0.133, 0.773, 0.369) | `#4ADE80` (0.290, 0.871, 0.502) |
| `SemanticExpense` | `#EF4444` (0.937, 0.267, 0.267) | `#F87171` (0.973, 0.443, 0.443) |
| `SemanticWarning` | `#F59E0B` (0.961, 0.620, 0.043) | `#FBBF24` (0.984, 0.749, 0.141) |
| `SemanticDanger` | `#DC2626` (0.863, 0.149, 0.149) | `#EF4444` (0.937, 0.267, 0.267) |
| `SemanticDebt` | `#EC4899` (0.925, 0.282, 0.600) | `#F472B6` (0.957, 0.447, 0.714) |

- [ ] **Step 4: Build to verify assets compile**

Run: `xcodebuild -scheme CashFlow -project CashFlow.xcodeproj -destination 'platform=macOS' build 2>&1 | tail -20`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add CashFlow/Assets.xcassets/
git commit -m "feat: add semantic color tokens for visual redesign"
```

---

### Task 2: Theme and Motion Foundation

**Files:**
- Create: `CashFlow/Shared/DesignSystem/Theme.swift`
- Create: `CashFlow/Shared/DesignSystem/Motion.swift`
- Create: `CashFlow/Shared/DesignSystem/CFPageBackground.swift`

- [ ] **Step 1: Create Theme.swift**

```swift
import SwiftUI

enum CFTheme {
    // MARK: - Colors

    static let brandGreen = Color("BrandGreen")
    static let surfacePrimary = Color("SurfacePrimary")
    static let surfaceSecondary = Color("SurfaceSecondary")
    static let surfaceElevated = Color("SurfaceElevated")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textTertiary = Color("TextTertiary")
    static let income = Color("SemanticIncome")
    static let expense = Color("SemanticExpense")
    static let warning = Color("SemanticWarning")
    static let danger = Color("SemanticDanger")
    static let debt = Color("SemanticDebt")
    static let gradientTop = Color("SurfaceGradientTop")
    static let gradientBottom = Color("SurfaceGradientBottom")

    // MARK: - Typography

    static func heroAmount() -> Font {
        .system(size: 44, weight: .semibold, design: .rounded).monospacedDigit()
    }

    static func title() -> Font {
        .system(size: 22, weight: .semibold)
    }

    static func headline() -> Font {
        .system(size: 17, weight: .semibold)
    }

    static func body() -> Font {
        .system(size: 15)
    }

    static func caption() -> Font {
        .system(size: 12)
    }

    static func kpiValue() -> Font {
        .system(size: 15, weight: .medium, design: .rounded).monospacedDigit()
    }

    // MARK: - Spacing & Radius

    static let cardRadius: CGFloat = 16
    static let cardPadding: CGFloat = 20
    static let rowRadius: CGFloat = 10
    static let iconSize: CGFloat = 34

    // MARK: - Pace state color

    static func paceColor(for state: PaceState) -> Color {
        switch state {
        case .underspending: return Color.blue
        case .onTrack: return income
        case .warning: return warning
        case .danger: return danger
        }
    }
}

// MARK: - View Modifiers

struct CFPageBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                LinearGradient(
                    colors: [CFTheme.gradientTop, CFTheme.gradientBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
    }
}

extension View {
    func cfPageBackground() -> some View {
        modifier(CFPageBackgroundModifier())
    }
}
```

- [ ] **Step 2: Create Motion.swift**

```swift
import SwiftUI

enum CFMotion {
    static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let bouncy = Animation.spring(response: 0.50, dampingFraction: 0.70)
    static let gentle = Animation.spring(response: 0.60, dampingFraction: 0.90)

    static func staggerDelay(index: Int, reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : Double(index) * 0.05
    }

    static func animation(_ preset: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : preset
    }
}

struct CFStaggerAppear: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .onAppear {
                let delay = CFMotion.staggerDelay(index: index, reduceMotion: reduceMotion)
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(CFMotion.bouncy.delay(delay)) {
                        appeared = true
                    }
                }
            }
    }
}

extension View {
    func cfStaggerAppear(index: Int) -> some View {
        modifier(CFStaggerAppear(index: index))
    }
}
```

- [ ] **Step 3: Create CFPageBackground.swift** (thin wrapper view for reuse)

```swift
import SwiftUI

struct CFPageBackground<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .cfPageBackground()
    }
}
```

- [ ] **Step 4: Build**

Run: `xcodebuild -scheme CashFlow -project CashFlow.xcodeproj -destination 'platform=macOS' build 2>&1 | tail -20`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add CashFlow/Shared/DesignSystem/
git commit -m "feat: add Theme and Motion design system foundation"
```

---

### Task 3: Base Components (Part 1 — Cards, Badges, Amounts)

**Files:**
- Create: `CashFlow/Shared/DesignSystem/CFGlassCard.swift`
- Create: `CashFlow/Shared/DesignSystem/CFIconBadge.swift`
- Create: `CashFlow/Shared/DesignSystem/CFAnimatedAmount.swift`
- Create: `CashFlow/Shared/DesignSystem/CFProgressBar.swift`

- [ ] **Step 1: Create CFGlassCard.swift**

```swift
import SwiftUI

struct CFGlassCard<Content: View>: View {
    var title: String?
    var subtitle: String?
    var padding: CGFloat = CFTheme.cardPadding
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title)
                            .font(CFTheme.headline())
                            .foregroundStyle(CFTheme.textPrimary)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(CFTheme.caption())
                            .foregroundStyle(CFTheme.textSecondary)
                    }
                }
            }
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { cardBackground }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if colorScheme == .dark {
            RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                        .fill(CFTheme.brandGreen.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        } else {
            RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                .fill(CFTheme.surfaceSecondary)
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                )
        }
    }
}
```

- [ ] **Step 2: Create CFIconBadge.swift**

```swift
import SwiftUI

struct CFIconBadge: View {
    let symbolName: String
    var tint: Color
    var size: CGFloat = CFTheme.iconSize
    var cornerRadius: CGFloat? = nil // nil = circle

    var body: some View {
        let iconFontSize = size * 0.42
        let radius = cornerRadius ?? size / 2

        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint.opacity(0.16))
                .frame(width: size, height: size)
            Image(systemName: symbolName)
                .font(.system(size: iconFontSize, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
    }
}
```

- [ ] **Step 3: Create CFAnimatedAmount.swift**

```swift
import SwiftUI

struct CFAnimatedAmount: View {
    let amount: Decimal
    var font: Font = CFTheme.heroAmount()
    var color: Color = CFTheme.textPrimary
    var prefix: String = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("\(prefix)\(amount.brl)")
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText())
            .animation(reduceMotion ? nil : CFMotion.gentle, value: amount)
    }
}
```

- [ ] **Step 4: Create CFProgressBar.swift**

```swift
import SwiftUI

struct CFProgressBar: View {
    let progress: Double // 0...1 for display width
    var color: Color = CFTheme.brandGreen
    var height: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(CFTheme.textTertiary.opacity(0.15))
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: max(4, geo.size.width * min(animatedProgress, 1)))
            }
        }
        .frame(height: height)
        .onAppear {
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(CFMotion.bouncy.delay(0.1)) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(reduceMotion ? nil : CFMotion.gentle) {
                animatedProgress = newValue
            }
        }
    }
}
```

- [ ] **Step 5: Build and commit**

```bash
xcodebuild -scheme CashFlow -project CashFlow.xcodeproj -destination 'platform=macOS' build 2>&1 | tail -20
git add CashFlow/Shared/DesignSystem/CFGlassCard.swift CashFlow/Shared/DesignSystem/CFIconBadge.swift CashFlow/Shared/DesignSystem/CFAnimatedAmount.swift CashFlow/Shared/DesignSystem/CFProgressBar.swift
git commit -m "feat: add CFGlassCard, CFIconBadge, CFAnimatedAmount, CFProgressBar"
```

---

### Task 4: Base Components (Part 2 — Tiles, Buttons, Empty States, Inputs, Hover)

**Files:**
- Create: `CashFlow/Shared/DesignSystem/CFMetricTile.swift`
- Create: `CashFlow/Shared/DesignSystem/CFPillButton.swift`
- Create: `CashFlow/Shared/DesignSystem/CFEmptyState.swift`
- Create: `CashFlow/Shared/DesignSystem/CFInputField.swift`
- Create: `CashFlow/Shared/DesignSystem/CFHoverRow.swift`

- [ ] **Step 1: Create CFMetricTile.swift**

```swift
import SwiftUI

struct CFMetricTile: View {
    let label: String
    let amount: Decimal
    let icon: String
    var tint: Color = CFTheme.brandGreen

    var body: some View {
        HStack(spacing: 10) {
            CFIconBadge(symbolName: icon, tint: tint, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
                CFAnimatedAmount(amount: amount, font: CFTheme.kpiValue(), color: CFTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 2: Create CFPillButton.swift**

```swift
import SwiftUI

enum CFPillStyle { case primary, ghost, destructive }

struct CFPillButton: View {
    let title: String
    var icon: String? = nil
    var style: CFPillStyle = .primary
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
            .scaleEffect(isHovered ? 1.02 : 1)
            .animation(CFMotion.snappy, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            Capsule().fill(CFTheme.brandGreen)
        case .ghost:
            Capsule().fill(CFTheme.textTertiary.opacity(isHovered ? 0.15 : 0.08))
        case .destructive:
            Capsule().fill(CFTheme.danger.opacity(0.12))
        }
    }

    private var foreground: Color {
        switch style {
        case .primary: return .white
        case .ghost: return CFTheme.textSecondary
        case .destructive: return CFTheme.danger
        }
    }
}
```

- [ ] **Step 3: Create CFEmptyState.swift**

```swift
import SwiftUI

struct CFEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 48, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    LinearGradient(
                        colors: [CFTheme.brandGreen, CFTheme.brandGreen.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 6) {
                Text(title)
                    .font(CFTheme.headline())
                    .foregroundStyle(CFTheme.textPrimary)
                Text(message)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            if let actionTitle, let action {
                CFPillButton(title: actionTitle, icon: "plus", style: .primary, action: action)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
```

- [ ] **Step 4: Create CFInputField.swift and CFHoverRow.swift**

`CFInputField.swift`:
```swift
import SwiftUI

struct CFInputField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(CFTheme.body())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(CFTheme.surfaceElevated.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isFocused ? CFTheme.brandGreen : CFTheme.textTertiary.opacity(0.2), lineWidth: isFocused ? 1.5 : 0.5)
                )
                .focused($isFocused)
                .animation(CFMotion.snappy, value: isFocused)
        }
    }
}
```

`CFHoverRow.swift`:
```swift
import SwiftUI

struct CFHoverRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: CFTheme.rowRadius, style: .continuous)
                    .fill(rowBackground)
            )
            .scaleEffect(isHovered ? 1.005 : 1)
            .shadow(color: .black.opacity(isHovered ? 0.06 : 0), radius: 8, x: 0, y: 2)
            .animation(CFMotion.snappy, value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if isHovered {
            return colorScheme == .dark
                ? Color.white.opacity(0.06)
                : Color.black.opacity(0.04)
        }
        return .clear
    }
}
```

- [ ] **Step 5: Build and commit**

```bash
xcodebuild -scheme CashFlow -project CashFlow.xcodeproj -destination 'platform=macOS' build 2>&1 | tail -20
git add CashFlow/Shared/DesignSystem/
git commit -m "feat: add CFMetricTile, CFPillButton, CFEmptyState, CFInputField, CFHoverRow"
```

---

### Task 5: Dashboard Rebuild

**Files:**
- Modify: `CashFlow/Features/Dashboard/MonthDashboardView.swift` (full rewrite of visual layer)
- Modify: `CashFlow/Features/Dashboard/CategoryBreakdownCard.swift`
- Modify: `CashFlow/Features/Dashboard/AccountBreakdownCard.swift`
- Delete or deprecate: `CashFlow/Features/Dashboard/DashboardCard.swift` (replaced by `CFGlassCard`)

- [ ] **Step 1: Replace `DashboardCard` usages with `CFGlassCard`**

In `CategoryBreakdownCard.swift`, change wrapper from `DashboardCard` to `CFGlassCard`. Replace inline icon circles with `CFIconBadge`. Replace inline progress bars with `CFProgressBar`. Use `CFTheme.expense` instead of `.red`/`.accentColor`.

In `AccountBreakdownCard.swift`, use `CFIconBadge` with `cornerRadius: 7`. Use `CFTheme.debt` instead of `.pink`.

- [ ] **Step 2: Rebuild `MonthDashboardView` layout**

Key changes to `MonthDashboardView`:

1. Wrap `dashboardScroll` in `.cfPageBackground()`
2. Replace `DashboardCard` in `HeroKPIsCard` with `CFGlassCard(padding: 24)`
3. Hero balance: `CFAnimatedAmount(amount: liquidBalance, color: liquidBalance >= 0 ? CFTheme.textPrimary : CFTheme.danger)`
4. KPI tiles: use `CFMetricTile` with semantic tints (`CFTheme.income`, `CFTheme.expense`, `CFTheme.debt`)
5. Budget button: `CFPillButton(title: ..., icon: ..., style: .ghost) { editingIncome.toggle() }`
6. Empty state: replace `ContentUnavailableView` with `CFEmptyState(symbol: "wallet.pass", title: "Comece criando uma conta", message: "...")`
7. Adaptive grid in `dashboardScroll`:

```swift
private var dashboardScroll: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            HeroKPIsCard(...)
                .cfStaggerAppear(index: 0)
                .id(referenceDate) // forces transition on month change

            if monthlyIncomeCents > 0 {
                ViewThatFits {
                    HStack(alignment: .top, spacing: 16) {
                        PaceCard(summary: summary)
                            .frame(maxWidth: .infinity)
                        CategoryBreakdownCard(...)
                            .frame(maxWidth: .infinity)
                    }
                    VStack(spacing: 16) {
                        PaceCard(summary: summary)
                        CategoryBreakdownCard(...)
                    }
                }
                .cfStaggerAppear(index: 1)
            } else {
                CategoryBreakdownCard(...)
                    .cfStaggerAppear(index: 1)
            }

            AccountBreakdownCard(...)
                .cfStaggerAppear(index: 2)
        }
        .padding(20)
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8)),
            removal: .opacity
        ))
        .animation(CFMotion.gentle, value: referenceDate)
    }
    .cfPageBackground()
}
```

8. `PaceCard`: replace `bar()` with `CFProgressBar`. Replace `paceColor` computed property to use `CFTheme.paceColor(for:)`. Add pulse on danger icon:

```swift
@State private var pulse = false
// on icon when summary.paceState == .danger:
.scaleEffect(pulse ? 1.08 : 1)
.onAppear { /* start repeating animation if danger */ }
```

9. `monthNavigator`: wrap in pill background:

```swift
HStack(spacing: 6) {
    // chevrons + month label
}
.padding(.horizontal, 12)
.padding(.vertical, 6)
.background(Capsule().fill(CFTheme.textTertiary.opacity(0.1)))
```

- [ ] **Step 3: Delete `DashboardCard.swift`** if no remaining references.

- [ ] **Step 4: Build and manually verify dashboard**

Run build command. Open app → Dashboard. Toggle macOS Appearance (Light/Dark). Navigate months — numbers should animate.

- [ ] **Step 5: Commit**

```bash
git add CashFlow/Features/Dashboard/
git commit -m "feat: rebuild dashboard with premium design system"
```

---

### Task 6: Transaction Timeline

**Files:**
- Modify: `CashFlow/Features/Transactions/TransactionListView.swift`
- Modify: `CashFlow/Features/Transactions/TransactionRow.swift`

- [ ] **Step 1: Replace List with ScrollView timeline in `TransactionListView`**

Replace `list` computed property:

```swift
private var list: some View {
    ScrollView {
        LazyVStack(spacing: 4, pinnedViews: [.sectionHeaders]) {
            ForEach(groupedByDay, id: \.0) { day, items in
                Section {
                    ForEach(items) { transaction in
                        CFHoverRow {
                            TransactionRow(transaction: transaction)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingTransaction = transaction }
                        .contextMenu {
                            Button { editingTransaction = transaction } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                modelContext.delete(transaction)
                            } label: {
                                Label("Excluir", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    dayHeader(for: day, total: dayTotal(items))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    .cfPageBackground()
}
```

Replace `sectionHeader` with sticky day header:

```swift
private func dayHeader(for day: Date, total: Decimal) -> some View {
    HStack {
        Text(dayHeader(day))
            .font(CFTheme.headline())
            .foregroundStyle(isRecentDay(day) ? CFTheme.brandGreen : CFTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(isRecentDay(day) ? CFTheme.brandGreen.opacity(0.12) : .clear)
            )
        Spacer()
        Text(total.brl)
            .font(CFTheme.kpiValue())
            .foregroundStyle(CFTheme.textSecondary)
    }
    .padding(.vertical, 8)
    .background(CFTheme.surfacePrimary.opacity(0.95))
}

private func isRecentDay(_ date: Date) -> Bool {
    Calendar.current.isDateInToday(date) || Calendar.current.isDateInYesterday(date)
}
```

Replace all three `ContentUnavailableView` empty states with `CFEmptyState` variants.

- [ ] **Step 2: Update `TransactionRow`**

```swift
struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 14) {
            CFIconBadge(
                symbolName: transaction.category?.symbolName ?? "questionmark.circle",
                tint: rowTint,
                size: CFTheme.iconSize
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.category?.name ?? "Sem categoria")
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                // account + note lines unchanged, use CFTheme.textSecondary / textTertiary
            }

            Spacer(minLength: 12)

            Text(formattedAmount)
                .font(CFTheme.body().weight(.medium))
                .monospacedDigit()
                .foregroundStyle(amountColor)
        }
    }

    private var rowTint: Color {
        transaction.kind == .expense ? CFTheme.expense : CFTheme.income
    }

    private var amountColor: Color {
        transaction.kind == .expense ? CFTheme.textPrimary : CFTheme.income
    }
    // formattedAmount unchanged
}
```

- [ ] **Step 3: Build, verify hover + context menu + edit sheet still work**

- [ ] **Step 4: Commit**

```bash
git add CashFlow/Features/Transactions/
git commit -m "feat: rebuild transaction list as custom timeline"
```

---

### Task 7: Categories and Accounts Lists

**Files:**
- Modify: `CashFlow/Features/Settings/CategoriesView.swift`
- Modify: `CashFlow/Features/Settings/AccountsView.swift`

- [ ] **Step 1: Replace `categoryList` with ScrollView**

```swift
private var categoryList: some View {
    ScrollView {
        LazyVStack(alignment: .leading, spacing: 16) {
            if !expenseCategories.isEmpty {
                categorySection(title: "Despesas", items: expenseCategories, tint: CFTheme.expense)
            }
            if !incomeCategories.isEmpty {
                categorySection(title: "Receitas", items: incomeCategories, tint: CFTheme.income)
            }
            if !archivedCategories.isEmpty {
                archivedSection
            }
        }
        .padding(20)
    }
    .cfPageBackground()
}

private func categorySection(title: String, items: [Category], tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(CFTheme.caption())
            .foregroundStyle(CFTheme.textSecondary)
            .textCase(.uppercase)
        ForEach(items) { category in
            CFHoverRow { categoryRowContent(category, tint: tint) }
                .onTapGesture { editingCategory = category }
                .contextMenu { /* existing archive/edit */ }
        }
    }
}
```

Extract row content from existing `categoryRow` into `categoryRowContent` using `CFIconBadge`. Replace empty state with `CFEmptyState`.

- [ ] **Step 2: Same pattern for `AccountsView`**

Use `CFAnimatedAmount` for balance display. `CFTheme.debt` for credit card balances. `CFHoverRow` wrapper. `CFEmptyState` for empty.

- [ ] **Step 3: Build and verify tap-to-edit, archive context menu**

- [ ] **Step 4: Commit**

```bash
git add CashFlow/Features/Settings/
git commit -m "feat: rebuild category and account lists with design system"
```

---

### Task 8: Sheets Redesign

**Files:**
- Modify: `CashFlow/Features/Transactions/AddTransactionSheet.swift`
- Modify: `CashFlow/Features/Settings/CategoriesView.swift` (`CategorySheet`)
- Modify: `CashFlow/Features/Settings/AccountsView.swift` (`AccountSheet`)
- Modify: `CashFlow/Shared/TransactionKindSwitcher.swift`
- Modify: `CashFlow/Shared/CurrencyField.swift`
- Modify: `CashFlow/Shared/IconPickerField.swift`

- [ ] **Step 1: Add presentation background to all sheets**

On each sheet root view:
```swift
.presentationBackground(.ultraThinMaterial)
```

- [ ] **Step 2: Update `TransactionKindSwitcher`**

Replace `.red`/`.green` with `CFTheme.expense`/`CFTheme.income`. Use `CFMotion.snappy` for animation value.

- [ ] **Step 3: Update `AddTransactionSheet` header**

- Amount field: `.font(.system(size: 42, weight: .semibold, design: .rounded))`
- Color: `draft.kind == .expense ? CFTheme.textPrimary : CFTheme.income`
- Replace form sections with labeled custom rows using `CFInputField` where applicable
- Footer: `CFPillButton` for Cancel (ghost) and Save (primary)

- [ ] **Step 4: Update `CategorySheet` and `AccountSheet`**

- Hero: replace manual ZStack with `CFIconBadge` at size 64 + colored shadow
- Replace `Form` fields: name uses `CFInputField`; keep `Picker`/`ColorPicker`/`IconPickerField`/`CurrencyField`/`DateField` but wrap sections in `VStack` with `CFTheme` spacing
- Footer: same `CFPillButton` pattern

- [ ] **Step 5: Update `CurrencyField` focus ring**

Add optional focus state with green border matching `CFInputField` when focused.

- [ ] **Step 6: Build, verify all three sheets open/save/archive correctly**

- [ ] **Step 7: Commit**

```bash
git add CashFlow/Features/Transactions/AddTransactionSheet.swift CashFlow/Features/Settings/ CashFlow/Shared/
git commit -m "feat: redesign sheets with custom layout and design system"
```

---

### Task 9: Sidebar Bridge and Root App Styling

**Files:**
- Modify: `CashFlow/App/RootSidebarView.swift`
- Modify: `CashFlow/CashFlowApp.swift`

- [ ] **Step 1: Update `RootSidebarView`**

```swift
// Change .tint(Color("BrandTint")) to:
.tint(CFTheme.brandGreen)
.background(CFTheme.surfacePrimary)
```

Do NOT change sidebar List structure, sections, or selection logic.

- [ ] **Step 2: Update `CashFlowApp`**

No functional changes. Optionally set default appearance — do NOT force dark mode since spec requires system-adaptive.

- [ ] **Step 3: Migrate remaining hardcoded colors project-wide**

Search and replace in all view files:
```
.foregroundStyle(.green)     → CFTheme.income (where semantic)
.foregroundStyle(.red)       → CFTheme.expense or CFTheme.danger (context-dependent)
.foregroundStyle(.pink)      → CFTheme.debt
.foregroundStyle(.orange)    → CFTheme.warning
Color("BrandTint")           → CFTheme.brandGreen
```

Run: `rg '\.(green|red|pink|orange|blue)' CashFlow/ --glob '*.swift'` and fix remaining non-semantic usages.

- [ ] **Step 4: Build and commit**

```bash
git add CashFlow/App/ CashFlow/CashFlowApp.swift
git commit -m "feat: apply sidebar bridge styling and migrate semantic colors"
```

---

### Task 10: Polish Pass and Accessibility

**Files:**
- Modify: any views missing `@Environment(\.accessibilityReduceMotion)` handling

- [ ] **Step 1: Audit reduce-motion**

Verify these respect `accessibilityReduceMotion`:
- `CFStaggerAppear` ✓ (built-in)
- `CFAnimatedAmount` ✓ (built-in)
- `CFProgressBar` ✓ (built-in)
- Month change transition in `MonthDashboardView` — wrap `.animation(CFMotion.gentle, value: referenceDate)`:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
// ...
.animation(reduceMotion ? nil : CFMotion.gentle, value: referenceDate)
```

- Pace danger pulse — skip when `reduceMotion`

- [ ] **Step 2: Run full spec testing checklist**

Manual verification in Xcode:
1. System Settings → Appearance → Light: all 4 screens + 3 sheets
2. Appearance → Dark: same
3. Appearance → Auto: toggle and confirm switch
4. Dashboard at 900px+ width: Pace + Category side-by-side
5. Dashboard at 700px width: stacked
6. Month navigation: animated numbers
7. Transaction list: scroll 50+ items smoothly
8. Hover rows on macOS
9. System Settings → Accessibility → Reduce motion: no stagger/pulse
10. Sidebar selection unchanged

- [ ] **Step 3: Add `.superpowers/` to `.gitignore`** (if not present)

```
.superpowers/
```

- [ ] **Step 4: Final commit**

```bash
git add .
git commit -m "feat: polish motion accessibility and complete visual redesign"
```

---

## Spec Coverage Check

| Spec Requirement | Task |
|-----------------|------|
| Color tokens (14 colorsets) | Task 1 |
| Theme.swift typography/spacing | Task 2 |
| Motion presets + reduce motion | Task 2, Task 10 |
| CFGlassCard | Task 3 |
| CFMetricTile, CFProgressBar, CFIconBadge, CFAnimatedAmount | Task 3–4 |
| CFPillButton, CFEmptyState, CFInputField | Task 4 |
| Dashboard adaptive grid + hero + pace + breakdowns | Task 5 |
| Transaction timeline + hover rows | Task 6 |
| Categories/Accounts custom lists | Task 7 |
| Sheets custom layout | Task 8 |
| Sidebar native + bridge | Task 9 |
| Semantic color migration | Task 9 |
| Reduce motion audit | Task 10 |
| No model/persistence changes | All tasks (view layer only) |

---

## Out of Scope (do not implement)

- Model or SwiftData schema changes
- New features
- Custom sidebar replacement
- iOS target
- Unit test target creation
- Red focus ring on invalid fields
