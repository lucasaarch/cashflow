import SwiftUI

struct DashboardCard<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        }
    }
}
