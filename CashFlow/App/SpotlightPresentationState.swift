import Combine
import SwiftUI

@MainActor
final class SpotlightPresentationState: ObservableObject {
    @Published private(set) var isPresented = false

    func open() {
        DispatchQueue.main.async { [self] in
            guard !isPresented else { return }
            withAnimation(CFMotion.quick) { isPresented = true }
        }
    }

    func close() {
        DispatchQueue.main.async { [self] in
            guard isPresented else { return }
            withAnimation(CFMotion.quick) { isPresented = false }
        }
    }

    func toggle() {
        if isPresented { close() } else { open() }
    }
}
