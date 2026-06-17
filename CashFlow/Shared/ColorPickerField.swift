import SwiftUI

struct AccountColorOption: Identifiable {
    let id: String
    let name: String

    var color: Color { Color(hex: id) }
}

enum AccountColorPalette {
    static let all: [AccountColorOption] = [
        AccountColorOption(id: "#3B82F6", name: "Azul"),
        AccountColorOption(id: "#0EA5E9", name: "Céu"),
        AccountColorOption(id: "#06B6D4", name: "Ciano"),
        AccountColorOption(id: "#14B8A6", name: "Teal"),
        AccountColorOption(id: "#6366F1", name: "Índigo"),
        AccountColorOption(id: "#8B5CF6", name: "Violeta"),
        AccountColorOption(id: "#A855F7", name: "Roxo"),
        AccountColorOption(id: "#EC4899", name: "Rosa"),
        AccountColorOption(id: "#EF4444", name: "Vermelho"),
        AccountColorOption(id: "#F97316", name: "Laranja"),
        AccountColorOption(id: "#F59E0B", name: "Âmbar"),
        AccountColorOption(id: "#84CC16", name: "Lima"),
        AccountColorOption(id: "#22C55E", name: "Verde"),
        AccountColorOption(id: "#64748B", name: "Ardósia"),
        AccountColorOption(id: "#78716C", name: "Pedra"),
        AccountColorOption(id: "#A16207", name: "Ouro"),
    ]
}

struct ColorPickerField: View {
    @Binding var color: Color

    @State private var showingPicker = false

    private var selectedOption: AccountColorOption? {
        AccountColorPalette.all.first { $0.color.matchesHex(color) }
    }

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack(spacing: 6) {
                swatch(color, size: 14)
                Text(selectedOption?.name ?? "Personalizada")
                    .foregroundStyle(CFTheme.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(CFTheme.textTertiary)
            }
            .cfPickerChip()
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPicker, arrowEdge: .top) {
            ColorPickerGrid(color: $color, dismiss: { showingPicker = false })
                .presentationBackground(CFTheme.surfacePrimary)
        }
    }

    private func swatch(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(CFTheme.textTertiary.opacity(0.25), lineWidth: 0.5)
            )
    }
}

private struct ColorPickerGrid: View {
    @Binding var color: Color
    let dismiss: () -> Void

    private let columns = Array(repeating: GridItem(.fixed(36), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cor da conta")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(AccountColorPalette.all) { option in
                    colorCell(option)
                }
            }
        }
        .padding(14)
        .frame(width: 220)
    }

    private func colorCell(_ option: AccountColorOption) -> some View {
        let isSelected = option.color.matchesHex(color)

        return Button {
            color = option.color
            dismiss()
        } label: {
            Circle()
                .fill(option.color)
                .frame(width: 32, height: 32)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(.white.opacity(0.95), lineWidth: 2)
                            .padding(2)
                        Circle()
                            .strokeBorder(option.color.opacity(0.8), lineWidth: 1.5)
                    }
                }
                .overlay {
                    Circle()
                        .stroke(CFTheme.textTertiary.opacity(isSelected ? 0 : 0.2), lineWidth: 0.5)
                }
                .shadow(color: option.color.opacity(isSelected ? 0.35 : 0), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .help(option.name)
    }
}

private extension Color {
    func matchesHex(_ other: Color) -> Bool {
        hexString.uppercased() == other.hexString.uppercased()
    }
}
