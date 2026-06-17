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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Transaction.self,
            Category.self,
            Account.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            SeedData.seedIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootSidebarView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            SidebarCommands()
        }
#if os(macOS)
        .windowResizability(.contentSize)
#endif
    }
}
