import SwiftUI
import SwiftData

struct AIChatSidePanel: View {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var chatPanelState: AIChatPanelState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ChatConversation.updatedAt, order: .reverse)])
    private var conversations: [ChatConversation]

    @Query private var transactions: [Transaction]
    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var accounts: [Account]

    @AppStorage(UserDefaultsKeys.monthlyIncomeCents) private var monthlyIncomeCents = 0

    @State private var selectedConversationID: UUID?
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showDeleteAllAlert = false

    private let chatService: AIChatService

    init(aiService: AIService) {
        chatService = AIChatService(aiService: aiService)
    }

    private var selectedConversation: ChatConversation? {
        if let id = selectedConversationID {
            return conversations.first { $0.id == id }
        }
        return conversations.first
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if aiService.configuration.isReady {
                conversationControls
                Divider()
                messagesList
                Divider()
                inputBar
            } else {
                setupCTA
            }
        }
        .frame(width: 380)
        .background(CFTheme.surfacePrimary)
        .onAppear {
            if selectedConversationID == nil {
                selectedConversationID = conversations.first?.id
            }
        }
        .alert("Apagar todas as conversas?", isPresented: $showDeleteAllAlert) {
            Button("Apagar", role: .destructive) {
                chatService.deleteAllConversations(conversations, in: modelContext)
                selectedConversationID = nil
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
    }

    private var header: some View {
        HStack {
            Text("Saúde financeira")
                .font(CFTheme.headline())
                .foregroundStyle(CFTheme.textPrimary)
            Spacer()
            Button {
                chatPanelState.close()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(CFTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var conversationControls: some View {
        HStack(spacing: 8) {
            CFSelectFieldOptional(
                selection: $selectedConversationID,
                options: conversations.map {
                    CFSelectOption(id: $0.id, title: $0.title)
                },
                placeholder: "Conversas"
            )
            Button {
                let conversation = chatService.createConversation(in: modelContext)
                selectedConversationID = conversation.id
            } label: {
                Label("Nova", systemImage: "plus")
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let conversation = selectedConversation {
                        ForEach(conversation.messages.sorted(by: { $0.createdAt < $1.createdAt }), id: \.id) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    } else {
                        Text("Comece uma conversa sobre suas finanças.")
                            .font(CFTheme.body())
                            .foregroundStyle(CFTheme.textSecondary)
                            .padding()
                    }
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 12)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(CFTheme.caption())
                            .foregroundStyle(CFTheme.expense)
                            .padding(.horizontal, 12)
                    }
                }
                .padding(12)
            }
            .onChange(of: selectedConversation?.messages.count) { _, _ in
                if let last = selectedConversation?.messages.last?.id {
                    withAnimation(CFMotion.snappy) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        let isUser = message.role == .user
        return HStack {
            if isUser { Spacer(minLength: 24) }
            Text(message.content.isEmpty && isSending && !isUser ? "…" : message.content)
                .font(CFTheme.body())
                .foregroundStyle(isUser ? CFTheme.textPrimary : CFTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isUser ? CFTheme.accent.opacity(0.18) : CFTheme.surfaceElevated.opacity(0.55))
                )
            if !isUser { Spacer(minLength: 24) }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Pergunte sobre suas finanças…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(10)
                    .cfFieldChrome(isFocused: false)
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(CFTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            HStack {
                Button("Apagar todas as conversas", role: .destructive) {
                    showDeleteAllAlert = true
                }
                .buttonStyle(.borderless)
                .font(CFTheme.caption())
                Spacer()
            }
        }
        .padding(12)
    }

    private var setupCTA: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Configure um provedor de IA para usar o chat.")
                .font(CFTheme.body())
                .foregroundStyle(CFTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(20)
    }

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
        let text = draft
        draft = ""

        do {
            try await chatService.sendMessage(
                text,
                in: conversation,
                transactions: transactions,
                accounts: accounts,
                monthlyIncomeCents: monthlyIncomeCents,
                context: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}
