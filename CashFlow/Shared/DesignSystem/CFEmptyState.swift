import SwiftUI

struct CFEmptyState: View {
    @State private var searchText: String = ""
    
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var onSearch: ((String) -> Void)? = nil
    var searchPrompt: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            if let onSearch, let searchPrompt = searchPrompt {
                TextField(searchPrompt, text: $searchText, onCommit: {
                    onSearch(searchText)
                })
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .submitLabel(.search)
            }
            
            Image(systemName: symbol)
                .font(.system(size: 48, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    LinearGradient(
                        colors: [CFTheme.accent, CFTheme.accent.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 6) {
                Text(title)
                    .font(CFTheme.headline())
                    .foregroundStyle(CFTheme.textPrimary)
                Text(message)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            if let actionTitle, let action {
                CFPillButton(title: actionTitle, icon: "plus", style: .primary, action: action)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
