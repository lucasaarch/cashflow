import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject private var aiService: AIService

    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var ollamaHost = ""
    @State private var ollamaPort = ""
    @State private var editingOpenAI = false
    @State private var editingAnthropic = false
    @State private var cachedModels: [AIProviderID: [AIModel]] = [:]
    @State private var statusMessages: [AIProviderID: String] = [:]
    @State private var isTesting: AIProviderID?
    @State private var activeProvider: AIProviderID?
    @State private var activeModelID: String?

    private var configuration: AIConfiguration { aiService.configuration }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Configure provedores de IA e escolha qual usar no CashFlow.")
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textSecondary)

                CFGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        providerHeader(.openai)
                        openAIFields
                        providerFooter(.openai)
                    }
                }

                CFGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        providerHeader(.anthropic)
                        anthropicFields
                        providerFooter(.anthropic)
                    }
                }

                CFGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        providerHeader(.ollama)
                        ollamaFields
                        providerFooter(.ollama)
                    }
                }

                activeSelectionCard
            }
            .padding(20)
        }
        .cfPageBackground()
        .navigationTitle("Inteligência")
        .onAppear(perform: loadState)
    }

    private func providerHeader(_ provider: AIProviderID) -> some View {
        HStack {
            Image(systemName: provider.symbolName)
                .foregroundStyle(CFTheme.accent)
            Text(provider.displayName)
                .font(CFTheme.body().weight(.semibold))
                .foregroundStyle(CFTheme.textPrimary)
            Spacer()
            statusBadge(for: provider)
        }
    }

    private func providerFooter(_ provider: AIProviderID) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = statusMessages[provider] {
                Text(message)
                    .font(CFTheme.caption())
                    .foregroundStyle(message.contains("sucesso") ? CFTheme.income : CFTheme.expense)
            }
            HStack {
                Spacer()
                CFPillButton(
                    title: isTesting == provider ? "Testando…" : "Testar conexão",
                    style: .ghost
                ) {
                    Task { await testProvider(provider) }
                }
                .allowsHitTesting(isTesting != provider)
            }
        }
    }

    @ViewBuilder
    private var openAIFields: some View {
        if let masked = SecureStore.maskedValue(for: .openAIAPIKey), !editingOpenAI {
            HStack {
                Text(masked)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(CFTheme.textSecondary)
                Spacer()
                Button("Substituir") { editingOpenAI = true }
                    .buttonStyle(.borderless)
                Button("Remover", role: .destructive) {
                    SecureStore.delete(.openAIAPIKey)
                    editingOpenAI = false
                }
                .buttonStyle(.borderless)
            }
        } else {
            SecureField("Chave da API OpenAI", text: $openAIKey)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .cfFieldChrome(isFocused: false)
            HStack {
                Spacer()
                CFPillButton(title: "Salvar chave", style: .primary) {
                    guard !openAIKey.isEmpty else { return }
                    try? SecureStore.save(openAIKey, for: .openAIAPIKey)
                    openAIKey = ""
                    editingOpenAI = false
                }
            }
        }
    }

    @ViewBuilder
    private var anthropicFields: some View {
        if let masked = SecureStore.maskedValue(for: .anthropicAPIKey), !editingAnthropic {
            HStack {
                Text(masked)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(CFTheme.textSecondary)
                Spacer()
                Button("Substituir") { editingAnthropic = true }
                    .buttonStyle(.borderless)
                Button("Remover", role: .destructive) {
                    SecureStore.delete(.anthropicAPIKey)
                    editingAnthropic = false
                }
                .buttonStyle(.borderless)
            }
        } else {
            SecureField("Chave da API Anthropic", text: $anthropicKey)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .cfFieldChrome(isFocused: false)
            HStack {
                Spacer()
                CFPillButton(title: "Salvar chave", style: .primary) {
                    guard !anthropicKey.isEmpty else { return }
                    try? SecureStore.save(anthropicKey, for: .anthropicAPIKey)
                    anthropicKey = ""
                    editingAnthropic = false
                }
            }
        }
    }

    private var ollamaFields: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Text("Host")
                    .foregroundStyle(CFTheme.textSecondary)
                TextField("127.0.0.1", text: $ollamaHost)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .cfFieldChrome(isFocused: false)
                Text("Porta")
                    .foregroundStyle(CFTheme.textSecondary)
                TextField("11434", text: $ollamaPort)
                    .textFieldStyle(.plain)
                    .frame(width: 80)
                    .padding(8)
                    .cfFieldChrome(isFocused: false)
            }
            HStack {
                Spacer()
                CFPillButton(title: "Salvar", style: .primary) {
                    configuration.ollamaHost = ollamaHost
                    configuration.ollamaPort = Int(ollamaPort) ?? 11434
                }
            }
        }
    }

    private var activeSelectionCard: some View {
        CFGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("PROVEDOR EM USO")
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)

                HStack(spacing: 12) {
                    Text("Provedor")
                        .font(CFTheme.body())
                        .foregroundStyle(CFTheme.textSecondary)
                    Spacer(minLength: 8)
                    providerPicker
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(CFTheme.surfaceElevated.opacity(0.38))
                )

                if let provider = activeProvider ?? configuredProviders.first {
                    HStack(spacing: 12) {
                        Text("Modelo")
                            .font(CFTheme.body())
                            .foregroundStyle(CFTheme.textSecondary)
                        Spacer(minLength: 8)
                        modelPicker(for: provider)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(CFTheme.surfaceElevated.opacity(0.38))
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var providerPicker: some View {
        if configuredProviders.isEmpty {
            Text("Configure um provedor acima")
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
        } else {
            CFSelectField(
                selection: Binding(
                    get: { activeProvider ?? configuredProviders[0] },
                    set: { newValue in
                        activeProvider = newValue
                        configuration.activeProvider = newValue
                        activeModelID = cachedModels[newValue]?.first?.id
                        configuration.activeModelID = activeModelID
                    }
                ),
                options: configuredProviders.map { provider in
                    CFSelectOption(id: provider, title: provider.displayName, symbolName: provider.symbolName)
                }
            )
        }
    }

    private func modelPicker(for provider: AIProviderID) -> some View {
        CFSelectField(
            selection: Binding(
                get: { activeModelID ?? cachedModels[provider]?.first?.id ?? "" },
                set: { newValue in
                    activeModelID = newValue
                    configuration.activeModelID = newValue
                }
            ),
            options: (cachedModels[provider] ?? []).map {
                CFSelectOption(id: $0.id, title: $0.displayName)
            },
            disabled: (cachedModels[provider] ?? []).isEmpty
        )
    }

    private var configuredProviders: [AIProviderID] {
        AIProviderID.allCases.filter { configuration.isConfigured($0) }
    }

    @ViewBuilder
    private func statusBadge(for provider: AIProviderID) -> some View {
        let configured = configuration.isConfigured(provider)
        Text(configured ? "Configurado" : "Não configurado")
            .font(CFTheme.caption())
            .foregroundStyle(configured ? CFTheme.income : CFTheme.textTertiary)
    }

    private func loadState() {
        ollamaHost = configuration.ollamaHost
        ollamaPort = String(configuration.ollamaPort)
        activeProvider = configuration.activeProvider
        activeModelID = configuration.activeModelID
    }

    private func testProvider(_ provider: AIProviderID) async {
        isTesting = provider
        defer { isTesting = nil }
        do {
            let models = try await aiService.listModels(for: provider)
            cachedModels[provider] = models
            statusMessages[provider] = "Conexão com sucesso — \(models.count) modelos encontrados."
            if activeProvider == provider, activeModelID == nil {
                activeModelID = models.first?.id
                configuration.activeModelID = activeModelID
            }
        } catch {
            statusMessages[provider] = error.localizedDescription
        }
    }
}
