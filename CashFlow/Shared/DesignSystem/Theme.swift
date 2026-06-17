import SwiftUI
#if os(macOS)
import AppKit
#endif

enum CFTheme {
    /// User's macOS accent (System Settings → Appearance).
    static var accent: Color {
#if os(macOS)
        Color(nsColor: NSColor.controlAccentColor)
#else
        Color.accentColor
#endif
    }
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

    static func heroAmount() -> Font {
        .system(size: 44, weight: .semibold, design: .rounded).monospacedDigit()
    }
    static func title() -> Font { .system(size: 22, weight: .semibold) }
    static func headline() -> Font { .system(size: 17, weight: .semibold) }
    static func body() -> Font { .system(size: 15) }
    static func caption() -> Font { .system(size: 12) }
    static func kpiValue() -> Font {
        .system(size: 15, weight: .medium, design: .rounded).monospacedDigit()
    }

    static let cardRadius: CGFloat = 16
    static let cardPadding: CGFloat = 20
    static let rowRadius: CGFloat = 10
    static let iconSize: CGFloat = 34

    static func paceColor(for state: PaceState) -> Color {
        switch state {
        case .underspending: return Color.blue
        case .onTrack: return income
        case .warning: return warning
        case .danger: return danger
        }
    }
}

struct CFPageBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
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

    /// Solid neutral background for sheets — avoids green tint from `.ultraThinMaterial` vibrancy.
    func cfSheetBackground() -> some View {
        presentationBackground(CFTheme.surfacePrimary)
    }

    /// Compact chip styling for inline pickers (category, date, icon).
    func cfPickerChip() -> some View {
        font(CFTheme.body())
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(CFTheme.surfaceSecondary.opacity(0.8))
            )
    }

    /// Neutral field background + visible border, accent when focused.
    func cfFieldChrome(isFocused: Bool) -> some View {
        background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(CFTheme.surfaceElevated.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isFocused ? CFTheme.accent : CFTheme.textTertiary.opacity(0.28),
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .animation(CFMotion.snappy, value: isFocused)
    }

    /// Chip-sized field chrome for inline rows (matches `cfPickerChip` dimensions).
    func cfCompactFieldChrome(isFocused: Bool) -> some View {
        background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(CFTheme.surfaceSecondary.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isFocused ? CFTheme.accent : CFTheme.textTertiary.opacity(0.28),
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .animation(CFMotion.snappy, value: isFocused)
    }
}
