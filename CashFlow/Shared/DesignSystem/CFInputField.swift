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
                .focused($isFocused)
                .cfFieldChrome(isFocused: isFocused)
        }
    }
}
