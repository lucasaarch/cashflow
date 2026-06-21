import SwiftData
import SwiftUI

/// Ações da Gio na toolbar nativa — cápsula à direita enquanto o inspector está aberto.
struct AIChatInspectorToolbarCapsule: View {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var chatPanelState: AIChatPanelState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ChatConversation.updatedAt, order: .reverse)])
    private var conversations: [ChatConversation]

    @State private var showingHistory = false
    @State private var showDeleteConversationAlert = false

    private var chatService: AIChatService {
        AIChatService(aiService: aiService)
    }

    private var selectedConversation: ChatConversation? {
        if let id = chatPanelState.selectedConversationID,
           let match = conversations.first(where: { $0.id == id }) {
            return match
        }
        return conversations.first
    }

    var body: some View {
        capsuleContent
            .alert("Apagar esta conversa?", isPresented: $showDeleteConversationAlert) {
                Button("Apagar", role: .destructive) {
                    deleteSelectedConversation()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("As mensagens desta conversa serão removidas permanentemente.")
            }
    }

    private var capsuleContent: some View {
        capsuleButtons
            .cfGlassToolbarIconCapsule()
    }

    private var capsuleButtons: some View {
        HStack(spacing: 0) {
            capsuleIconButton(symbol: "plus", help: "Nova conversa") {
                createConversation()
            }

            if selectedConversation != nil {
                capsuleIconButton(symbol: "trash", help: "Apagar conversa atual") {
                    showDeleteConversationAlert = true
                }
            }

            historyButton
        }
    }

    private func capsuleIconButton(symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .cfGlassToolbarCapsuleSegmentButton()
        .help(help)
    }

    private var historyButton: some View {
        Button {
            showingHistory = true
        } label: {
            Image(systemName: "clock.arrow.circlepath")
        }
        .cfGlassToolbarCapsuleSegmentButton()
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

    private func createConversation() {
        let conversation = chatService.createConversation(in: modelContext)
        withAnimation(CFMotion.snappy) {
            chatPanelState.selectedConversationID = conversation.id
        }
    }

    private func deleteSelectedConversation() {
        guard let conversation = selectedConversation else { return }
        let deletingID = conversation.id
        chatService.deleteConversation(conversation, in: modelContext)
        chatPanelState.selectedConversationID = conversations.first(where: { $0.id != deletingID })?.id
    }
}

struct AIChatConversationHistoryPicker: View {
    let conversations: [ChatConversation]
    let selectedConversationID: UUID?
    let onSelect: (ChatConversation) -> Void

    var body: some View {
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
        let isSelected = selectedConversationID == conversation.id

        return Button {
            onSelect(conversation)
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
}
