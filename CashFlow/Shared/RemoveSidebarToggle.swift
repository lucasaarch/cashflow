#if os(macOS)
import AppKit
import SwiftUI

private enum SidebarToggleRemoval {
    static let itemID = NSToolbarItem.Identifier("com.apple.SwiftUI.navigationSplitView.toggleSidebar")

    static func removeFromKeyWindow() {
        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow ?? NSApp.mainWindow,
                  let toolbar = window.toolbar else { return }
            toolbar.removeItem(identifier: itemID)
        }
    }
}

struct RemoveSidebarToggleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { SidebarToggleRemoval.removeFromKeyWindow() }
            .background(SidebarToggleRemovalHost())
    }
}

/// Re-runs removal when the window toolbar is rebuilt (e.g. after navigation).
private struct SidebarToggleRemovalHost: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { SidebarToggleRemoval.removeFromKeyWindow() }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        SidebarToggleRemoval.removeFromKeyWindow()
    }
}

extension View {
    func removeSidebarToggleButton() -> some View {
        modifier(RemoveSidebarToggleModifier())
    }
}
#endif
