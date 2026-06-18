import SwiftUI

struct CFSelectOption<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    var symbolName: String?
    var tint: Color = CFTheme.accent
}

struct CFSelectField<ID: Hashable>: View {
    @Binding var selection: ID
    let options: [CFSelectOption<ID>]
    var disabled: Bool = false
    var popoverWidth: CGFloat = 220
    var popoverMaxHeight: CGFloat? = nil

    @State private var showingPicker = false

    private var selected: CFSelectOption<ID>? {
        options.first { $0.id == selection }
    }

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            triggerLabel
        }
        .buttonStyle(.plain)
        .disabled(disabled || options.isEmpty)
        .cfAdaptivePicker(isPresented: $showingPicker, arrowEdge: .top, sheetTitle: "Selecionar") {
            popoverContent
        }
    }

    private var triggerLabel: some View {
        HStack(spacing: 6) {
            if let selected {
                if let symbolName = selected.symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(selected.tint)
                }
                Text(selected.title)
                    .foregroundStyle(CFTheme.textPrimary)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(CFTheme.textTertiary)
        }
        .cfPickerChip()
    }

    @ViewBuilder
    private var popoverContent: some View {
        if let popoverMaxHeight {
            ScrollView {
                optionsList
            }
            .frame(width: popoverWidth, height: popoverMaxHeight)
        } else {
            optionsList
                .frame(width: popoverWidth)
        }
    }

    private var optionsList: some View {
        VStack(spacing: 8) {
            ForEach(options) { option in
                optionRow(option)
            }
        }
        .padding(12)
    }

    private func optionRow(_ option: CFSelectOption<ID>) -> some View {
        let isSelected = selection == option.id

        return Button {
            selection = option.id
            showingPicker = false
        } label: {
            HStack(spacing: 10) {
                if let symbolName = option.symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(option.tint)
                        .frame(width: 24)
                }
                Text(option.title)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(option.tint)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? option.tint.opacity(0.18) : CFTheme.surfaceElevated.opacity(0.4))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(option.tint.opacity(0.35), lineWidth: 1)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

struct CFSelectFieldOptional<ID: Hashable>: View {
    @Binding var selection: ID?
    let options: [CFSelectOption<ID>]
    var placeholder: String = "Selecionar"
    var disabled: Bool = false
    var popoverWidth: CGFloat = 240
    var popoverMaxHeight: CGFloat = 280

    @State private var showingPicker = false

    private var selected: CFSelectOption<ID>? {
        guard let selection else { return nil }
        return options.first { $0.id == selection }
    }

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            triggerLabel
        }
        .buttonStyle(.plain)
        .disabled(disabled || options.isEmpty)
        .cfAdaptivePicker(isPresented: $showingPicker, arrowEdge: .top, sheetTitle: placeholder) {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(options) { option in
                        optionRow(option)
                    }
                }
                .padding(12)
            }
            .frame(width: popoverWidth, height: popoverMaxHeight)
        }
    }

    private var triggerLabel: some View {
        HStack(spacing: 6) {
            if let selected {
                if let symbolName = selected.symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(selected.tint)
                }
                Text(selected.title)
                    .foregroundStyle(CFTheme.textPrimary)
            } else {
                Text(placeholder)
                    .foregroundStyle(CFTheme.textSecondary)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(CFTheme.textTertiary)
        }
        .cfPickerChip()
    }

    private func optionRow(_ option: CFSelectOption<ID>) -> some View {
        let isSelected = selection == option.id

        return Button {
            selection = option.id
            showingPicker = false
        } label: {
            HStack(spacing: 10) {
                if let symbolName = option.symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(option.tint)
                        .frame(width: 24)
                }
                Text(option.title)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(option.tint)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? option.tint.opacity(0.18) : CFTheme.surfaceElevated.opacity(0.4))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(option.tint.opacity(0.35), lineWidth: 1)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

extension CategoryKind {
    var selectOption: CFSelectOption<CategoryKind> {
        CFSelectOption(
            id: self,
            title: displayName,
            symbolName: symbolName,
            tint: self == .expense ? CFTheme.expense : CFTheme.accent
        )
    }

    static var selectOptions: [CFSelectOption<CategoryKind>] {
        allCases.map(\.selectOption)
    }

    var displayName: String {
        switch self {
        case .expense: return "Despesa"
        case .income: return "Receita"
        }
    }

    var symbolName: String {
        switch self {
        case .expense: return "arrow.up.right"
        case .income: return "arrow.down.left"
        }
    }
}

extension AccountKind {
    static var selectOptions: [CFSelectOption<AccountKind>] {
        allCases.map { kind in
            CFSelectOption(
                id: kind,
                title: kind.displayName,
                symbolName: kind.defaultSymbolName,
                tint: CFTheme.accent
            )
        }
    }
}

extension WishlistPriority {
    var selectTint: Color {
        switch self {
        case .urgent: return CFTheme.danger
        case .high: return CFTheme.warning
        case .medium: return CFTheme.accent
        case .low: return CFTheme.textSecondary
        }
    }

    var selectSymbolName: String {
        switch self {
        case .urgent: return "exclamationmark.circle.fill"
        case .high: return "arrow.up.circle.fill"
        case .medium: return "equal.circle.fill"
        case .low: return "arrow.down.circle.fill"
        }
    }

    var selectOption: CFSelectOption<WishlistPriority> {
        CFSelectOption(
            id: self,
            title: displayName,
            symbolName: selectSymbolName,
            tint: selectTint
        )
    }

    static var selectOptions: [CFSelectOption<WishlistPriority>] {
        allCases.map(\.selectOption)
    }
}
