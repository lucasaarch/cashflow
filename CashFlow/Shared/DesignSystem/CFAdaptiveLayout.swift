import SwiftUI

enum CFLayoutMode {
    case compact
    case regular
}

private struct CFLayoutModeKey: EnvironmentKey {
    static let defaultValue: CFLayoutMode = .regular
}

extension EnvironmentValues {
    var cfLayoutMode: CFLayoutMode {
        get { self[CFLayoutModeKey.self] }
        set { self[CFLayoutModeKey.self] = newValue }
    }
}

extension View {
    /// Applies fixed sheet dimensions on regular layouts; full width on compact.
    func cfAdaptiveSheetFrame(width: CGFloat, height: CGFloat) -> some View {
        modifier(CFAdaptiveSheetFrameModifier(width: width, height: height))
    }

    /// Hides custom footers on compact and exposes toolbar actions instead.
    func cfAdaptiveSheetFooterVisible() -> some View {
        modifier(CFAdaptiveSheetFooterVisibilityModifier())
    }

    /// Navigation toolbar with Cancel/Save for compact sheet layouts.
    func cfCompactSheetToolbar(
        title: String,
        cancelTitle: String = "Cancelar",
        saveTitle: String = "Salvar",
        saveDisabled: Bool = false,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) -> some View {
        modifier(
            CFCompactSheetToolbarModifier(
                title: title,
                cancelTitle: cancelTitle,
                saveTitle: saveTitle,
                saveDisabled: saveDisabled,
                onCancel: onCancel,
                onSave: onSave
            )
        )
    }

    /// Sheet detents on compact iOS; no-op elsewhere.
    func cfAdaptiveSheetDetents() -> some View {
        modifier(CFAdaptiveSheetDetentsModifier())
    }

    /// Popover on macOS/regular; sheet on compact.
    func cfAdaptivePicker<PickerContent: View>(
        isPresented: Binding<Bool>,
        arrowEdge: Edge = .top,
        sheetTitle: String = "Selecionar",
        @ViewBuilder content: @escaping () -> PickerContent
    ) -> some View {
        modifier(
            CFAdaptivePickerModifier(
                isPresented: isPresented,
                arrowEdge: arrowEdge,
                sheetTitle: sheetTitle,
                pickerContent: content
            )
        )
    }
}

extension View {
    /// Wraps sheet content in NavigationStack on compact layouts.
    func cfAdaptiveSheetNavigation() -> some View {
        modifier(CFAdaptiveSheetNavigationModifier())
    }
}

private struct CFAdaptiveSheetNavigationModifier: ViewModifier {
    @Environment(\.cfLayoutMode) private var layoutMode

    func body(content: Content) -> some View {
        if layoutMode == .compact {
            NavigationStack { content }
        } else {
            content
        }
    }
}

private enum CFCompactLayout {
    static func isCompact(layoutMode: CFLayoutMode, horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
        layoutMode == .compact || horizontalSizeClass == .compact
    }
}

private struct CFAdaptiveSheetFrameModifier: ViewModifier {
    @Environment(\.cfLayoutMode) private var layoutMode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let width: CGFloat
    let height: CGFloat

    private var isCompact: Bool {
        CFCompactLayout.isCompact(layoutMode: layoutMode, horizontalSizeClass: horizontalSizeClass)
    }

    func body(content: Content) -> some View {
        if isCompact {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            content
                .frame(width: width, height: height)
        }
    }
}

private struct CFAdaptiveSheetFooterVisibilityModifier: ViewModifier {
    @Environment(\.cfLayoutMode) private var layoutMode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        CFCompactLayout.isCompact(layoutMode: layoutMode, horizontalSizeClass: horizontalSizeClass)
    }

    func body(content: Content) -> some View {
        if isCompact {
            EmptyView()
        } else {
            content
        }
    }
}

private struct CFCompactSheetToolbarModifier: ViewModifier {
    @Environment(\.cfLayoutMode) private var layoutMode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let cancelTitle: String
    let saveTitle: String
    let saveDisabled: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    private var isCompact: Bool {
        CFCompactLayout.isCompact(layoutMode: layoutMode, horizontalSizeClass: horizontalSizeClass)
    }

    func body(content: Content) -> some View {
        if isCompact {
            content
                .navigationTitle(title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(cancelTitle, action: onCancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(saveTitle, action: onSave)
                            .disabled(saveDisabled)
                    }
                }
        } else {
            content
        }
    }
}

private struct CFAdaptiveSheetDetentsModifier: ViewModifier {
    @Environment(\.cfLayoutMode) private var layoutMode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        CFCompactLayout.isCompact(layoutMode: layoutMode, horizontalSizeClass: horizontalSizeClass)
    }

    func body(content: Content) -> some View {
        #if os(iOS)
        if isCompact {
            content
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

private struct CFAdaptivePickerModifier<PickerContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    var arrowEdge: Edge
    var sheetTitle: String
    @ViewBuilder var pickerContent: () -> PickerContent

    @Environment(\.cfLayoutMode) private var layoutMode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if usesPopover {
            content
                .popover(isPresented: $isPresented, arrowEdge: arrowEdge) {
                    pickerContent()
                        .presentationBackground(CFTheme.surfacePrimary)
                }
        } else {
            content
                .sheet(isPresented: $isPresented) {
                    NavigationStack {
                        ScrollView {
                            pickerContent()
                        }
                        .navigationTitle(sheetTitle)
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Fechar") { isPresented = false }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(CFTheme.surfacePrimary)
                }
        }
    }

    private var usesPopover: Bool {
        #if os(macOS)
        true
        #else
        !CFCompactLayout.isCompact(layoutMode: layoutMode, horizontalSizeClass: horizontalSizeClass)
        #endif
    }
}
