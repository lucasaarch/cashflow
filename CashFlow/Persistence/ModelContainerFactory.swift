import Foundation
import SwiftData

enum ModelContainerFactory {
    private static let schema = Schema([
        AppSettings.self,
        Transaction.self,
        Category.self,
        Account.self,
        InstallmentPlan.self,
        RecurringExpense.self,
        RecurringIncome.self,
        Bill.self,
        Receivable.self,
        FinancialGoal.self,
        WishlistItem.self,
        ChatConversation.self,
        ChatMessage.self,
        ChatToolActivity.self,
        AIWriteActionLogEntry.self,
        AIPendingWriteProposal.self
    ])

    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKitDatabase(inMemory: inMemory)
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            NSLog("ModelContainer load failed: \(error). Resetting local store and retrying.")
            if !inMemory {
                resetStoreFiles(at: configuration.url)
            }
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Could not create ModelContainer after store reset: \(error)")
            }
        }
    }

    private static func cloudKitDatabase(inMemory: Bool) -> ModelConfiguration.CloudKitDatabase {
        #if CLOUDKIT_SYNC
        inMemory ? .none : .private(CloudKitSync.containerIdentifier)
        #else
        .none
        #endif
    }

    private static func resetStoreFiles(at url: URL) {
        let directory = url.deletingLastPathComponent()
        let prefix = url.lastPathComponent
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
