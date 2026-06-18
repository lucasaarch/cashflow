import SwiftUI
import SwiftData

enum AIChatPanelPresentation {
    case inlineColumn
    case sheet
}

struct AIChatSidePanel: View {
    private static let bottomAnchorID = "ai-chat-bottom-anchor"

    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var chatPanelState: AIChatPanelState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: [SortDescriptor(\ChatConversation.updatedAt, order: .reverse)])
    private var conversations: [ChatConversation]

    @Query private var transactions: [Transaction]
    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var accounts: [Account]
    @Query private var goals: [FinancialGoal]
    @Query(sort: [SortDescriptor(\Bill.dueDate)]) private var bills: [Bill]
    @Query(sort: [SortDescriptor(\Receivable.expectedDate)]) private var receivables: [Receivable]
    @Query(sort: [SortDescriptor(\WishlistItem.createdAt, order: .reverse)]) private var wishlistItems: [WishlistItem]
    @Query(sort: [SortDescriptor(\RecurringExpense.createdAt)]) private var recurringExpenses: [RecurringExpense]
    @Query(sort: [SortDescriptor(\RecurringIncome.createdAt)]) private var recurringIncomes: [RecurringIncome]
    @Query(sort: [SortDescriptor(\Category.sortOrder)]) private var categories: [Category]

    @State private var isSending = false
    @State private var typewriterMessageID: UUID?
    @State private var typewriterScrollTick = 0
    @State private var errorMessage: String?
    @State private var showingHistory = false
    @State private var showDeleteConversationAlert = false
    @FocusState private var isInputFocused: Bool

    private let chatService: AIChatService
    private let presentation: AIChatPanelPresentation

    private let suggestions = [
        "Como está meu mês até agora?",
        "Me explica meu saldo projetado",
        "O que tenho pra pagar essa semana?"
    ]

    init(aiService: AIService, presentation: AIChatPanelPresentation = .inlineColumn) {
        chatService = AIChatService(aiService: aiService)
        self.presentation = presentation
    }

    private var selectedConversation: ChatConversation? {
        if let id = chatPanelState.selectedConversationID,
           let match = conversations.first(where: { $0.id == id }) {
            return match
        }
        return conversations.first
    }

    private var sortedMessages: [ChatMessage] {
        selectedConversation?.messages.sorted { $0.createdAt < $1.createdAt } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if aiService.configuration.isReady {
                messagesList
                    .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                inputBar
            } else {
                setupCTA
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [CFTheme.surfacePrimary, CFTheme.surfacePrimary.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            if chatPanelState.selectedConversationID == nil {
                chatPanelState.selectedConversationID = conversations.first?.id
            }
        }
        .onChange(of: conversations.count) { _, _ in
            guard let currentID = chatPanelState.selectedConversationID else {
                chatPanelState.selectedConversationID = conversations.first?.id
                return
            }
            if !conversations.contains(where: { $0.id == currentID }) {
                chatPanelState.selectedConversationID = conversations.first?.id
            }
        }
        .alert("Apagar esta conversa?", isPresented: $showDeleteConversationAlert) {
            Button("Apagar", role: .destructive) {
                deleteSelectedConversation()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("As mensagens desta conversa serão removidas permanentemente.")
        }
        .onChange(of: chatPanelState.insightLaunchToken) { _, token in
            guard token != nil else { return }
            Task { await handleInsightLaunchIfNeeded() }
        }
        .onChange(of: chatPanelState.isOpen) { _, isOpen in
            guard isOpen, chatPanelState.insightLaunchToken != nil else { return }
            Task { await handleInsightLaunchIfNeeded() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            CFIconBadge(symbolName: "sparkles", tint: CFTheme.accent, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(AIAssistantIdentity.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CFTheme.textPrimary)
                Text(AIAssistantIdentity.subtitle)
                    .font(.caption2)
                    .foregroundStyle(CFTheme.textSecondary)
            }

            Spacer(minLength: 0)

            if presentation == .sheet {
                headerIconButton(symbol: "xmark", help: "Fechar") {
                    chatPanelState.close()
                }
            }

            headerIconButton(symbol: "plus", help: "Nova conversa") {
                createConversation()
            }

            if selectedConversation != nil {
                headerIconButton(symbol: "trash", help: "Apagar conversa atual") {
                    showDeleteConversationAlert = true
                }
            }

            historyButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(CFTheme.surfacePrimary.opacity(0.85))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }

    private func headerIconButton(symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CFTheme.textSecondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(CFTheme.textTertiary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    /// Clock icon doubles as the picker trigger — tapping it opens the conversation
    /// list popover directly (no intermediate sheet).
    private var historyButton: some View {
        Button {
            showingHistory = true
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CFTheme.textSecondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(CFTheme.textTertiary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help("Histórico de conversas")
        .disabled(conversations.isEmpty)
        .cfAdaptivePicker(isPresented: $showingHistory, arrowEdge: .top, sheetTitle: "Histórico") {
            historyPickerContent
        }
    }

    private var historyPickerContent: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(conversations) { conversation in
                    conversationRow(conversation)
                }
            }
            .padding(12)
            .cfScrollContent()
        }
        .cfScrollChrome()
        .frame(width: 280, height: 320)
    }

    private func conversationRow(_ conversation: ChatConversation) -> some View {
        let isSelected = chatPanelState.selectedConversationID == conversation.id

        return Button {
            chatPanelState.selectedConversationID = conversation.id
            showingHistory = false
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CFTheme.accent)
                    .frame(width: 24)
                Text(conversation.title)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CFTheme.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? CFTheme.accent.opacity(0.18) : CFTheme.surfaceElevated.opacity(0.4))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(CFTheme.accent.opacity(0.35), lineWidth: 1)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if sortedMessages.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(sortedMessages.enumerated()), id: \.element.id) { index, message in
                            messageRow(message, index: index)
                                .id(message.id)
                        }
                    }

                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    if let pending = chatPanelState.pendingWrite {
                        writeConfirmationCard(pending)
                    }

                    if let status = chatPanelState.toolStatusMessage, isSending {
                        toolStatusBanner(status)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchorID)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .cfScrollContent()
            }
            .cfScrollChrome()
            .onAppear {
                Task { await scrollToBottomWhenReady(proxy) }
            }
            .task(id: chatPanelState.selectedConversationID) {
                await scrollToBottomWhenReady(proxy)
            }
            .onChange(of: chatPanelState.isOpen) { _, isOpen in
                guard isOpen else { return }
                Task { await scrollToBottomWhenReady(proxy) }
            }
            .onChange(of: sortedMessages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: sortedMessages.last?.content) { _, _ in scrollToBottom(proxy) }
            .onChange(of: typewriterScrollTick) { _, _ in scrollToBottom(proxy) }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pergunte qualquer coisa")
                    .font(.headline)
                    .foregroundStyle(CFTheme.textPrimary)
                Text("\(AIAssistantIdentity.name) conhece seus lançamentos, contas e metas — converse no seu ritmo.")
                    .font(.callout)
                    .foregroundStyle(CFTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Sugestões")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CFTheme.textTertiary)
                    .textCase(.uppercase)

                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                    Button {
                        chatPanelState.draft = suggestion
                        Task { await send() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkle")
                                .font(.caption)
                                .foregroundStyle(CFTheme.accent)
                            Text(suggestion)
                                .font(.callout)
                                .foregroundStyle(CFTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(CFTheme.textTertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(CFTheme.surfaceElevated.opacity(0.4))
                        )
                    }
                    .buttonStyle(.plain)
                    .cfStaggerAppear(index: index)
                }
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func messageRow(_ message: ChatMessage, index: Int) -> some View {
        Group {
            if message.role == .user {
                userBubble(message)
            } else {
                assistantBubble(message)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .cfStaggerAppear(index: index)
    }

    private func userBubble(_ message: ChatMessage) -> some View {
        Text(message.content)
            .font(CFTheme.body())
            .foregroundStyle(CFTheme.textPrimary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CFTheme.surfaceElevated.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(CFTheme.textTertiary.opacity(0.16), lineWidth: 1)
            )
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func assistantBubble(_ message: ChatMessage) -> some View {
        let isStreaming = isSending && message.role == .assistant && message.id == sortedMessages.last?.id
        let alreadyPlayed = chatPanelState.typedMessageIDs.contains(message.id)
        let useTypewriter = typewriterMessageID == message.id && !isStreaming && !alreadyPlayed

        Group {
            if isStreaming, message.content.isEmpty {
                CFThinkingDots()
            } else if useTypewriter {
                CFTypewriter(
                    text: message.content,
                    markdown: true,
                    animated: true,
                    onProgress: { _ in
                        typewriterScrollTick += 1
                    },
                    onComplete: {
                        chatPanelState.typedMessageIDs.insert(message.id)
                        if typewriterMessageID == message.id {
                            typewriterMessageID = nil
                        }
                    }
                )
                .font(CFTheme.body())
                .foregroundStyle(CFTheme.textPrimary)
                .lineSpacing(4)
            } else {
                CFMarkdownText(text: message.content)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(CFTheme.danger)
            Text(message)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.danger)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CFTheme.danger.opacity(0.1))
        )
    }

    private func toolStatusBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(message)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CFTheme.surfaceElevated.opacity(0.45))
        )
    }

    private func writeConfirmationCard(_ pending: AIPendingWriteAction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                CFIconBadge(symbolName: "hand.raised.fill", tint: CFTheme.warning, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(AIAssistantIdentity.name) quer fazer uma ação")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CFTheme.textPrimary)
                    Text(pending.summary)
                        .font(.callout)
                        .foregroundStyle(CFTheme.textSecondary)
                }
            }

            HStack(spacing: 10) {
                CFPillButton(title: "Cancelar", style: .ghost) {
                    chatPanelState.pendingWrite = nil
                    chatPanelState.agentMessages = []
                }
                CFPillButton(title: "Confirmar", style: .primary) {
                    Task { await confirmPendingWrite(pending) }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CFTheme.warning.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CFTheme.warning.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Input

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.5)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Converse com \(AIAssistantIdentity.name)…", text: $chatPanelState.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(CFTheme.body())
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onKeyPress(.return, phases: .down) { press in
                        guard !press.modifiers.contains(.shift) else { return .ignored }
                        Task { await send() }
                        return .handled
                    }
                    .submitLabel(.send)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(CFTheme.surfaceElevated.opacity(0.45))
                    )
                    .cfAIGlow(active: isInputFocused || isSending, cornerRadius: 14, lineWidth: isInputFocused || isSending ? 1.4 : 0.8)
                    .animation(reduceMotion ? nil : CFMotion.snappy, value: isInputFocused)

                sendButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(CFTheme.surfacePrimary.opacity(0.9))
    }

    private var sendButton: some View {
        let canSend = !chatPanelState.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending

        return Button {
            Task { await send() }
        } label: {
            Image(systemName: isSending ? "ellipsis" : "arrow.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(canSend ? .white : CFTheme.textTertiary)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(
                            canSend
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [CFTheme.accent, CFTheme.accent.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                : AnyShapeStyle(CFTheme.textTertiary.opacity(0.15))
                        )
                )
                .scaleEffect(canSend ? 1 : 0.94)
                .animation(reduceMotion ? nil : CFMotion.snappy, value: canSend)
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .help("Enviar")
    }

    private var setupCTA: some View {
        VStack(spacing: 16) {
            Spacer()
            CFIconBadge(symbolName: "sparkles", tint: CFTheme.textTertiary, size: 44)
            Text("Configure um provedor de IA")
                .font(.headline)
                .foregroundStyle(CFTheme.textPrimary)
            Text("Vá em Inteligência nas configurações para conversar com \(AIAssistantIdentity.name).")
                .font(.callout)
                .foregroundStyle(CFTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }

    // MARK: - Actions

    private func createConversation() {
        let conversation = chatService.createConversation(in: modelContext)
        withAnimation(CFMotion.snappy) {
            chatPanelState.selectedConversationID = conversation.id
        }
    }

    private func send() async {
        guard aiService.configuration.isReady else { return }
        var conversation = selectedConversation
        if conversation == nil {
            conversation = chatService.createConversation(in: modelContext)
            chatPanelState.selectedConversationID = conversation?.id
        }
        guard let conversation else { return }

        isSending = true
        errorMessage = nil
        typewriterMessageID = nil
        let text = chatPanelState.draft
        chatPanelState.draft = ""

        do {
            let result = try await chatService.sendMessage(
                text,
                in: conversation,
                transactions: transactions,
                accounts: accounts,
                bills: bills,
                receivables: receivables,
                goals: goals,
                wishlistItems: wishlistItems,
                recurringExpenses: recurringExpenses,
                recurringIncomes: recurringIncomes,
                categories: categories,
                dashboardInsightMonthKey: chatPanelState.dashboardInsightMonthKey,
                wishlistInsightMonthKey: chatPanelState.wishlistInsightMonthKey,
                context: modelContext,
                onStatus: { update in
                    if update.isExecutingTools, let toolName = update.toolName {
                        chatPanelState.toolStatusMessage = toolStatusLabel(for: toolName)
                    } else {
                        chatPanelState.toolStatusMessage = nil
                    }
                },
                onPartialContent: nil
            )
            chatPanelState.toolStatusMessage = nil
            chatPanelState.agentMessages = result.agentMessages
            chatPanelState.pendingWrite = result.pendingWrite
            if let assistantID = result.assistantMessageID {
                typewriterMessageID = assistantID
            }
        } catch {
            errorMessage = error.localizedDescription
            chatPanelState.toolStatusMessage = nil
        }
        isSending = false
    }

    private func confirmPendingWrite(_ pending: AIPendingWriteAction) async {
        guard let conversation = selectedConversation else { return }
        isSending = true
        errorMessage = nil
        chatPanelState.pendingWrite = nil

        do {
            let result = try await chatService.confirmPendingWrite(
                pending,
                agentMessages: chatPanelState.agentMessages,
                in: conversation,
                transactions: transactions,
                accounts: accounts,
                bills: bills,
                receivables: receivables,
                goals: goals,
                wishlistItems: wishlistItems,
                recurringExpenses: recurringExpenses,
                recurringIncomes: recurringIncomes,
                categories: categories,
                dashboardInsightMonthKey: chatPanelState.dashboardInsightMonthKey,
                wishlistInsightMonthKey: chatPanelState.wishlistInsightMonthKey,
                context: modelContext,
                onStatus: { update in
                    if update.isExecutingTools, let toolName = update.toolName {
                        chatPanelState.toolStatusMessage = toolStatusLabel(for: toolName)
                    } else {
                        chatPanelState.toolStatusMessage = nil
                    }
                },
                onPartialContent: nil
            )
            chatPanelState.toolStatusMessage = nil
            chatPanelState.agentMessages = result.agentMessages
            chatPanelState.pendingWrite = result.pendingWrite
            if let assistantID = result.assistantMessageID {
                typewriterMessageID = assistantID
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }

    private func toolStatusLabel(for toolName: String) -> String {
        switch toolName {
        case let name where name.hasPrefix("get_goal") || name == "list_goals":
            return "Consultando suas metas…"
        case "get_wishlist_insight":
            return "Consultando sugestão da lista de desejos…"
        case let name where name.contains("wishlist"):
            return "Consultando lista de desejos…"
        case let name where name.contains("bill"):
            return "Consultando contas a pagar…"
        case let name where name.contains("receivable"):
            return "Consultando contas a receber…"
        case let name where name.contains("transaction"):
            return "Consultando lançamentos…"
        case "get_patrimony", "list_accounts":
            return "Consultando patrimônio…"
        case "get_dashboard_insight":
            return "Consultando resumo da Gio…"
        case let name where name.contains("month"):
            return "Consultando o mês…"
        default:
            return "Consultando seus dados…"
        }
    }

    private func handleInsightLaunchIfNeeded() async {
        guard chatPanelState.isOpen else { return }
        guard chatPanelState.consumeInsightLaunchToken() != nil else { return }
        guard aiService.configuration.isReady else { return }
        guard !chatPanelState.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isSending else { return }

        try? await Task.sleep(for: .milliseconds(150))
        isInputFocused = true
        try? await Task.sleep(for: .milliseconds(80))
        await send()
    }

    private func deleteSelectedConversation() {
        guard let conversation = selectedConversation else { return }
        let deletingID = conversation.id
        chatService.deleteConversation(conversation, in: modelContext)
        chatPanelState.selectedConversationID = conversations.first(where: { $0.id != deletingID })?.id
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let scroll = {
            if let lastID = sortedMessages.last?.id {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
        if animated && !reduceMotion {
            withAnimation(CFMotion.snappy) { scroll() }
        } else {
            scroll()
        }
    }

    private func scrollToBottomWhenReady(_ proxy: ScrollViewProxy) async {
        guard !sortedMessages.isEmpty else { return }
        scrollToBottom(proxy, animated: false)
        try? await Task.sleep(for: .milliseconds(16))
        scrollToBottom(proxy, animated: false)
        try? await Task.sleep(for: .milliseconds(100))
        scrollToBottom(proxy, animated: false)
    }
}
