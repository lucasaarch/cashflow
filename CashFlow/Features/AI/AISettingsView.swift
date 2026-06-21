import SwiftUI
import SwiftData

struct AISettingsView: View {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var chatPanelState: AIChatPanelState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ChatConversation.updatedAt, order: .reverse)])
    private var conversations: [ChatConversation]

    @Query(sort: [SortDescriptor(\AIWriteActionLogEntry.createdAt, order: .reverse)])
    private var writeActionLogs: [AIWriteActionLogEntry]

    @State private var cachedModels: [AIProviderID: [AIModel]] = [:]
    @State private var activeProvider: AIProviderID?
    @State private var activeModelID: String?
    @State private var editingBuiltInProvider: AIProviderID?
    @State private var customProviderEditor: CustomProviderEditorTarget?
    @State private var showingActiveSelection = false
    @State private var showDeleteAllChatsAlert = false
    @State private var isSyncingModels = false
    @State private var customProviders: [CustomAIProvider] = []
    @State private var weeklyReminderEnabled = UserDefaults.standard.object(forKey: UserDefaultsKeys.weeklyReminderEnabled) as? Bool ?? true
    #if os(macOS)
    @ObservedObject private var mcpServer = MCPServerCoordinator.shared
    @State private var didCopyMCPConfig = false
    @State private var isRestartingMCPServer = false
    #endif

    private var configuration: AIConfiguration { aiService.configuration }
    private var chatService: AIChatService { AIChatService(aiService: aiService) }

    var body: some View {
        CFGlassPage {
            CFGlassPageStack {
                heroSection

                if configuration.isReady {
                    chatShortcutSection
                }

                if !configuredProviders.isEmpty {
                    activeSection
                }

                providersSection
                preferencesSection

                #if os(macOS)
                mcpServerSection
                #endif

                if !writeActionLogs.isEmpty {
                    writeActionLogSection
                }

                if !conversations.isEmpty {
                    conversationsSection
                }
            }
        }
        .navigationTitle("Inteligência")
        .sheet(item: $editingBuiltInProvider) { provider in
            BuiltInProviderConfigSheet(
                provider: provider,
                cachedModels: $cachedModels,
                activeProvider: $activeProvider,
                activeModelID: $activeModelID
            )
            .environmentObject(aiService)
        }
        .sheet(item: $customProviderEditor) { target in
            CustomProviderConfigSheet(
                target: target,
                cachedModels: $cachedModels,
                activeProvider: $activeProvider,
                activeModelID: $activeModelID,
                onProvidersChanged: refreshCustomProviders
            )
            .environmentObject(aiService)
        }
        .sheet(isPresented: $showingActiveSelection) {
            ActiveProviderSheet(
                activeProvider: $activeProvider,
                activeModelID: $activeModelID,
                cachedModels: $cachedModels,
                isSyncingModels: $isSyncingModels,
                onSyncModels: { await syncModels() }
            )
            .environmentObject(aiService)
        }
        .task {
            await loadStateAndSyncModels()
            refreshCustomProviders()
        }
        .alert("Apagar todas as conversas?", isPresented: $showDeleteAllChatsAlert) {
            Button("Apagar", role: .destructive) {
                chatService.deleteAllConversations(conversations, in: modelContext)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Todas as conversas do assistente serão removidas permanentemente.")
        }
        .cfGlassDetailChrome()
    }

    private var heroSection: some View {
        CFGlassPanel(glass: .regular.tint(CFTheme.accent.opacity(0.06))) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(CFTheme.accent.opacity(0.14))
                        .frame(width: 56, height: 56)
                    Image(systemName: "sparkles")
                        .font(.system(size: 26, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(CFTheme.accent, CFTheme.brandTint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(AIAssistantIdentity.name)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(AIAssistantIdentity.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if configuration.isReady {
                        CFGlassStatusBadge(text: "Pronta para conversar", tint: CFTheme.income)
                    } else {
                        CFGlassStatusBadge(text: "Configure um provedor abaixo", tint: CFTheme.warning)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .cfStaggerAppear(index: 0)
    }

    private var chatShortcutSection: some View {
        Button {
            chatPanelState.openFresh()
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Conversar com \(AIAssistantIdentity.name)")
                    Text("Abrir o painel de chat agora")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } icon: {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .cfGlassProminentButton()
        .controlSize(.large)
        .cfStaggerAppear(index: 1)
    }

    private var preferencesSection: some View {
        CFGlassSection(title: "Preferências", staggerIndex: 4) {
            CFGlassPanel {
                CFGlassToggleRow(
                    title: "Resumo semanal da Gio",
                    subtitle: "Notificação às segundas com contas e recebimentos da semana",
                    isOn: $weeklyReminderEnabled
                )
            }
        }
        .onChange(of: weeklyReminderEnabled) { _, enabled in
            UserDefaults.standard.set(enabled, forKey: UserDefaultsKeys.weeklyReminderEnabled)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.weeklyReminderLastScheduledWeek)
        }
    }

    #if os(macOS)
    private var mcpServerSection: some View {
        CFGlassSection(
            title: "Servidor MCP",
            subtitle: "Expõe ferramentas do CashFlow para assistentes externos",
            staggerIndex: 5
        ) {
            CFGlassPanel {
                VStack(spacing: 0) {
                    CFGlassToggleRow(
                        title: "Permitir assistente externo (MCP)",
                        subtitle: "Escritas retornam proposta e exigem confirmação no app.",
                        isOn: Binding(
                            get: { mcpServer.isEnabled },
                            set: { mcpServer.isEnabled = $0 }
                        )
                    )

                    CFGlassPanelDivider()

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            CFGlassSymbol(
                                systemName: mcpStatusSymbolName,
                                tint: mcpStatusTint
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Status do servidor")
                                        .font(.body)
                                    mcpStatusBadge
                                }
                                if let detail = mcpServer.statusDetail {
                                    Text(detail)
                                        .font(.callout)
                                        .foregroundStyle(mcpStatusDetailTint)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                        }

                        HStack(spacing: 8) {
                            Button {
                                Task { await restartMCPServer() }
                            } label: {
                                Label(
                                    isRestartingMCPServer ? "Reiniciando…" : "Reiniciar",
                                    systemImage: "arrow.clockwise"
                                )
                            }
                            .cfGlassSecondaryButton()
                            .disabled(isRestartingMCPServer || !mcpServer.isEnabled)

                            Button {
                                mcpServer.copyConfigToPasteboard()
                                didCopyMCPConfig = true
                                Task {
                                    try? await Task.sleep(for: .seconds(2))
                                    didCopyMCPConfig = false
                                }
                            } label: {
                                Label(
                                    didCopyMCPConfig ? "Copiado!" : "Copiar config",
                                    systemImage: "doc.on.doc"
                                )
                            }
                            .cfGlassSecondaryButton()

                            Spacer(minLength: 0)
                        }

                        Text("Cole a config em \(MCPConfiguration.cursorConfigPath) para clientes MCP externos.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
                    .padding(.vertical, CFGlassMetrics.rowVerticalPadding)
                }
            }
        }
    }

    private var mcpStatusSymbolName: String {
        guard mcpServer.isEnabled else { return "power" }
        if mcpServer.isRunning { return "checkmark.circle.fill" }
        if mcpServer.lastError != nil { return "exclamationmark.triangle.fill" }
        return "pause.circle.fill"
    }

    private var mcpStatusTint: Color {
        guard mcpServer.isEnabled else { return CFTheme.textTertiary }
        if mcpServer.isRunning { return CFTheme.income }
        if mcpServer.lastError != nil { return CFTheme.danger }
        return CFTheme.warning
    }

    private var mcpStatusDetailTint: Color {
        guard mcpServer.isEnabled else { return CFTheme.textSecondary }
        if mcpServer.isRunning { return CFTheme.textSecondary }
        if mcpServer.lastError != nil { return CFTheme.danger }
        return CFTheme.warning
    }

    private var mcpStatusBadge: some View {
        let text = mcpServer.statusSummary
        let tint = mcpStatusTint
        return Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.15)))
    }

    private func restartMCPServer() async {
        guard mcpServer.isEnabled, !isRestartingMCPServer else { return }
        isRestartingMCPServer = true
        defer { isRestartingMCPServer = false }

        mcpServer.configure(container: modelContext.container)
        mcpServer.restart()
        await Task.yield()
    }
    #endif

    private var writeActionLogSection: some View {
        CFGlassSection(title: "Ações da Gio", subtitle: "Registro recente de alterações confirmadas", staggerIndex: 6) {
            CFGlassPanel {
                VStack(spacing: 0) {
                    ForEach(Array(writeActionLogs.prefix(8).enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 12) {
                            CFGlassSymbol(
                                systemName: entry.wasConfirmed ? "checkmark.circle.fill" : "xmark.circle.fill",
                                tint: entry.wasConfirmed ? CFTheme.income : CFTheme.textSecondary,
                                size: 28
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.summary)
                                    .font(.body)
                                    .lineLimit(2)
                                Text("\(entry.toolName) · \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
                        .padding(.vertical, CFGlassMetrics.rowVerticalPadding)

                        if index < writeActionLogs.prefix(8).count - 1 {
                            CFGlassInsetDivider()
                        }
                    }
                }
            }
        }
    }

    private var activeSection: some View {
        CFGlassSection(title: "Em uso", staggerIndex: 2, trailing: {
            Button {
                Task { await syncModels() }
            } label: {
                Group {
                    if isSyncingModels {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .cfGlassSecondaryButton()
            .disabled(isSyncingModels)
            .help("Sincronizar modelos")
        }) {
            CFGlassPanel(glass: .regular.interactive()) {
                CFGlassRowButton {
                    showingActiveSelection = true
                } label: {
                    activeRowContent
                }
            }
        }
    }

    private var activeRowContent: some View {
        let provider = activeProvider ?? configuredProviders.first ?? .openai
        return HStack(spacing: 12) {
            CFGlassSymbol(systemName: provider.symbolName, tint: CFTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(configuration.displayName(for: provider))
                    .font(.body)
                Text(activeModelDisplayName(for: provider))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private var conversationsSection: some View {
        CFGlassSection(title: "Conversas", staggerIndex: 7) {
            CFGlassPanel(glass: .regular.interactive()) {
                CFGlassRowButton {
                    showDeleteAllChatsAlert = true
                } label: {
                    HStack(spacing: 12) {
                        CFGlassSymbol(
                            systemName: "trash",
                            tint: CFTheme.danger,
                            size: 30
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apagar todas as conversas")
                            Text("\(conversations.count) conversa\(conversations.count == 1 ? "" : "s") salva\(conversations.count == 1 ? "" : "s")")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var providersSection: some View {
        VStack(alignment: .leading, spacing: CFGlassMetrics.sectionSpacing) {
            builtInProvidersSection
            customProvidersSection
        }
        .cfStaggerAppear(index: 3)
    }

    private var builtInProvidersSection: some View {
        CFGlassSection(title: "Provedores") {
            CFGlassPanel {
                VStack(spacing: 0) {
                    ForEach(Array(AIProviderID.builtInAllCases.enumerated()), id: \.element.id) { index, provider in
                        CFGlassRowButton {
                            editingBuiltInProvider = provider
                        } label: {
                            providerRowContent(provider)
                        }

                        if index < AIProviderID.builtInAllCases.count - 1 {
                            CFGlassInsetDivider()
                        }
                    }
                }
            }
        }
    }

    private var customProvidersSection: some View {
        CFGlassSection(title: "Compatíveis", subtitle: "OpenAI-compatíveis como Ollama, LM Studio ou vLLM", trailing: {
            Button {
                customProviderEditor = .add
            } label: {
                Label("Adicionar", systemImage: "plus")
            }
            .cfGlassSecondaryButton()
        }) {
            if customProviders.isEmpty {
                Text("Nenhum endpoint personalizado ainda.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            } else {
                CFGlassPanel {
                    VStack(spacing: 0) {
                        ForEach(Array(customProviders.enumerated()), id: \.element.id) { index, provider in
                            CFGlassRowButton {
                                customProviderEditor = .edit(provider.id)
                            } label: {
                                customProviderRowContent(provider)
                            }

                            if index < customProviders.count - 1 {
                                CFGlassInsetDivider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func providerRowContent(_ provider: AIProviderID) -> some View {
        let configured = configuration.isConfigured(provider)
        let currentActive = activeProvider ?? configuration.activeProvider ?? configuredProviders.first
        let isActive = configured && currentActive == provider

        return HStack(spacing: 12) {
            CFGlassSymbol(
                systemName: provider.symbolName,
                tint: configured ? CFTheme.accent : CFTheme.textSecondary
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(configuration.displayName(for: provider))
                    .font(.body)
                Text(providerStatusCaption(configured: configured, isActive: isActive))
                    .font(.callout)
                    .foregroundStyle(configured ? Color.secondary : Color.secondary.opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func customProviderRowContent(_ provider: CustomAIProvider) -> some View {
        let providerID = AIProviderID.custom(provider.id)
        let configured = provider.isConfigured
        let currentActive = activeProvider ?? configuration.activeProvider ?? configuredProviders.first
        let isActive = configured && currentActive == providerID

        return HStack(spacing: 12) {
            CFGlassSymbol(
                systemName: "server.rack",
                tint: configured ? CFTheme.accent : CFTheme.textSecondary
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(provider.name)
                        .font(.body)
                    customProviderBadge(provider)
                }
                Text(customProviderStatusCaption(provider, configured: configured, isActive: isActive))
                    .font(.callout)
                    .foregroundStyle(configured ? Color.secondary : Color.secondary.opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func providerStatusCaption(configured: Bool, isActive: Bool) -> String {
        if isActive { return "Em uso" }
        if configured { return "Configurado" }
        return "Não configurado"
    }

    private func customProviderStatusCaption(_ provider: CustomAIProvider, configured: Bool, isActive: Bool) -> String {
        if isActive { return "Em uso" }
        if configured { return provider.resolvedBaseURL?.host ?? "Conectado" }
        if !provider.baseURL.isEmpty, provider.resolvedBaseURL != nil { return "Teste pendente" }
        if !provider.baseURL.isEmpty { return "URL inválida" }
        return "Não configurado"
    }

    private func customProviderBadge(_ provider: CustomAIProvider) -> some View {
        let configured = provider.isConfigured
        let pending = !provider.baseURL.isEmpty && provider.resolvedBaseURL != nil && !provider.didConnect
        let text = configured ? "Conectado" : (pending ? "Pendente" : "Offline")
        let tint = configured ? CFTheme.income : (pending ? CFTheme.warning : CFTheme.textTertiary)
        return Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.15)))
    }

    private var configuredProviders: [AIProviderID] {
        configuration.configuredProviders()
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

    private func refreshCustomProviders() {
        customProviders = configuration.customProviders
    }

    private func loadState() {
        activeProvider = configuration.activeProvider
        activeModelID = configuration.activeModelID
    }

    private func loadStateAndSyncModels() async {
        await Task.yield()
        loadState()
        await syncModels()
    }

    private func syncModels(providers: [AIProviderID]? = nil) async {
        guard !isSyncingModels else { return }
        isSyncingModels = true
        defer { isSyncingModels = false }

        let targets = providers ?? configuredProviders
        for provider in targets {
            do {
                let models = try await aiService.listModels(for: provider)
                await Task.yield()
                applyFetchedModels(models, for: provider)
            } catch {
                continue
            }
        }
    }

    private func applyFetchedModels(_ models: [AIModel], for provider: AIProviderID) {
        cachedModels[provider] = models
        reconcileActiveModel(for: provider, models: models)
    }

    private func reconcileActiveModel(for provider: AIProviderID, models: [AIModel]) {
        guard configuration.activeProvider == provider else { return }
        let currentID = activeModelID ?? configuration.activeModelID
        if let currentID, models.contains(where: { $0.id == currentID }) { return }
        guard let first = models.first else { return }
        Task { @MainActor in
            activeModelID = first.id
            configuration.activeModelID = first.id
        }
    }
}

// MARK: - Custom provider editor target

private enum CustomProviderEditorTarget: Identifiable {
    case add
    case edit(UUID)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let id): id.uuidString
        }
    }
}

// MARK: - Built-in provider configuration sheet

private struct BuiltInProviderConfigSheet: View {
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    let provider: AIProviderID
    @Binding var cachedModels: [AIProviderID: [AIModel]]
    @Binding var activeProvider: AIProviderID?
    @Binding var activeModelID: String?

    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var editingOpenAI = false
    @State private var editingAnthropic = false
    @State private var statusMessage: String?
    @State private var isTesting = false

    private var configuration: AIConfiguration { aiService.configuration }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 480, height: 320)
        .cfCompactSheetToolbar(
            title: configuration.displayName(for: provider),
            cancelTitle: "Fechar",
            saveDisabled: !needsSave,
            onCancel: { dismiss() },
            onSave: { save(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfGlassSheetChrome()
    }

    private var formContent: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    CFGlassSheetHero(
                        systemName: provider.symbolName,
                        title: configuration.displayName(for: provider),
                        subtitle: providerSubtitle
                    )

                    CFGlassFormPanel(title: "Credenciais") {
                        VStack(spacing: 0) {
                            switch provider {
                            case .openai: openAIFields
                            case .anthropic: anthropicFields
                            case .custom: EmptyView()
                            }
                        }
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.callout)
                            .foregroundStyle(
                                statusMessage.contains("sucesso") ? CFTheme.income : CFTheme.expense
                            )
                            .padding(.horizontal, 4)
                    }
                }
                .padding(20)
            }
        }
        .scrollIndicators(.never)
    }

    private var providerSubtitle: String {
        switch provider {
        case .openai: return "GPT e modelos da OpenAI"
        case .anthropic: return "Claude e modelos da Anthropic"
        case .custom: return ""
        }
    }

    @ViewBuilder
    private var openAIFields: some View {
        if let masked = SecureStore.maskedValue(for: .openAIAPIKey), !editingOpenAI {
            CFGlassLabeledField(label: "Chave da API") {
                HStack(spacing: 8) {
                    Text(masked)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
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
            CFGlassLabeledField(label: "Chave da API") {
                SecureField("sk-…", text: $openAIKey)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    @ViewBuilder
    private var anthropicFields: some View {
        if let masked = SecureStore.maskedValue(for: .anthropicAPIKey), !editingAnthropic {
            CFGlassLabeledField(label: "Chave da API") {
                HStack(spacing: 8) {
                    Text(masked)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
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
            CFGlassLabeledField(label: "Chave da API") {
                SecureField("sk-ant-…", text: $anthropicKey)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                Task { await testConnection() }
            } label: {
                Label(isTesting ? "Testando…" : "Testar conexão", systemImage: "bolt.horizontal.circle")
            }
            .cfGlassSecondaryButton()
            .disabled(isTesting)

            Spacer()

            Button("Fechar") { dismiss() }
                .cfGlassSecondaryButton()
                .keyboardShortcut(.cancelAction)

            if needsSave {
                Button("Salvar") {
                    save()
                    dismiss()
                }
                .cfGlassProminentButton()
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
        case .custom: return false
        }
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
        case .custom:
            break
        }
    }

    private func testConnection() async {
        isTesting = true
        defer { isTesting = false }
        do {
            try persistCredentialsForTest()
            let models = try await aiService.listModels(for: provider)
            await Task.yield()
            cachedModels[provider] = models
            statusMessage = "Conexão com sucesso — \(models.count) modelos encontrados."
            activateProviderIfNeeded(models: models)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func activateProviderIfNeeded(models: [AIModel]) {
        Task { @MainActor in
            if configuration.activeProvider == nil {
                configuration.activeProvider = provider
                activeProvider = provider
            }
            if configuration.activeProvider == provider {
                let currentID = activeModelID ?? configuration.activeModelID
                if currentID == nil || !models.contains(where: { $0.id == currentID }) {
                    let modelID = models.first?.id
                    configuration.activeModelID = modelID
                    activeModelID = modelID
                }
            }
        }
    }

    private func persistCredentialsForTest() throws {
        switch provider {
        case .openai:
            let key = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                try SecureStore.save(key, for: .openAIAPIKey)
                openAIKey = ""
                editingOpenAI = false
            } else if !configuration.isConfigured(.openai) {
                throw AIError.notConfigured(.openai)
            }
        case .anthropic:
            let key = anthropicKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                try SecureStore.save(key, for: .anthropicAPIKey)
                anthropicKey = ""
                editingAnthropic = false
            } else if !configuration.isConfigured(.anthropic) {
                throw AIError.notConfigured(.anthropic)
            }
        case .custom:
            break
        }
    }
}

// MARK: - Custom provider configuration sheet

private struct CustomProviderConfigSheet: View {
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    let target: CustomProviderEditorTarget
    @Binding var cachedModels: [AIProviderID: [AIModel]]
    @Binding var activeProvider: AIProviderID?
    @Binding var activeModelID: String?
    var onProvidersChanged: () -> Void = {}

    @State private var providerID = UUID()
    @State private var name = ""
    @State private var baseURL = ""
    @State private var supportsTools = true
    @State private var apiKey = ""
    @State private var editingAPIKey = false
    @State private var statusMessage: String?
    @State private var isTesting = false

    private var configuration: AIConfiguration { aiService.configuration }
    private var providerReference: AIProviderID { .custom(providerID) }
    private var isEditing: Bool {
        if case .edit = target { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 480, height: isEditing ? 460 : 420)
        .cfCompactSheetToolbar(
            title: isEditing ? "Editar provedor" : "Novo provedor",
            cancelTitle: "Fechar",
            saveDisabled: !needsSave,
            onCancel: { dismiss() },
            onSave: { save(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfGlassSheetChrome()
        .onAppear(perform: loadFields)
    }

    private var formContent: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    CFGlassSheetHero(
                        systemName: "server.rack",
                        title: isEditing ? name : "Provedor compatível",
                        subtitle: "Ollama, LM Studio, vLLM e outros endpoints compatíveis"
                    )

                    CFGlassFormPanel(title: "Configuração") {
                        VStack(spacing: 0) {
                            CFGlassLabeledField(label: "Nome") {
                                TextField("Ollama local", text: $name)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                            }

                            CFGlassPanelDivider()

                            CFGlassLabeledField(label: "URL base") {
                                TextField(CustomAIProvider.suggestedBaseURL, text: $baseURL)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                            }

                            HStack(spacing: 8) {
                                presetButton("Ollama", url: "http://127.0.0.1:11434")
                                presetButton("LM Studio", url: "http://127.0.0.1:1234")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
                            .padding(.bottom, CFGlassMetrics.rowVerticalPadding)

                            CFGlassPanelDivider()

                            if let masked = SecureStore.maskedCustomProviderAPIKey(providerID), !editingAPIKey {
                                CFGlassLabeledField(label: "Chave da API (opcional)") {
                                    HStack(spacing: 8) {
                                        Text(masked)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        Button("Substituir") { editingAPIKey = true }
                                            .buttonStyle(.borderless)
                                        Button("Remover", role: .destructive) {
                                            SecureStore.deleteCustomProviderAPIKey(providerID)
                                            editingAPIKey = false
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            } else {
                                CFGlassLabeledField(label: "Chave da API (opcional)") {
                                    SecureField("Bearer token…", text: $apiKey)
                                        .textFieldStyle(.plain)
                                        .multilineTextAlignment(.trailing)
                                }
                            }

                            CFGlassPanelDivider()

                            CFGlassToggleRow(
                                title: "Ferramentas do app",
                                subtitle: "Desative se o modelo local não suportar function calling.",
                                isOn: $supportsTools
                            )
                        }
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.callout)
                            .foregroundStyle(
                                statusMessage.contains("sucesso") ? CFTheme.income : CFTheme.expense
                            )
                            .padding(.horizontal, 4)
                    }
                }
                .padding(20)
            }
        }
        .scrollIndicators(.never)
    }

    private func presetButton(_ title: String, url: String) -> some View {
        Button(title) {
            baseURL = url
        }
        .cfGlassSecondaryButton()
        .controlSize(.small)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                Task { await testConnection() }
            } label: {
                Label(isTesting ? "Testando…" : "Testar conexão", systemImage: "bolt.horizontal.circle")
            }
            .cfGlassSecondaryButton()
            .disabled(isTesting)

            if isEditing {
                Button("Remover", role: .destructive) {
                    deleteProvider()
                    dismiss()
                }
                .cfGlassDestructiveButton()
            }

            Spacer()

            Button("Fechar") { dismiss() }
                .cfGlassSecondaryButton()
                .keyboardShortcut(.cancelAction)

            if needsSave {
                Button("Salvar") {
                    save()
                    dismiss()
                }
                .cfGlassProminentButton()
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var needsSave: Bool {
        guard let existing = currentStoredProvider() else {
            return !trimmedName.isEmpty || !trimmedBaseURL.isEmpty || editingAPIKey && !apiKey.isEmpty
        }
        let nameChanged = trimmedName != existing.name
        let urlChanged = trimmedBaseURL != existing.baseURL
        let toolsChanged = supportsTools != existing.supportsTools
        let keyChanged = editingAPIKey && !apiKey.isEmpty
        return nameChanged || urlChanged || toolsChanged || keyChanged
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadFields() {
        switch target {
        case .add:
            providerID = UUID()
            name = ""
            baseURL = CustomAIProvider.suggestedBaseURL
            supportsTools = true
        case .edit(let id):
            providerID = id
            if let provider = configuration.customProvider(id: id) {
                name = provider.name
                baseURL = provider.baseURL.isEmpty ? CustomAIProvider.suggestedBaseURL : provider.baseURL
                supportsTools = provider.supportsTools
            }
        }
    }

    private func currentStoredProvider() -> CustomAIProvider? {
        configuration.customProvider(id: providerID)
    }

    private func save() {
        let existing = currentStoredProvider()
        let provider = CustomAIProvider(
            id: providerID,
            name: trimmedName.isEmpty ? "Provedor compatível" : trimmedName,
            baseURL: trimmedBaseURL,
            supportsTools: supportsTools,
            didConnect: existing?.didConnect ?? false
        )
        configuration.upsertCustomProvider(provider)

        if editingAPIKey, !apiKey.isEmpty {
            try? SecureStore.saveCustomProviderAPIKey(apiKey, providerID: providerID)
            apiKey = ""
            editingAPIKey = false
        }
        onProvidersChanged()
    }

    private func deleteProvider() {
        configuration.deleteCustomProvider(id: providerID)
        Task { @MainActor in
            cachedModels[providerReference] = nil
            if activeProvider == providerReference {
                activeProvider = configuration.activeProvider
                activeModelID = configuration.activeModelID
            }
            onProvidersChanged()
        }
    }

    private func testConnection() async {
        isTesting = true
        defer { isTesting = false }
        do {
            try persistCredentialsForTest()
            let models = try await aiService.listModels(for: providerReference)
            configuration.markCustomProviderConnected(id: providerID)
            await Task.yield()
            cachedModels[providerReference] = models
            statusMessage = "Conexão com sucesso — \(models.count) modelos encontrados."
            onProvidersChanged()

            if configuration.activeProvider == nil {
                configuration.activeProvider = providerReference
                activeProvider = providerReference
            }
            if configuration.activeProvider == providerReference {
                let currentID = activeModelID ?? configuration.activeModelID
                if currentID == nil || !models.contains(where: { $0.id == currentID }) {
                    let modelID = models.first?.id
                    configuration.activeModelID = modelID
                    activeModelID = modelID
                }
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func persistCredentialsForTest() throws {
        let existing = currentStoredProvider()
        let provider = CustomAIProvider(
            id: providerID,
            name: trimmedName.isEmpty ? "Provedor compatível" : trimmedName,
            baseURL: trimmedBaseURL,
            supportsTools: supportsTools,
            didConnect: existing?.didConnect ?? false
        )
        configuration.upsertCustomProvider(provider)

        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            try SecureStore.saveCustomProviderAPIKey(key, providerID: providerID)
            apiKey = ""
            editingAPIKey = false
        } else if provider.resolvedBaseURL == nil {
            throw AIError.notConfigured(.custom(providerID))
        }
    }
}

// MARK: - Active provider sheet

private struct ActiveProviderSheet: View {
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    @Binding var activeProvider: AIProviderID?
    @Binding var activeModelID: String?
    @Binding var cachedModels: [AIProviderID: [AIModel]]
    @Binding var isSyncingModels: Bool
    var onSyncModels: () async -> Void

    private var configuration: AIConfiguration { aiService.configuration }

    private var configuredProviders: [AIProviderID] {
        configuration.configuredProviders()
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
        .cfGlassSheetChrome()
    }

    private var formContent: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                CFGlassFormPanel(title: "Seleção") {
                    VStack(spacing: 0) {
                        if configuredProviders.isEmpty {
                            Text("Configure um provedor antes de selecionar o ativo.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
                                .padding(.vertical, CFGlassMetrics.rowVerticalPadding)
                        } else {
                            CFGlassLabeledField(label: "Provedor") {
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
                                            title: configuration.displayName(for: provider),
                                            symbolName: provider.symbolName
                                        )
                                    }
                                )
                            }

                            if let provider = activeProvider ?? configuredProviders.first {
                                let models = cachedModels[provider] ?? []
                                if !models.isEmpty {
                                    CFGlassPanelDivider()
                                    CFGlassLabeledField(label: "Modelo") {
                                        AIModelPickerField(
                                            selection: Binding(
                                                get: { activeModelID ?? models.first?.id ?? "" },
                                                set: { newValue in
                                                    activeModelID = newValue
                                                    configuration.activeModelID = newValue
                                                }
                                            ),
                                            provider: provider,
                                            models: models
                                        )
                                    }
                                } else {
                                    CFGlassPanelDivider()
                                    Text("Nenhum modelo encontrado. Verifique a conexão ou sincronize novamente.")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
                                        .padding(.vertical, CFGlassMetrics.rowVerticalPadding)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .scrollIndicators(.never)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                Task { await onSyncModels() }
            } label: {
                Label(
                    isSyncingModels ? "Sincronizando…" : "Sincronizar modelos",
                    systemImage: "arrow.clockwise"
                )
            }
            .cfGlassSecondaryButton()
            .disabled(isSyncingModels)

            Spacer()

            Button("Concluído") { dismiss() }
                .cfGlassProminentButton()
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
