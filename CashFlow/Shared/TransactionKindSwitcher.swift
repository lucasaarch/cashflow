import SwiftUI

struct TransactionKindSwitcher: View {
    @Binding var kind: TransactionKind
    var namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 0) {
            pill(for: .expense, label: "Despesa", icon: "arrow.up.right", tint: .red)
            pill(for: .income, label: "Receita", icon: "arrow.down.left", tint: .green)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.secondary.opacity(0.12))
        )
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: kind)
    }

    @ViewBuilder
    private func pill(for value: TransactionKind, label: String, icon: String, tint: Color) -> some View {
        let isSelected = kind == value
        Button {
            kind = value
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tint.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(tint.opacity(0.35), lineWidth: 0.5)
                        )
                        .matchedGeometryEffect(id: "kindPill", in: namespace)
                }
            }
            .foregroundStyle(isSelected ? tint : .secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
