import SwiftUI

enum CFTheme {
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
}
