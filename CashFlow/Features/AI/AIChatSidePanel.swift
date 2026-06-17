import SwiftUI
import SwiftData

enum AIChatPanelPresentation {
    case sidebarOverlay
    case sheet
}

struct AIChatSidePanel: View {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var chatPanelState: AIChatPanelState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: [SortDescriptor(\ChatConversation.updatedAt, order: .reverse)])
    private var conversations: [ChatConversation]

    @Query private var transactions: [Transaction]
    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var accounts: [Account]
    @Query private var goals: [FinancialGoal]

    @Query(filter: #Predicate<AppSettings> { $0.id == "default" })
    private var appSettings: [AppSettings]

    @State private var selectedConversationID: UUID?
    @State private var draft = ""
    @State private var isSending = false
    @State private var typewriterMessageID: UUID?
    @State private var errorMessage: String?
    @State private var showDeleteConversationAlert = false
    @FocusState private var isInputFocused: Bool

    private let chatService: AIChatService
    private let presentation: AIChatPanelPresentation

    private let suggestions = [
        "Como está meu ritmo de gastos?",
        "Onde posso economizar este mês?",
        "Resuma minha situação financeira"
    ]

    init(aiService: AIService, presentation: AIChatPanelPresentation = .sidebarOverlay) {
        chatService = AIChatService(aiService: aiService)
        self.presentation = presentation
    }

    private var selectedConversation: ChatConversation? {
        if let id = selectedConversationID {
            return conversations.first { $0.id == id }
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
                conversationBar
                messagesList
                inputBar
            } else {
                setupCTA
            }
        }
        .frame(maxWidth: presentation == .sidebarOverlay ? 400 : .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [CFTheme.surfacePrimary, CFTheme.surfacePrimary.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            if selectedConversationID == nil {
                selectedConversationID = conversations.first?.id
            }
        }
        .alert("Apagar esta conversa?", isPresented: $showDeleteConversationAlert) {
            Button("Apagar", role: .destructive) { deleteSelectedConversation() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("As mensagens desta conversa serão removidas permanentemente.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            CFIconBadge(symbolName: "sparkles", tint: CFTheme.accent, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Saúde financeira")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CFTheme.textPrimary)
                Text("Assistente com contexto das suas finanças")
                    .font(.caption2)
                    .foregroundStyle(CFTheme.textSecondary)
            }

            Spacer(minLength: 0)

            if selectedConversation != nil {
                Menu {
                    Button {
                        showDeleteConversationAlert = true
                    } label: {
                        Label("Apagar conversa", systemImage: "trash")
                    }
                    .disabled(conversations.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(CFTheme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
                .help("Opções da conversa")
            }

            Button {
                chatPanelState.close()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CFTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(CFTheme.textTertiary.opacity(0.12)))
            }
            .buttonStyle(.plain)
#if os(macOS)
            .keyboardShortcut(.escape, modifiers: [])
#endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(CFTheme.surfacePrimary.opacity(0.85))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }

    // MARK: - Conversation bar

    private var conversationBar: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(conversations) { conversation in
                    Button {
                        withAnimation(CFMotion.snappy) {
                            selectedConversationID = conversation.id
                        }
                    } label: {
                        if conversation.id == selectedConversation?.id {
                            Label(conversation.title, systemImage: "checkmark")
                        } else {
                            Text(conversation.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundStyle(CFTheme.accent)
                    Text(selectedConversation?.title ?? "Nova conversa")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(CFTheme.textPrimary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(CFTheme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(CFTheme.surfaceElevated.opacity(0.45))
                )
            }
            .menuStyle(.borderlessButton)

            Button {
                let conversation = chatService.createConversation(in: modelContext)
                withAnimation(CFMotion.snappy) {
                    selectedConversationID = conversation.id
                }
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CFTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(CFTheme.accent.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .help("Nova conversa")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
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
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: sortedMessages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: sortedMessages.last?.content) { _, _ in scrollToBottom(proxy) }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pergunte qualquer coisa")
                    .font(.headline)
                    .foregroundStyle(CFTheme.textPrimary)
                Text("O assistente analisa seus lançamentos, contas, metas e ritmo de gastos.")
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
                        draft = suggestion
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
        .cfStaggerAppear(index: index)
    }

    private func userBubble(_ message: ChatMessage) -> some View {
        HStack {
            Spacer(minLength: 48)
            Text(message.content)
                .font(CFTheme.body())
                .foregroundStyle(CFTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [CFTheme.accent.opacity(0.22), CFTheme.accent.opacity(0.14)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(CFTheme.accent.opacity(0.2), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func assistantBubble(_ message: ChatMessage) -> some View {
        let isStreaming = isSending && message.role == .assistant && message.id == sortedMessages.last?.id
        let useTypewriter = typewriterMessageID == message.id && !isStreaming

        HStack(alignment: .top, spacing: 10) {
            CFIconBadge(symbolName: "sparkles", tint: CFTheme.accent, size: 28)

            VStack(alignment: .leading, spacing: 0) {
                if isStreaming {
                    assistantSkeleton
                } else if useTypewriter {
                    CFTypewriter(text: message.content, markdown: true, animated: true)
                        .font(CFTheme.body())
                        .foregroundStyle(CFTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                } else {
                    CFMarkdownText(text: message.content)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CFTheme.surfaceElevated.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(CFTheme.textTertiary.opacity(0.1), lineWidth: 1)
            )

            Spacer(minLength: 16)
        }
    }

    private var assistantSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            CFSkeletonLine(height: 10, widthFraction: 0.92)
            CFSkeletonLine(height: 10, widthFraction: 0.78)
            CFSkeletonLine(height: 10, widthFraction: 0.55)
        }
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

    // MARK: - Input

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.5)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Pergunte sobre suas finanças…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(CFTheme.body())
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(CFTheme.surfaceElevated.opacity(0.45))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isInputFocused ? CFTheme.accent.opacity(0.35) : CFTheme.textTertiary.opacity(0.12),
                                lineWidth: isInputFocused ? 1.5 : 1
                            )
                    )
                    .animation(reduceMotion ? nil : CFMotion.snappy, value: isInputFocused)

                sendButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(CFTheme.surfacePrimary.opacity(0.9))
    }

    private var sendButton: some View {
        let canSend = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending

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
#if os(macOS)
        .keyboardShortcut(.return, modifiers: [])
#endif
    }

    private var setupCTA: some View {
        VStack(spacing: 16) {
            Spacer()
            CFIconBadge(symbolName: "sparkles", tint: CFTheme.textTertiary, size: 44)
            Text("Configure um provedor de IA")
                .font(.headline)
                .foregroundStyle(CFTheme.textPrimary)
            Text("Vá em Inteligência nas configurações para conectar OpenAI, Anthropic ou Ollama.")
                .font(.callout)
                .foregroundStyle(CFTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }

    // MARK: - Actions

    private func send() async {
        guard aiService.configuration.isReady else { return }
        var conversation = selectedConversation
        if conversation == nil {
            conversation = chatService.createConversation(in: modelContext)
            selectedConversationID = conversation?.id
        }
        guard let conversation else { return }

        isSending = true
        errorMessage = nil
        typewriterMessageID = nil
        let text = draft
        draft = ""

        do {
            if let assistantID = try await chatService.sendMessage(
                text,
                in: conversation,
                transactions: transactions,
                accounts: accounts,
                goals: goals,
                monthlyIncomeCents: appSettings.first?.monthlyIncomeCents ?? 0,
                context: modelContext
            ) {
                typewriterMessageID = assistantID
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }

    private func deleteSelectedConversation() {
        guard let conversation = selectedConversation else { return }
        let deletingID = conversation.id
        chatService.deleteConversation(conversation, in: modelContext)
        selectedConversationID = conversations.first(where: { $0.id != deletingID })?.id
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = sortedMessages.last?.id else { return }
        withAnimation(reduceMotion ? nil : CFMotion.snappy) {
            proxy.scrollTo(last, anchor: .bottom)
        }
    }
}
