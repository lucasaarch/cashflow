//
//  CashFlowApp.swift
//  CashFlow
//
//  Created by Lucas Arch on 16/06/26.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

@main
struct CashFlowApp: App {
    @StateObject private var aiService = AIService()
    @StateObject private var chatPanelState = AIChatPanelState()
    @StateObject private var sidebarNavigation = SidebarNavigationState()
    @StateObject private var spotlightState = SpotlightPresentationState()
    @StateObject private var spotlightNavigation = SpotlightNavigationState()

    var sharedModelContainer: ModelContainer = ModelContainerFactory.make()
    #if os(macOS)
    @StateObject private var mcpServer = MCPServerCoordinator.shared
    #endif

    var body: some Scene {
        WindowGroup {
            AdaptiveRootView()
                .environmentObject(aiService)
                .environmentObject(chatPanelState)
                .environmentObject(sidebarNavigation)
                .environmentObject(spotlightState)
                .environmentObject(spotlightNavigation)
                .onAppear {
                    handlePendingShortcut()
                    MCPWriteProposalPersistence.restorePending(
                        into: MCPWriteProposalStore.shared,
                        container: sharedModelContainer
                    )
                    chatPanelState.adoptPendingWriteFromMCPStore()
                    #if os(macOS)
                    mcpServer.configure(container: sharedModelContainer)
                    #endif
                }
                .onReceive(NotificationCenter.default.publisher(for: .mcpWriteProposalCreated)) { notification in
                    guard let pending = notification.object as? AIPendingWriteAction else { return }
                    chatPanelState.pendingWrite = pending
                    if !chatPanelState.isOpen {
                        chatPanelState.ensureOpen()
                    }
                }
                #if os(macOS)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    mcpServer.stop()
                }
                #endif
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 600)
                #endif
        }
        .modelContainer(sharedModelContainer)
#if os(macOS)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Conversar com \(AIAssistantIdentity.name)…") {
                    if !chatPanelState.isOpen {
                        spotlightState.close()
                    }
                    chatPanelState.toggle()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Button("Buscar em tudo…") {
                    if !spotlightState.isPresented {
                        chatPanelState.close()
                    }
                    spotlightState.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
#endif
    }

    private func handlePendingShortcut() {
        guard UserDefaults.standard.string(forKey: CashFlowShortcutKeys.pendingAction) == "openChat" else { return }
        UserDefaults.standard.removeObject(forKey: CashFlowShortcutKeys.pendingAction)
        chatPanelState.openFresh()
    }
}
