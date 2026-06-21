import Combine
import SwiftUI

@MainActor
final class SidebarNavigationState: ObservableObject {
    @Published var selection: SidebarDestination? = .dashboard

    func navigate(to destination: SidebarDestination) {
        DispatchQueue.main.async { [self] in
            guard selection != destination else { return }
            selection = destination
        }
    }
}
