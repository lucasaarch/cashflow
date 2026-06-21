import SwiftUI

struct AIModelPickerField: View {
    @EnvironmentObject private var aiService: AIService

    @Binding var selection: String
    let provider: AIProviderID
    let models: [AIModel]

    @State private var showingPicker = false
    @State private var searchQuery = ""

    private var configuration: AIConfiguration { aiService.configuration }

    private var sortedModels: [AIModel] {
        configuration.sortedModels(models, for: provider)
    }

    private var filteredModels: [AIModel] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sortedModels }
        return sortedModels.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query)
        }
    }

    private var favoriteIDs: Set<String> {
        Set(configuration.favoriteModelIDs(for: provider))
    }

    private var selectedModel: AIModel? {
        models.first { $0.id == selection }
    }

    var body: some View {
        Button {
            searchQuery = ""
            showingPicker = true
        } label: {
            HStack(spacing: 6) {
                Text(selectedModel?.displayName ?? selection)
                    .foregroundStyle(CFTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(CFTheme.textTertiary)
            }
            .cfPickerChip()
        }
        .buttonStyle(.plain)
        .disabled(models.isEmpty)
        .cfAdaptivePicker(isPresented: $showingPicker, arrowEdge: .top, sheetTitle: "Modelo") {
            pickerContent
        }
    }

    private var pickerContent: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            ScrollView {
                LazyVStack(spacing: 8) {
                    if filteredModels.isEmpty {
                        Text("Nenhum resultado")
                            .font(CFTheme.caption())
                            .foregroundStyle(CFTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(filteredModels) { model in
                            modelRow(model)
                        }
                    }
                }
                .padding(12)
            }
            .scrollIndicators(.visible)
        }
        .frame(width: 340, height: 360)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CFTheme.textSecondary)
            TextField("Buscar entre \(models.count) modelos…", text: $searchQuery)
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

    private func modelRow(_ model: AIModel) -> some View {
        let isSelected = selection == model.id
        let isFavorite = favoriteIDs.contains(model.id)

        return HStack(spacing: 8) {
            Button {
                configuration.toggleFavoriteModel(model.id, for: provider)
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isFavorite ? CFTheme.warning : CFTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .help(isFavorite ? "Remover dos favoritos" : "Adicionar aos favoritos")

            Button {
                selection = model.id
                showingPicker = false
            } label: {
                HStack(spacing: 10) {
                    Text(model.displayName)
                        .font(CFTheme.body())
                        .foregroundStyle(CFTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CFTheme.accent)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .cfGlassPickerOption(isSelected: isSelected)
            }
            .buttonStyle(.plain)
        }
    }
}
