#if os(macOS)
import SwiftUI

enum SpotlightFocusRunner {
    @MainActor
    static func reveal(
        id: UUID,
        proxy: ScrollViewProxy,
        setHighlight: @escaping (UUID?) -> Void,
        openDetailOnFocus: Bool,
        onReveal: @escaping () -> Void,
        clearNavigation: @escaping () -> Void
    ) -> Task<Void, Never> {
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            setHighlight(id)
            withAnimation(CFMotion.snappy) {
                proxy.scrollTo(id, anchor: .center)
            }

            if openDetailOnFocus {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                onReveal()
            }

            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            setHighlight(nil)
            clearNavigation()
        }
    }
}

private struct SpotlightRowHighlightModifier: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: CFTheme.rowRadius, style: .continuous)
                    .strokeBorder(CFTheme.accent.opacity(isFocused ? 0.85 : 0), lineWidth: 2)
                    .animation(CFMotion.snappy, value: isFocused)
            }
            .background {
                RoundedRectangle(cornerRadius: CFTheme.rowRadius, style: .continuous)
                    .fill(CFTheme.accent.opacity(isFocused ? 0.14 : 0))
                    .animation(CFMotion.snappy, value: isFocused)
            }
    }
}

extension View {
    func spotlightFocused(_ isFocused: Bool) -> some View {
        modifier(SpotlightRowHighlightModifier(isFocused: isFocused))
    }

    func spotlightScrollTarget(
        navigation: SpotlightNavigationState,
        kind: SpotlightTargetKind,
        highlightedID: Binding<UUID?>,
        focusTask: Binding<Task<Void, Never>?>,
        proxy: ScrollViewProxy,
        onReveal: @escaping (UUID) -> Void
    ) -> some View {
        spotlightScrollTarget(
            activeTarget: navigation.activeTarget,
            extractID: { $0.entityID(matching: kind) },
            openDetailOnFocus: navigation.openDetailOnFocus,
            highlightedID: highlightedID,
            focusTask: focusTask,
            proxy: proxy,
            onReveal: onReveal,
            clearNavigation: navigation.clearTarget
        )
    }

    func spotlightScrollTarget(
        activeTarget: SpotlightTarget?,
        extractID: @escaping (SpotlightTarget) -> UUID?,
        openDetailOnFocus: Bool,
        highlightedID: Binding<UUID?>,
        focusTask: Binding<Task<Void, Never>?>,
        proxy: ScrollViewProxy,
        onReveal: @escaping (UUID) -> Void,
        clearNavigation: @escaping () -> Void
    ) -> some View {
        onAppear {
            Task { @MainActor in
                runSpotlightFocus(
                    activeTarget,
                    extractID: extractID,
                    openDetailOnFocus: openDetailOnFocus,
                    highlightedID: highlightedID,
                    focusTask: focusTask,
                    proxy: proxy,
                    onReveal: onReveal,
                    clearNavigation: clearNavigation
                )
            }
        }
        .onChange(of: activeTarget) { _, target in
            Task { @MainActor in
                runSpotlightFocus(
                    target,
                    extractID: extractID,
                    openDetailOnFocus: openDetailOnFocus,
                    highlightedID: highlightedID,
                    focusTask: focusTask,
                    proxy: proxy,
                    onReveal: onReveal,
                    clearNavigation: clearNavigation
                )
            }
        }
        .onDisappear {
            focusTask.wrappedValue?.cancel()
        }
    }
}

@MainActor
private func runSpotlightFocus(
    _ target: SpotlightTarget?,
    extractID: (SpotlightTarget) -> UUID?,
    openDetailOnFocus: Bool,
    highlightedID: Binding<UUID?>,
    focusTask: Binding<Task<Void, Never>?>,
    proxy: ScrollViewProxy,
    onReveal: @escaping (UUID) -> Void,
    clearNavigation: @escaping () -> Void
) {
    guard let target, let id = extractID(target) else { return }

    focusTask.wrappedValue?.cancel()
    focusTask.wrappedValue = SpotlightFocusRunner.reveal(
        id: id,
        proxy: proxy,
        setHighlight: { highlightedID.wrappedValue = $0 },
        openDetailOnFocus: openDetailOnFocus,
        onReveal: { onReveal(id) },
        clearNavigation: clearNavigation
    )
}
#endif
