import SwiftData
import SwiftUI

/// Keeps the home-screen widget snapshot in sync with SwiftData.
struct WidgetSnapshotSync: View {
    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse)])
    private var transactions: [Transaction]

    @Query(sort: [SortDescriptor(\Bill.dueDate)])
    private var bills: [Bill]

    @EnvironmentObject private var privacy: PrivacyMode
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .task(id: syncToken) {
                publish()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { publish() }
            }
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { notification in
                guard let savedContext = notification.object as? ModelContext,
                      savedContext.container == modelContext.container
                else { return }
                publish()
            }
    }

    /// Re-publish whenever balances or pending bills change.
    private var syncToken: String {
        let overview = FinancialOverview(
            accounts: accounts,
            transactions: transactions,
            bills: bills
        )
        let pendingBillSignature = bills
            .filter(\.isPending)
            .map { "\($0.id.uuidString)|\($0.statusRaw)|\($0.amount)|\($0.dueDate.timeIntervalSinceReferenceDate)" }
            .joined(separator: ";")

        return [
            "\(accounts.count)",
            "\(transactions.count)",
            "\(overview.netWorth.minorUnits)",
            "\(overview.liquidBalance.minorUnits)",
            "\(overview.totalInvestedBalance.minorUnits)",
            "\(overview.pendingBillsTotal.minorUnits)",
            pendingBillSignature,
            privacy.valuesHidden ? "hidden" : "visible"
        ].joined(separator: "|")
    }

    private func publish() {
        WidgetSnapshotPublisher.publish(
            accounts: accounts,
            transactions: transactions,
            bills: bills,
            valuesHidden: privacy.valuesHidden
        )
    }
}
