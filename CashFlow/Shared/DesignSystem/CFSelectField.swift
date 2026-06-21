import SwiftUI

private enum CFSelectFieldLayout {
    static let searchThreshold = 12
    static let scrollThreshold = 8
    static let defaultScrollHeight: CGFloat = 320
}

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
    /// When `nil`, search is enabled automatically for lists with 12 or more options.
    var searchable: Bool? = nil
    var searchPlaceholder: String = "Buscar…"

    @State private var showingPicker = false
    @State private var searchQuery = ""

    private var selected: CFSelectOption<ID>? {
        options.first { $0.id == selection }
    }

    private var isSearchEnabled: Bool {
        searchable ?? (options.count >= CFSelectFieldLayout.searchThreshold)
    }

    private var usesScrollContainer: Bool {
        popoverMaxHeight != nil || options.count > CFSelectFieldLayout.scrollThreshold || isSearchEnabled
    }

    private var effectiveMaxHeight: CGFloat {
        popoverMaxHeight ?? CFSelectFieldLayout.defaultScrollHeight
    }

    private var effectivePopoverWidth: CGFloat {
        isSearchEnabled ? max(popoverWidth, 300) : popoverWidth
    }

    private var filteredOptions: [CFSelectOption<ID>] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return options }
        return options.filter { matchesSearch($0, query: query) }
    }

    var body: some View {
        Button {
            searchQuery = ""
            showingPicker = true
        } label: {
            triggerLabel
        }
        .buttonStyle(.plain)
        .disabled(disabled || options.isEmpty)
        .cfAdaptivePicker(isPresented: $showingPicker, arrowEdge: .top, sheetTitle: "Selecionar") {
            popoverContent
        }
        .onChange(of: showingPicker) { _, isShowing in
            if !isShowing {
                searchQuery = ""
            }
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
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(CFTheme.textTertiary)
        }
        .cfPickerChip()
    }

    @ViewBuilder
    private var popoverContent: some View {
        if usesScrollContainer {
            VStack(spacing: 0) {
                if isSearchEnabled {
                    searchBar
                    Divider()
                }
                ScrollView {
                    optionsList(options: filteredOptions)
                }
                .scrollIndicators(.visible)
            }
            .frame(width: effectivePopoverWidth, height: effectiveMaxHeight)
        } else {
            optionsList(options: options)
                .frame(width: popoverWidth)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CFTheme.textSecondary)
            TextField(searchPlaceholder, text: $searchQuery)
                .textFieldStyle(.plain)
                .foregroundStyle(CFTheme.textPrimary)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(CFTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .cfGlassPickerSearchBar()
    }

    private func optionsList(options: [CFSelectOption<ID>]) -> some View {
        LazyVStack(spacing: 8) {
            if options.isEmpty {
                Text("Nenhum resultado")
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(options) { option in
                    optionRow(option)
                }
            }
        }
        .padding(12)
    }

    private func matchesSearch(_ option: CFSelectOption<ID>, query: String) -> Bool {
        if option.title.localizedCaseInsensitiveContains(query) { return true }
        if let stringID = option.id as? String, stringID.localizedCaseInsensitiveContains(query) {
            return true
        }
        return String(describing: option.id).localizedCaseInsensitiveContains(query)
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
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(option.tint)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .cfGlassPickerOption(isSelected: isSelected, tint: option.tint)
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
    var searchable: Bool? = nil
    var searchPlaceholder: String = "Buscar…"

    @State private var showingPicker = false
    @State private var searchQuery = ""

    private var isSearchEnabled: Bool {
        searchable ?? (options.count >= CFSelectFieldLayout.searchThreshold)
    }

    private var filteredOptions: [CFSelectOption<ID>] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return options }
        return options.filter { option in
            option.title.localizedCaseInsensitiveContains(query)
                || String(describing: option.id).localizedCaseInsensitiveContains(query)
        }
    }

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
            VStack(spacing: 0) {
                if isSearchEnabled {
                    optionalSearchBar
                    Divider()
                }
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(filteredOptions) { option in
                            optionRow(option)
                        }
                    }
                    .padding(12)
                }
                .scrollIndicators(.visible)
            }
            .frame(width: isSearchEnabled ? max(popoverWidth, 300) : popoverWidth, height: popoverMaxHeight)
        }
        .onChange(of: showingPicker) { _, isShowing in
            if !isShowing { searchQuery = "" }
        }
    }

    private var optionalSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CFTheme.textSecondary)
            TextField(searchPlaceholder, text: $searchQuery)
                .textFieldStyle(.plain)
            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(CFTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .cfGlassPickerSearchBar()
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
            .cfGlassPickerOption(isSelected: isSelected, tint: option.tint)
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
