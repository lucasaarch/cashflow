import SwiftUI

struct IconPickerField: View {
    @Binding var symbolName: String
    var tint: Color = CFTheme.brandGreen

    @State private var showingPicker = false

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 30, height: 30)
                    Image(systemName: symbolName.isEmpty ? "questionmark.square.dashed" : symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(tint)
                }
                Text(displayName)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(CFTheme.textSecondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(CFTheme.surfaceElevated.opacity(0.42))
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPicker, arrowEdge: .top) {
            IconPickerGrid(symbolName: $symbolName, tint: tint, dismiss: { showingPicker = false })
        }
    }

    private var displayName: String {
        if let match = IconLibrary.all.first(where: { $0.name == symbolName }) {
            return match.keywords.first?.capitalized ?? "Ícone"
        }
        return symbolName.isEmpty ? "Escolher ícone" : symbolName
    }
}

private struct IconPickerGrid: View {
    @Binding var symbolName: String
    let tint: Color
    let dismiss: () -> Void

    @State private var query: String = ""

    private var grouped: [(IconGroup, [IconItem])] {
        let items = IconLibrary.filter(query)
        let dict = Dictionary(grouping: items) { $0.group }
        return IconGroup.allCases.compactMap { group in
            guard let arr = dict[group], !arr.isEmpty else { return nil }
            return (group, arr)
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(40), spacing: 8), count: 7)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if grouped.isEmpty {
                        ContentUnavailableView("Nenhum ícone", systemImage: "magnifyingglass",
                                               description: Text("Tente outra palavra."))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(grouped, id: \.0) { group, items in
                            section(title: group.rawValue, items: items)
                        }
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 360, height: 380)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CFTheme.textSecondary)
            TextField("Buscar (mercado, uber, luz…)", text: $query)
                .textFieldStyle(.plain)
                .foregroundStyle(CFTheme.textPrimary)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(CFTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(CFTheme.surfaceElevated.opacity(0.35))
    }

    private func section(title: String, items: [IconItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(items, id: \.name) { item in
                    cell(item)
                }
            }
        }
    }

    private func cell(_ item: IconItem) -> some View {
        let isSelected = item.name == symbolName
        return Button {
            symbolName = item.name
            dismiss()
        } label: {
            Image(systemName: item.name)
                .font(.system(size: 17, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? tint : CFTheme.textPrimary)
                .frame(width: 36, height: 36)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? tint.opacity(0.22) : CFTheme.surfaceElevated.opacity(0.40))
                        .overlay {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(tint, lineWidth: 1)
                            }
                        }
                }
        }
        .buttonStyle(.plain)
        .help(item.keywords.first?.capitalized ?? item.name)
    }
}
