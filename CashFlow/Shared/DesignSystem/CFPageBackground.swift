import SwiftUI

struct CFPageBackground<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content().cfPageBackground()
    }
}
