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

    var sharedModelContainer: ModelContainer = {
        DataReset.wipeStoreIfNeeded()

        let schema = Schema([
            Transaction.self,
            Category.self,
            Account.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootSidebarView()
                .environmentObject(aiService)
                .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(sharedModelContainer)
#if os(macOS)
        .windowResizability(.contentSize)
#endif
    }
}
