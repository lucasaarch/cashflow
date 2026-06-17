import Combine
import SwiftUI

@MainActor
final class AIChatPanelState: ObservableObject {
    @Published var isOpen = false

    func toggle() { isOpen.toggle() }
    func close() { isOpen = false }
    func open() { isOpen = true }
}
