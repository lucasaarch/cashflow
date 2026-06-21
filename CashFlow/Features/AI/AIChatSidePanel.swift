import SwiftUI
import SwiftData

enum AIChatPanelPresentation {
    case inlineColumn
    case sheet
}

struct AIChatSidePanel: View {
    private static let bottomAnchorID = "ai-chat-bottom-anchor"
    /// Conteúdo abaixo dos botões da toolbar nativa — o fundo do inspector vai até o topo.
    private static let inlineToolbarClearance: CGFloat = 52
    private static let conversationTopPaddingSheet: CGFloat = 12
    private static let conversationBottomPadding: CGFloat = 16
    private static let sendButtonSize: CGFloat = 32

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
    @State private var sendTask: Task<Void, Never>?
    @State private var stopButtonPulse = false
    @State private var typewriterScrollTick = 0
    @State private var pendingSettleMessageID: UUID?
    @State private var settledRevealMessageIDs: Set<UUID> = []
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

    init(
        aiService: AIService,
        presentation: AIChatPanelPresentation = .inlineColumn
    ) {
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
        Group {
            if presentation == .sheet {
                panelContent.cfGlassSheetChrome()
            } else {
                panelContent
            }
        }
        .onAppear {
            Task { @MainActor in
                reconcileSelectedConversation()
            }
        }
        .onChange(of: conversations.count) { _, _ in
            Task { @MainActor in
                reconcileSelectedConversation()
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
            beginSend { await handleInsightLaunchIfNeeded() }
        }
        .onChange(of: chatPanelState.isOpen) { _, isOpen in
            guard isOpen, chatPanelState.insightLaunchToken != nil else { return }
            beginSend { await handleInsightLaunchIfNeeded() }
        }
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            if presentation == .sheet {
                sheetHeader
            }
            if aiService.configuration.isReady {
                conversationBody
            } else {
                setupCTA
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, presentation == .inlineColumn ? Self.inlineToolbarClearance : 0)
    }

    private var conversationTopPadding: CGFloat {
        presentation == .inlineColumn ? 0 : Self.conversationTopPaddingSheet
    }

    private var conversationBody: some View {
        VStack(spacing: 0) {
            Group {
                if sortedMessages.isEmpty {
                    emptyStateLayout
                } else {
                    messagesList
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)

            inputBar
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header (sheet)

    private var sheetHeader: some View {
        HStack(spacing: 12) {
            CFGlassSymbol(
                systemName: AIAssistantIdentity.settingsSymbolName,
                tint: CFTheme.accent,
                size: 34
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(AIAssistantIdentity.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CFTheme.textPrimary)
                Text(AIAssistantIdentity.subtitle)
                    .font(.caption2)
                    .foregroundStyle(CFTheme.textSecondary)
            }

            Spacer(minLength: 0)

            inlineToolbarButton(symbol: "xmark", help: "Fechar") {
                chatPanelState.close()
            }

            inlineToolbarButton(symbol: "plus", help: "Nova conversa") {
                createConversation()
            }

            if selectedConversation != nil {
                inlineToolbarButton(symbol: "trash", help: "Apagar conversa atual") {
                    showDeleteConversationAlert = true
                }
            }

            sheetHistoryButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .padding(.top, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            CFGlassPanelDivider()
        }
    }

    private func inlineToolbarButton(symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .cfGlassToolbarIconButton()
        .help(help)
    }

    /// Clock icon doubles as the picker trigger — tapping it opens the conversation
    /// list popover directly (no intermediate sheet).
    private var sheetHistoryButton: some View {
        Button {
            showingHistory = true
        } label: {
            Image(systemName: "clock.arrow.circlepath")
        }
        .cfGlassToolbarIconButton()
        .help("Histórico de conversas")
        .disabled(conversations.isEmpty)
        .cfAdaptivePicker(isPresented: $showingHistory, arrowEdge: .top, sheetTitle: "Histórico") {
            AIChatConversationHistoryPicker(
                conversations: conversations,
                selectedConversationID: chatPanelState.selectedConversationID,
                onSelect: { conversation in
                    chatPanelState.selectedConversationID = conversation.id
                    showingHistory = false
                }
            )
        }
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(sortedMessages.enumerated()), id: \.element.id) { index, message in
                        messageRow(message, index: index)
                            .id(message.id)
                    }

                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    if let pending = chatPanelState.pendingWrite {
                        writeConfirmationCard(pending)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchorID)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, conversationTopPadding)
                .padding(.bottom, Self.conversationBottomPadding)
                .cfScrollContent()
            }
            .cfScrollChrome()
            .clipped()
            .onAppear {
                Task { await scrollToBottomWhenReady(proxy) }
            }
            .task(id: chatPanelState.selectedConversationID) {
                resetConversationPresentationState()
                await scrollToBottomWhenReady(proxy)
            }
            .onChange(of: chatPanelState.isOpen) { _, isOpen in
                guard isOpen else { return }
                Task { await scrollToBottomWhenReady(proxy) }
            }
            .onChange(of: chatPanelState.liveToolActivities.count) { _, _ in
                Task { @MainActor in scrollToBottom(proxy) }
            }
            .onChange(of: sortedMessages.count) { _, _ in
                Task { @MainActor in scrollToBottom(proxy) }
            }
            .onChange(of: sortedMessages.last?.content) { _, _ in
                Task { @MainActor in scrollToBottom(proxy) }
            }
            .onChange(of: typewriterScrollTick) { _, _ in
                Task { @MainActor in scrollToBottom(proxy) }
            }
        }
    }

    private var emptyStateLayout: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pergunte qualquer coisa")
                        .font(CFTheme.chatHeadline())
                        .foregroundStyle(CFTheme.textPrimary)
                    Text("\(AIAssistantIdentity.name) conhece seus lançamentos, contas e metas — converse no seu ritmo.")
                        .font(CFTheme.chatBody())
                        .foregroundStyle(CFTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                emptyStateSuggestions
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateSuggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sugestões")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CFTheme.textTertiary)
                .textCase(.uppercase)

            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                Button {
                    chatPanelState.draft = suggestion
                    beginSend { await send() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.caption2)
                            .foregroundStyle(CFTheme.accent)
                        Text(suggestion)
                            .font(CFTheme.chatBody())
                            .foregroundStyle(CFTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(CFTheme.textTertiary)
                    }
                    .cfChatSuggestionChipGlass()
                }
                .buttonStyle(.plain)
                .cfStaggerAppear(index: index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func messageRow(_ message: ChatMessage, index: Int) -> some View {
        Group {
            if message.role == .user {
                userBubble(message)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    toolActivitiesView(for: message)
                    assistantBubble(message)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private func toolActivitiesView(for message: ChatMessage) -> some View {
        let activities = resolvedToolActivities(for: message)
        return AIToolActivityStack(activities: activities)
    }

    private func resolvedToolActivities(for message: ChatMessage) -> [AIToolActivityRecord] {
        if isSending,
           message.role == .assistant,
           message.id == sortedMessages.last?.id,
           !chatPanelState.liveToolActivities.isEmpty {
            return chatPanelState.visibleToolActivities(chatPanelState.liveToolActivities)
        }
        let cached = chatPanelState.toolActivities(for: message.id)
        if !cached.isEmpty { return chatPanelState.visibleToolActivities(cached) }
        return chatPanelState.visibleToolActivities(message.sortedToolActivityRecords)
    }

    private func finalizeWriteProposalTrace() {
        guard let conversation = selectedConversation,
              let lastAssistant = conversation.messages
            .filter({ $0.role == .assistant })
            .sorted(by: { $0.createdAt < $1.createdAt })
            .last,
              !chatPanelState.liveToolActivities.isEmpty else { return }
        chatPanelState.finalizeToolTrace(
            for: lastAssistant.id,
            message: lastAssistant,
            context: modelContext
        )
    }

    private func userBubble(_ message: ChatMessage) -> some View {
        Text(message.content)
            .font(CFTheme.chatBody())
            .foregroundStyle(CFTheme.textPrimary)
            .lineSpacing(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .cfChatUserBubbleGlass()
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func assistantBubble(_ message: ChatMessage) -> some View {
        let isStreaming = isSending && message.role == .assistant && message.id == sortedMessages.last?.id
        let shouldSettleReveal = pendingSettleMessageID == message.id
            && !settledRevealMessageIDs.contains(message.id)

        Group {
            if isStreaming, message.content.isEmpty {
                CFThinkingDots()
            } else if isStreaming {
                CFTypewriter(
                    text: message.content,
                    markdown: true,
                    markdownCompact: true,
                    animated: true,
                    streaming: true,
                    onProgress: { _ in
                        typewriterScrollTick += 1
                    }
                )
                .font(CFTheme.chatBody())
                .foregroundStyle(CFTheme.textPrimary)
                .lineSpacing(2)
            } else {
                CFMarkdownText(text: message.content, compact: true, lineSpacing: 2)
                    .foregroundStyle(CFTheme.textPrimary)
                    .cfStreamSettleReveal(isActive: shouldSettleReveal) {
                        settledRevealMessageIDs.insert(message.id)
                        if pendingSettleMessageID == message.id {
                            pendingSettleMessageID = nil
                        }
                    }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private func finishSending(for conversation: ChatConversation) {
        if let assistantID = conversation.messages
            .sorted(by: { $0.createdAt < $1.createdAt })
            .last(where: { $0.role == .assistant })?
            .id {
            pendingSettleMessageID = assistantID
        }
        withAnimation(CFMotion.gentle) {
            isSending = false
        }
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

    private func writeConfirmationCard(_ pending: AIPendingWriteAction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                CFIconBadge(
                    symbolName: AIToolDisplayName.symbol(for: pending.toolName),
                    tint: CFTheme.warning,
                    size: 28
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(AIToolDisplayName.confirmationTitle(for: pending.toolName))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CFTheme.textPrimary)
                    Text(pending.summary)
                        .font(.callout)
                        .foregroundStyle(CFTheme.textSecondary)
                }
            }

            HStack(spacing: 10) {
                CFPillButton(title: "Cancelar", style: .ghost) {
                    cancelPendingWrite(pending)
                }
                CFPillButton(title: "Confirmar", style: .primary) {
                    beginSend { await confirmPendingWrite(pending) }
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
            if presentation != .inlineColumn {
                CFGlassPanelDivider()
            }

            HStack(alignment: .center, spacing: 10) {
                TextField("Converse com \(AIAssistantIdentity.name)…", text: $chatPanelState.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(CFTheme.chatBody())
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onKeyPress(.return, phases: .down) { press in
                        if press.modifiers.contains(.shift) {
                            Task { @MainActor in
                                chatPanelState.draft.append("\n")
                            }
                            return .handled
                        }
                        Task { @MainActor in
                            beginSend { await send() }
                        }
                        return .handled
                    }
                    .submitLabel(.send)
                    .cfChatInputFieldGlass()
                    .animation(reduceMotion ? nil : CFMotion.snappy, value: isInputFocused)

                sendButton
                    .frame(width: Self.sendButtonSize, height: Self.sendButtonSize)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .background {
            if presentation != .inlineColumn {
                CFTheme.surfacePrimary.opacity(0.96)
            }
        }
    }

    private var sendButton: some View {
        let hasDraft = !chatPanelState.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return Button {
            if isSending {
                stopSending()
            } else {
                beginSend { await send() }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(sendButtonBackground(isSending: isSending, hasDraft: hasDraft))

                Image(systemName: isSending ? "stop.fill" : "arrow.up")
                    .font(.system(size: isSending ? 10 : 12, weight: .bold))
                    .foregroundStyle(sendButtonForeground(isSending: isSending, hasDraft: hasDraft))
            }
            .frame(width: Self.sendButtonSize, height: Self.sendButtonSize)
            .opacity(isSending && stopButtonPulse ? 0.82 : 1)
            .animation(reduceMotion ? nil : CFMotion.snappy, value: isSending)
            .animation(reduceMotion ? nil : CFMotion.snappy, value: hasDraft)
        }
        .buttonStyle(.plain)
        .disabled(!isSending && !hasDraft)
        .help(isSending ? "Interromper resposta" : "Enviar")
        .onChange(of: isSending) { _, sending in
            guard sending, !reduceMotion else {
                stopButtonPulse = false
                return
            }
            stopButtonPulse = false
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                stopButtonPulse = true
            }
        }
    }

    private func sendButtonForeground(isSending: Bool, hasDraft: Bool) -> Color {
        if isSending { return .white }
        return hasDraft ? .white : CFTheme.textTertiary
    }

    private func sendButtonBackground(isSending: Bool, hasDraft: Bool) -> AnyShapeStyle {
        if isSending {
            return AnyShapeStyle(LinearGradient(
                colors: [CFTheme.danger, CFTheme.danger.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
        if hasDraft {
            return AnyShapeStyle(LinearGradient(
                colors: [CFTheme.accent, CFTheme.accent.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
        return AnyShapeStyle(CFTheme.textTertiary.opacity(0.15))
    }

    private func beginSend(_ operation: @escaping @MainActor () async -> Void) {
        sendTask?.cancel()
        sendTask = Task {
            await operation()
            sendTask = nil
        }
    }

    private func stopSending() {
        sendTask?.cancel()
        sendTask = nil
    }

    private var setupCTA: some View {
        VStack(spacing: 16) {
            Spacer()
            CFIconBadge(symbolName: "sparkles", tint: CFTheme.textTertiary, size: 44)
            Text("Configure um provedor de IA")
                .font(CFTheme.chatHeadline())
                .foregroundStyle(CFTheme.textPrimary)
            Text("Vá em Inteligência nas configurações para conversar com \(AIAssistantIdentity.name).")
                .font(CFTheme.chatBody())
                .foregroundStyle(CFTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }

    // MARK: - Actions

    private func resetConversationPresentationState() {
        pendingSettleMessageID = nil
        settledRevealMessageIDs = []
    }

    private func reconcileSelectedConversation() {
        guard let currentID = chatPanelState.selectedConversationID else {
            chatPanelState.selectedConversationID = conversations.first?.id
            return
        }
        if !conversations.contains(where: { $0.id == currentID }) {
            chatPanelState.selectedConversationID = conversations.first?.id
        }
    }

    private func createConversation() {
        let conversation = chatService.createConversation(in: modelContext)
        withAnimation(CFMotion.snappy) {
            chatPanelState.selectedConversationID = conversation.id
        }
    }

    private func send() async {
        let text = chatPanelState.draft
        chatPanelState.draft = ""
        await send(text: text)
    }

    private func send(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard aiService.configuration.isReady else { return }
        var conversation = selectedConversation
        if conversation == nil {
            conversation = chatService.createConversation(in: modelContext)
            chatPanelState.selectedConversationID = conversation?.id
        }
        guard let conversation else { return }

        withAnimation(CFMotion.snappy) {
            isSending = true
        }
        errorMessage = nil
        chatPanelState.beginToolTrace()

        do {
            let result = try await chatService.sendMessage(
                trimmed,
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
                    chatPanelState.handleAgentStatus(
                        update,
                        treatWriteToolsAsProposals: aiService.activeProviderUsesExternalMCPTools
                    )
                },
                onPartialContent: nil
            )
            chatPanelState.agentMessages = result.agentMessages
            chatPanelState.pendingWrite = result.pendingWrite ?? MCPWriteProposalStore.shared.pendingWrite
            if let assistantID = result.assistantMessageID,
               let assistantMessage = conversation.messages.first(where: { $0.id == assistantID }) {
                chatPanelState.finalizeToolTrace(
                    for: assistantID,
                    message: assistantMessage,
                    context: modelContext
                )
            } else if result.pendingWrite == nil, MCPWriteProposalStore.shared.pendingWrite == nil {
                chatPanelState.beginToolTrace()
            }
        } catch is CancellationError {
            handleSendCancellation(conversation: conversation)
        } catch {
            if Task.isCancelled {
                handleSendCancellation(conversation: conversation)
            } else {
                errorMessage = error.localizedDescription
                chatPanelState.beginToolTrace()
            }
        }
        finishSending(for: conversation)
    }

    private func handleSendCancellation(conversation: ChatConversation) {
        errorMessage = nil
        if let assistant = conversation.messages
            .sorted(by: { $0.createdAt < $1.createdAt })
            .last(where: { $0.role == .assistant }) {
            let trimmed = assistant.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                conversation.messages.removeAll { $0.id == assistant.id }
                modelContext.delete(assistant)
                chatPanelState.beginToolTrace()
            } else {
                chatPanelState.finalizeToolTrace(
                    for: assistant.id,
                    message: assistant,
                    context: modelContext
                )
            }
        } else {
            chatPanelState.beginToolTrace()
        }
        conversation.updatedAt = .now
        try? modelContext.save()
    }

    private func confirmPendingWrite(_ pending: AIPendingWriteAction) async {
        if pending.source == .mcp {
            await confirmMCPPendingWrite(pending)
            return
        }

        guard let conversation = selectedConversation else { return }
        withAnimation(CFMotion.snappy) {
            isSending = true
        }
        errorMessage = nil
        chatPanelState.markWriteProposalConfirmed(
            callID: pending.toolCallID,
            toolName: pending.toolName
        )
        finalizeWriteProposalTrace()
        chatPanelState.pendingWrite = nil
        chatPanelState.beginToolTrace()

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
                    chatPanelState.handleAgentStatus(
                        update,
                        treatWriteToolsAsProposals: aiService.activeProviderUsesExternalMCPTools
                    )
                },
                onPartialContent: nil
            )
            chatPanelState.agentMessages = result.agentMessages
            chatPanelState.pendingWrite = result.pendingWrite ?? MCPWriteProposalStore.shared.pendingWrite
            AIWriteActionLogger.log(pending, confirmed: true, in: modelContext)
            if let assistantID = result.assistantMessageID,
               let assistantMessage = conversation.messages.first(where: { $0.id == assistantID }) {
                chatPanelState.finalizeToolTrace(
                    for: assistantID,
                    message: assistantMessage,
                    context: modelContext
                )
            } else {
                chatPanelState.beginToolTrace()
            }
        } catch is CancellationError {
            handleSendCancellation(conversation: conversation)
        } catch {
            if Task.isCancelled {
                handleSendCancellation(conversation: conversation)
            } else {
                errorMessage = error.localizedDescription
                chatPanelState.beginToolTrace()
            }
        }
        finishSending(for: conversation)
    }

    private func confirmMCPPendingWrite(_ pending: AIPendingWriteAction) async {
        errorMessage = nil
        chatPanelState.pendingWrite = nil

        do {
            try MCPWriteProposalService.apply(pending, container: modelContext.container)
            AIWriteActionLogger.log(pending, confirmed: true, in: modelContext)
            chatPanelState.markWriteProposalConfirmed(
                callID: pending.toolCallID,
                toolName: pending.toolName
            )
            finalizeWriteProposalTrace()

            if aiService.activeProviderUsesExternalMCPTools {
                await send(text: ChatPrompts.writeConfirmationContinuation(summary: pending.summary))
            }
        } catch {
            errorMessage = error.localizedDescription
            chatPanelState.pendingWrite = pending
        }
    }

    private func cancelPendingWrite(_ pending: AIPendingWriteAction) {
        AIWriteActionLogger.log(pending, confirmed: false, in: modelContext)
        chatPanelState.markWriteProposalCancelled(
            callID: pending.toolCallID,
            toolName: pending.toolName
        )
        finalizeWriteProposalTrace()
        chatPanelState.pendingWrite = nil

        if pending.source == .mcp {
            MCPWriteProposalService.markCancelled(pending.id, container: modelContext.container)
            return
        }

        chatPanelState.agentMessages = []
        chatPanelState.beginToolTrace()
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
