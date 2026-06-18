import Combine
import SwiftUI

/// App-wide toggle for hiding monetary values from the screen. Useful when the user
/// is in a public space and doesn't want balances/amounts visible to people nearby.
/// Persisted via `@AppStorage` so the state survives launches.
@MainActor
final class PrivacyMode: ObservableObject {
    private static let storageKey = "privacy.valuesHidden"

    @Published var valuesHidden: Bool {
        didSet {
            UserDefaults.standard.set(valuesHidden, forKey: Self.storageKey)
        }
    }

    init() {
        self.valuesHidden = UserDefaults.standard.bool(forKey: Self.storageKey)
    }

    func toggle() {
        valuesHidden.toggle()
    }

    var iconName: String {
        valuesHidden ? "eye.slash" : "eye"
    }

    var helpText: String {
        valuesHidden ? "Mostrar valores" : "Ocultar valores"
    }
}

struct PrivacyToggleToolbarButton: View {
    @EnvironmentObject private var privacy: PrivacyMode

    var body: some View {
        Button {
            privacy.toggle()
        } label: {
            Image(systemName: privacy.iconName)
        }
        .help(privacy.helpText)
    }
}

/// Visual placeholder used everywhere a monetary value is hidden.
enum PrivacyMaskedAmount {
    static let placeholder = "R$ ••••"
}

extension Decimal {
    /// Returns the standard BRL string, or a placeholder when `isHidden` is true.
    func brl(masked isHidden: Bool) -> String {
        isHidden ? PrivacyMaskedAmount.placeholder : brl
    }
}

private struct PrivacyRedactedModifier: ViewModifier {
    @EnvironmentObject private var privacy: PrivacyMode

    func body(content: Content) -> some View {
        content.redacted(reason: privacy.valuesHidden ? .placeholder : [])
    }
}

extension View {
    /// Visually redacts the wrapped subtree (shows placeholder blocks) when the
    /// user has enabled `PrivacyMode.valuesHidden`. Use on containers that have
    /// raw `Text(amount.brl)` we don't want to rewrite individually.
    func privacyRedacted() -> some View {
        modifier(PrivacyRedactedModifier())
    }
}
