import SwiftUI
#if os(macOS)
import AppKit
#endif

#if os(macOS)
private final class CFScrollViewConfigHost: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyScrollStyle()
    }

    override func layout() {
        super.layout()
        applyScrollStyle()
    }

    fileprivate func applyScrollStyle() {
        guard let scrollView = enclosingScrollView else { return }

        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.verticalScroller?.controlSize = .mini
        scrollView.horizontalScroller?.controlSize = .mini
        scrollView.verticalScroller?.scrollerStyle = .overlay
        scrollView.horizontalScroller?.scrollerStyle = .overlay
        scrollView.verticalScroller?.alphaValue = 0.55
        scrollView.horizontalScroller?.alphaValue = 0.55
    }
}

private struct CFScrollViewConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> CFScrollViewConfigHost {
        let host = CFScrollViewConfigHost(frame: .zero)
        host.isHidden = true
        host.alphaValue = 0
        return host
    }

    func updateNSView(_ nsView: CFScrollViewConfigHost, context: Context) {
        DispatchQueue.main.async {
            nsView.applyScrollStyle()
        }
    }
}
#endif

/// Scroll view with overlay scrollbars on macOS and hidden system indicators.
struct CFScrollView<Content: View>: View {
    private let axes: Axis.Set
    @ViewBuilder private var content: () -> Content

    init(_ axes: Axis.Set = .vertical, @ViewBuilder content: @escaping () -> Content) {
        self.axes = axes
        self.content = content
    }

    var body: some View {
        ScrollView(axes) {
            content()
                .cfScrollContent()
        }
        .cfScrollChrome()
    }
}

extension View {
    /// Place on the root content inside a `ScrollView` (e.g. when using `ScrollViewReader`).
    func cfScrollContent() -> some View {
        background {
            #if os(macOS)
            CFScrollViewConfigurator()
            #endif
        }
    }

    /// Hides SwiftUI scroll indicators; pair with `cfScrollContent()` on macOS.
    func cfScrollChrome() -> some View {
        scrollIndicators(.hidden)
    }
}
