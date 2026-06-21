import SwiftUI

enum CFTheme {
    static let accent = Color("AccentColor")
    static let brandGreen = Color("BrandGreen")
    static let brandTint = Color("BrandTint")
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
    /// Mensagens e campo de entrada do chat Gio — alinhado ao corpo da sidebar (13pt no macOS).
    static func chatBody() -> Font { .system(size: 13) }
    /// Títulos compactos dentro do painel do chat.
    static func chatHeadline() -> Font { .system(size: 15, weight: .semibold) }
    static func caption() -> Font { .system(size: 12) }
    static func kpiValue() -> Font {
        .system(size: 15, weight: .medium, design: .rounded).monospacedDigit()
    }
    /// Secondary labels on dashboard stat chips and KPI rows.
    static func dashboardLabel() -> Font { .system(size: 13, weight: .medium) }
    /// Supporting dashboard copy — previsto, datas, detalhes de alerta.
    static func dashboardMeta() -> Font { .system(size: 13) }
    /// Emphasized amounts inside dashboard chips and compact rows.
    static func dashboardAmount() -> Font {
        .system(size: 15, weight: .semibold, design: .rounded).monospacedDigit()
    }

    static let cardRadius: CGFloat = 16
    static let cardPadding: CGFloat = 20
    static let rowRadius: CGFloat = 10
    static let iconSize: CGFloat = 34

    static func paceColor(for state: PaceState) -> Color {
        switch state {
        case .underspending: return accent
        case .onTrack: return income
        case .warning: return warning
        case .danger: return danger
        }
    }
}

struct CFPageBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            CFTheme.surfacePrimary
                .ignoresSafeArea()
        }
    }
}

extension View {
    func cfPageBackground() -> some View {
        modifier(CFPageBackgroundModifier())
    }

    /// Compact chip styling for inline pickers (category, date, icon, color).
    /// Uses inset material styling — not `glassEffect`, which crashes when nested inside
    /// `Button` labels within `CFGlassPanel` on macOS.
    func cfPickerChip() -> some View {
        self
            .font(CFTheme.body())
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(CFTheme.surfaceSecondary.opacity(0.55))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(CFTheme.textTertiary.opacity(0.24), lineWidth: 0.5)
            }
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
