import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Drag handle on the inner edge of a trailing side panel.
struct CFTrailingPanelResizeHandle: View {
    @Binding var width: CGFloat
    var range: ClosedRange<CGFloat> = 320...720
    var onDraggingChanged: ((Bool) -> Void)?
    var onDragEnded: ((CGFloat) -> Void)?

    @State private var dragStartWidth: CGFloat?
    @State private var isDragging = false
    @State private var isHovering = false
    #if os(macOS)
    @State private var isResizeCursorActive = false
    #endif

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 10)
            .overlay {
                Rectangle()
                    .fill(handleColor)
                    .frame(width: 1)
            }
            .contentShape(Rectangle())
            .offset(x: -5)
            #if os(macOS)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovering = true
                    activateResizeCursor()
                case .ended:
                    isHovering = false
                    updateResizeCursor()
                }
            }
            #else
            .onHover { hovering in
                isHovering = hovering
            }
            #endif
            .highPriorityGesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if dragStartWidth == nil {
                            dragStartWidth = width
                            isDragging = true
                            onDraggingChanged?(true)
                            #if os(macOS)
                            activateResizeCursor()
                            #endif
                        }
                        let start = dragStartWidth ?? width
                        let proposed = start - value.translation.width
                        width = min(max(proposed, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        let finalWidth = width
                        dragStartWidth = nil
                        isDragging = false
                        onDraggingChanged?(false)
                        onDragEnded?(finalWidth)
                        #if os(macOS)
                        updateResizeCursor()
                        #endif
                    }
            )
            .onDisappear {
                #if os(macOS)
                deactivateResizeCursor()
                #endif
            }
            .accessibilityLabel("Redimensionar painel")
            .accessibilityAddTraits(.isButton)
    }

    private var handleColor: Color {
        if isDragging || isHovering {
            return CFTheme.accent.opacity(0.55)
        }
        return CFTheme.textTertiary.opacity(0.22)
    }

    #if os(macOS)
    private func activateResizeCursor() {
        guard !isResizeCursorActive else { return }
        NSCursor.resizeLeftRight.push()
        isResizeCursorActive = true
    }

    private func deactivateResizeCursor() {
        guard isResizeCursorActive else { return }
        NSCursor.pop()
        isResizeCursorActive = false
    }

    private func updateResizeCursor() {
        if isDragging || isHovering {
            activateResizeCursor()
        } else {
            deactivateResizeCursor()
        }
    }
    #endif
}
