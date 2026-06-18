//
//  CashFlowApp.swift
//  CashFlow
//
//  Created by Lucas Arch on 16/06/26.
//

import SwiftUI
import SwiftData

@main
struct CashFlowApp: App {
    @StateObject private var aiService = AIService()
    @StateObject private var chatPanelState = AIChatPanelState()
    @StateObject private var privacyMode = PrivacyMode()

    var sharedModelContainer: ModelContainer = ModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            AdaptiveRootView()
                .environmentObject(aiService)
                .environmentObject(chatPanelState)
                .environmentObject(privacyMode)
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 600)
                #endif
        }
        .modelContainer(sharedModelContainer)
#if os(macOS)
        .windowResizability(.contentSize)
#endif
    }
}
