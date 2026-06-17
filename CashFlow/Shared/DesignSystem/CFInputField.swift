import SwiftUI

struct CFInputField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(CFTheme.body())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(CFTheme.surfaceElevated.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isFocused ? CFTheme.brandGreen : CFTheme.textTertiary.opacity(0.2), lineWidth: isFocused ? 1.5 : 0.5)
                )
                .focused($isFocused)
                .animation(CFMotion.snappy, value: isFocused)
        }
    }
}
