import SwiftUI
import SwiftData

struct AISettingsView: View {
    @EnvironmentObject private var aiService: AIService
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ChatConversation.updatedAt, order: .reverse)])
    private var conversations: [ChatConversation]

    @State private var cachedModels: [AIProviderID: [AIModel]] = [:]
    @State private var activeProvider: AIProviderID?
    @State private var activeModelID: String?
    @State private var editingProvider: AIProviderID?
    @State private var showingActiveSelection = false
    @State private var showDeleteAllChatsAlert = false

    private var configuration: AIConfiguration { aiService.configuration }
    private var chatService: AIChatService { AIChatService(aiService: aiService) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !configuredProviders.isEmpty {
                    activeSection
                }
                providersSection
                if !conversations.isEmpty {
                    conversationsSection
                }
            }
            .padding(20)
        }
        .cfPageBackground()
        .navigationTitle("Inteligência")
        .sheet(item: $editingProvider) { provider in
            ProviderConfigSheet(
                provider: provider,
                cachedModels: $cachedModels,
                activeProvider: $activeProvider,
                activeModelID: $activeModelID
            )
            .environmentObject(aiService)
        }
        .sheet(isPresented: $showingActiveSelection) {
            ActiveProviderSheet(
                activeProvider: $activeProvider,
                activeModelID: $activeModelID,
                cachedModels: $cachedModels
            )
            .environmentObject(aiService)
        }
        .onAppear(perform: loadState)
        .alert("Apagar todas as conversas?", isPresented: $showDeleteAllChatsAlert) {
            Button("Apagar", role: .destructive) {
                chatService.deleteAllConversations(conversations, in: modelContext)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Todas as conversas do assistente serão removidas permanentemente.")
        }
    }

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Em uso")
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            CFHoverRow {
                activeRowContent
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingActiveSelection = true
            }
        }
    }

    private var activeRowContent: some View {
        let provider = activeProvider ?? configuredProviders[0]
        return HStack(spacing: 12) {
            CFIconBadge(symbolName: provider.symbolName, tint: CFTheme.accent, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(provider.displayName)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                Text(activeModelDisplayName(for: provider))
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CFTheme.textTertiary)
        }
    }

    private var conversationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Conversas")
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            CFHoverRow {
                HStack(spacing: 12) {
                    CFIconBadge(symbolName: "bubble.left.and.bubble.right", tint: CFTheme.danger, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Apagar todas as conversas")
                            .font(CFTheme.body())
                            .foregroundStyle(CFTheme.textPrimary)
                        Text("\(conversations.count) conversa\(conversations.count == 1 ? "" : "s") salva\(conversations.count == 1 ? "" : "s")")
                            .font(CFTheme.caption())
                            .foregroundStyle(CFTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CFTheme.danger.opacity(0.8))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showDeleteAllChatsAlert = true
            }
        }
    }

    private var providersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Provedores")
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            ForEach(AIProviderID.allCases) { provider in
                CFHoverRow {
                    providerRowContent(provider)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingProvider = provider
                }
            }
        }
    }

    private func providerRowContent(_ provider: AIProviderID) -> some View {
        let configured = configuration.isConfigured(provider)
        let currentActive = activeProvider ?? configuration.activeProvider ?? configuredProviders.first
        let isActive = configured && currentActive == provider

        return HStack(spacing: 12) {
            CFIconBadge(
                symbolName: provider.symbolName,
                tint: configured ? CFTheme.accent : CFTheme.textSecondary,
                size: 30
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(provider.displayName)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                Text(providerStatusCaption(provider, configured: configured, isActive: isActive))
                    .font(CFTheme.caption())
                    .foregroundStyle(configured ? CFTheme.textSecondary : CFTheme.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CFTheme.textTertiary)
        }
    }

    private func providerStatusCaption(_ provider: AIProviderID, configured: Bool, isActive: Bool) -> String {
        if isActive { return "Em uso" }
        if configured { return "Configurado" }
        return "Não configurado"
    }

    private var configuredProviders: [AIProviderID] {
        AIProviderID.allCases.filter { configuration.isConfigured($0) }
    }

    private func activeModelDisplayName(for provider: AIProviderID) -> String {
        let modelID = activeModelID ?? configuration.activeModelID
        if let modelID,
           let model = cachedModels[provider]?.first(where: { $0.id == modelID }) {
            return model.displayName
        }
        if let modelID { return modelID }
        return "Selecionar modelo"
    }

    private func loadState() {
        activeProvider = configuration.activeProvider
        activeModelID = configuration.activeModelID
    }
}

// MARK: - Provider configuration sheet

private struct ProviderConfigSheet: View {
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    let provider: AIProviderID
    @Binding var cachedModels: [AIProviderID: [AIModel]]
    @Binding var activeProvider: AIProviderID?
    @Binding var activeModelID: String?

    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var ollamaHost = ""
    @State private var ollamaPort = ""
    @State private var editingOpenAI = false
    @State private var editingAnthropic = false
    @State private var statusMessage: String?
    @State private var isTesting = false

    private var configuration: AIConfiguration { aiService.configuration }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 480, height: sheetHeight)
        .cfCompactSheetToolbar(
            title: provider.displayName,
            cancelTitle: "Fechar",
            saveDisabled: !needsSave,
            onCancel: { dismiss() },
            onSave: { save(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfSheetBackground()
        .tint(CFTheme.accent)
        .onAppear(perform: loadFields)
    }

    private var sheetHeight: CGFloat {
        switch provider {
        case .openai, .anthropic: return 320
        case .ollama: return 360
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CFIconBadge(symbolName: provider.symbolName, tint: CFTheme.accent, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(CFTheme.headline())
                    .foregroundStyle(CFTheme.textPrimary)
                Text(providerSubtitle)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var providerSubtitle: String {
        switch provider {
        case .openai: return "GPT e modelos da OpenAI"
        case .anthropic: return "Claude e modelos da Anthropic"
        case .ollama: return "Modelos rodando localmente"
        }
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                switch provider {
                case .openai:
                    credentialsSection { openAIFields }
                case .anthropic:
                    credentialsSection { anthropicFields }
                case .ollama:
                    connectionSection
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(CFTheme.caption())
                        .foregroundStyle(
                            statusMessage.contains("sucesso") ? CFTheme.income : CFTheme.expense
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.never)
    }

    private func credentialsSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Credenciais")
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
            content()
        }
    }

    @ViewBuilder
    private var openAIFields: some View {
        if let masked = SecureStore.maskedValue(for: .openAIAPIKey), !editingOpenAI {
            labeledRow("Chave da API") {
                HStack(spacing: 8) {
                    Text(masked)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(CFTheme.textSecondary)
                        .lineLimit(1)
                    Button("Substituir") { editingOpenAI = true }
                        .buttonStyle(.borderless)
                    Button("Remover", role: .destructive) {
                        SecureStore.delete(.openAIAPIKey)
                        editingOpenAI = false
                    }
                    .buttonStyle(.borderless)
                }
            }
        } else {
            labeledRow("Chave da API") {
                SecureField("sk-…", text: $openAIKey)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    @ViewBuilder
    private var anthropicFields: some View {
        if let masked = SecureStore.maskedValue(for: .anthropicAPIKey), !editingAnthropic {
            labeledRow("Chave da API") {
                HStack(spacing: 8) {
                    Text(masked)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(CFTheme.textSecondary)
                        .lineLimit(1)
                    Button("Substituir") { editingAnthropic = true }
                        .buttonStyle(.borderless)
                    Button("Remover", role: .destructive) {
                        SecureStore.delete(.anthropicAPIKey)
                        editingAnthropic = false
                    }
                    .buttonStyle(.borderless)
                }
            }
        } else {
            labeledRow("Chave da API") {
                SecureField("sk-ant-…", text: $anthropicKey)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Conexão")
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)

            labeledRow("Host") {
                TextField("127.0.0.1", text: $ollamaHost)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            labeledRow("Porta") {
                TextField("11434", text: $ollamaPort)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
            }
        }
    }

    private func labeledRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(CFTheme.body())
                .foregroundStyle(CFTheme.textSecondary)
            Spacer(minLength: 8)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(CFTheme.surfaceElevated.opacity(0.38))
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            CFPillButton(
                title: isTesting ? "Testando…" : "Testar conexão",
                style: .ghost
            ) {
                Task { await testConnection() }
            }
            .allowsHitTesting(!isTesting)

            Spacer()

            CFPillButton(title: "Fechar", style: .ghost) { dismiss() }
                .keyboardShortcut(.cancelAction)

            if needsSave {
                CFPillButton(title: "Salvar", style: .primary) {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var needsSave: Bool {
        switch provider {
        case .openai: return editingOpenAI && !openAIKey.isEmpty
        case .anthropic: return editingAnthropic && !anthropicKey.isEmpty
        case .ollama: return true
        }
    }

    private func loadFields() {
        ollamaHost = configuration.ollamaHost
        ollamaPort = String(configuration.ollamaPort)
    }

    private func save() {
        switch provider {
        case .openai:
            guard !openAIKey.isEmpty else { return }
            try? SecureStore.save(openAIKey, for: .openAIAPIKey)
            openAIKey = ""
            editingOpenAI = false
        case .anthropic:
            guard !anthropicKey.isEmpty else { return }
            try? SecureStore.save(anthropicKey, for: .anthropicAPIKey)
            anthropicKey = ""
            editingAnthropic = false
        case .ollama:
            configuration.ollamaHost = ollamaHost
            configuration.ollamaPort = Int(ollamaPort) ?? 11434
        }
    }

    private func testConnection() async {
        isTesting = true
        defer { isTesting = false }
        saveOllamaIfNeeded()
        do {
            let models = try await aiService.listModels(for: provider)
            cachedModels[provider] = models
            statusMessage = "Conexão com sucesso — \(models.count) modelos encontrados."
            if configuration.activeProvider == nil {
                configuration.activeProvider = provider
                activeProvider = provider
            }
            if configuration.activeProvider == provider, configuration.activeModelID == nil {
                let modelID = models.first?.id
                configuration.activeModelID = modelID
                activeModelID = modelID
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func saveOllamaIfNeeded() {
        guard provider == .ollama else { return }
        configuration.ollamaHost = ollamaHost
        configuration.ollamaPort = Int(ollamaPort) ?? 11434
    }
}

// MARK: - Active provider sheet

private struct ActiveProviderSheet: View {
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    @Binding var activeProvider: AIProviderID?
    @Binding var activeModelID: String?
    @Binding var cachedModels: [AIProviderID: [AIModel]]

    private var configuration: AIConfiguration { aiService.configuration }

    private var configuredProviders: [AIProviderID] {
        AIProviderID.allCases.filter { configuration.isConfigured($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 480, height: 280)
        .cfCompactSheetToolbar(
            title: "Provedor ativo",
            cancelTitle: "Fechar",
            saveTitle: "Concluído",
            onCancel: { dismiss() },
            onSave: { dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfSheetBackground()
        .tint(CFTheme.accent)
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section(title: "Seleção") {
                    labeledRow("Provedor") {
                        CFSelectField(
                            selection: Binding(
                                get: { activeProvider ?? configuredProviders[0] },
                                set: { newValue in
                                    activeProvider = newValue
                                    configuration.activeProvider = newValue
                                    let models = cachedModels[newValue] ?? []
                                    if let first = models.first {
                                        activeModelID = first.id
                                        configuration.activeModelID = first.id
                                    }
                                }
                            ),
                            options: configuredProviders.map { provider in
                                CFSelectOption(
                                    id: provider,
                                    title: provider.displayName,
                                    symbolName: provider.symbolName
                                )
                            }
                        )
                    }

                    if let provider = activeProvider ?? configuredProviders.first {
                        let models = cachedModels[provider] ?? []
                        if !models.isEmpty {
                            labeledRow("Modelo") {
                                CFSelectField(
                                    selection: Binding(
                                        get: { activeModelID ?? models.first?.id ?? "" },
                                        set: { newValue in
                                            activeModelID = newValue
                                            configuration.activeModelID = newValue
                                        }
                                    ),
                                    options: models.map {
                                        CFSelectOption(id: $0.id, title: $0.displayName)
                                    }
                                )
                            }
                        } else {
                            Text("Teste a conexão do provedor para carregar os modelos disponíveis.")
                                .font(CFTheme.caption())
                                .foregroundStyle(CFTheme.textSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.never)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func labeledRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(CFTheme.body())
                .foregroundStyle(CFTheme.textSecondary)
            Spacer(minLength: 8)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(CFTheme.surfaceElevated.opacity(0.38))
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            CFPillButton(title: "Concluído", style: .primary) { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
