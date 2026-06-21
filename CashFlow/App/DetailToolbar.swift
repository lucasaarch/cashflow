import SwiftUI

struct DetailToolbarAddAction: Equatable {
    var help: String = ""
    var disabled: Bool = false
    let id: UUID
    let action: () -> Void

    init(help: String = "", disabled: Bool = false, action: @escaping () -> Void) {
        self.help = help
        self.disabled = disabled
        self.id = UUID()
        self.action = action
    }

    static func == (lhs: DetailToolbarAddAction, rhs: DetailToolbarAddAction) -> Bool {
        lhs.id == rhs.id && lhs.help == rhs.help && lhs.disabled == rhs.disabled
    }
}

struct DetailToolbarAddPreferenceKey: PreferenceKey {
    static var defaultValue: DetailToolbarAddAction? = nil

    static func reduce(value: inout DetailToolbarAddAction?, nextValue: () -> DetailToolbarAddAction?) {
        if let next = nextValue() {
            value = next
        }
    }
}

extension View {
    /// Optional trailing "+" for screens that create records. Rendered first in the global toolbar.
    func detailToolbarAdd(
        help: String = "",
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        preference(
            key: DetailToolbarAddPreferenceKey.self,
            value: DetailToolbarAddAction(help: help, disabled: disabled, action: action)
        )
    }
}

extension ToolbarContent {
    /// Evita o chip glass compartilhado da toolbar (macOS/iOS 26), que clipa botões customizados.
    @ToolbarContentBuilder
    func cfHideToolbarSharedBackgroundIfAvailable() -> some ToolbarContent {
        if #available(macOS 26.0, iOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

/// Ações globais à direita — um `ToolbarItem` por botão, cada um com cápsula glass própria.
struct DetailToolbarItems: ToolbarContent {
    var addAction: DetailToolbarAddAction?

    @EnvironmentObject private var chatPanelState: AIChatPanelState
    @Environment(\.cfLayoutMode) private var layoutMode

    private var showsInspectorChatTools: Bool {
        layoutMode == .regular && chatPanelState.isOpen
    }

    var body: some ToolbarContent {
        if let addAction {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addAction.action) {
                    Label("Adicionar", systemImage: "plus")
                }
                .cfGlassToolbarAddButton()
                .disabled(addAction.disabled)
                .help(addAction.help)
            }
            .cfHideToolbarSharedBackgroundIfAvailable()
        }

        ToolbarItem(placement: .primaryAction) {
            SpotlightToolbarButton()
        }
        .cfHideToolbarSharedBackgroundIfAvailable()

        if showsInspectorChatTools {
            ToolbarItem(placement: .primaryAction) {
                AIChatInspectorToolbarCapsule()
            }
            .cfHideToolbarSharedBackgroundIfAvailable()
        }

        ToolbarItem(placement: .primaryAction) {
            AIChatToolbarButton()
        }
        .cfHideToolbarSharedBackgroundIfAvailable()
    }
}
