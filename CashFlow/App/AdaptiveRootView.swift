import SwiftUI
import SwiftData

struct AdaptiveRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            #if os(iOS)
            if horizontalSizeClass == .compact {
                CompactTabRootView()
                    .environment(\.cfLayoutMode, .compact)
            } else {
                RootSidebarView(pinSidebar: false)
                    .environment(\.cfLayoutMode, .regular)
            }
            #else
            RootSidebarView(pinSidebar: true)
                .environment(\.cfLayoutMode, .regular)
            #endif
        }
        .background(CFTheme.surfacePrimary)
        .overlay { WidgetSnapshotSync() }
        .overlay { SpotlightSearchLayer() }
        .onAppear(perform: runStartupTasks)
    }

    private func runStartupTasks() {
        AppSettingsBootstrap.ensureExists(context: modelContext)
        GoalAccountBootstrap.migrateLegacyManualGoals(context: modelContext)
        RecurringExpenseMaterializer.materializeAll(context: modelContext)
        RecurringIncomeMaterializer.materializeAll(context: modelContext)
        CardStatementMaterializer.materializeAll(context: modelContext)
        try? modelContext.save()
        migrateSecureCredentialsIfNeeded()
        resyncNotifications()
    }

    private func resyncNotifications() {
        Task { @MainActor in
            await BillNotifications.ensureAuthorization()
            await ReceivableNotifications.ensureAuthorization()

            let billDescriptor = FetchDescriptor<Bill>()
            let receivableDescriptor = FetchDescriptor<Receivable>()

            if let bills = try? modelContext.fetch(billDescriptor) {
                BillNotifications.resync(pending: bills)
            }
            if let receivables = try? modelContext.fetch(receivableDescriptor) {
                ReceivableNotifications.resync(pending: receivables)
            }
        }
    }

    private func migrateSecureCredentialsIfNeeded() {
        for key in [SecureStore.Key.openAIAPIKey, .anthropicAPIKey, .openAICompatibleAPIKey] {
            guard let value = SecureStore.read(key) else { continue }
            try? SecureStore.save(value, for: key)
        }

        let configuration = AIConfiguration()
        for provider in configuration.customProviders {
            guard let value = SecureStore.readCustomProviderAPIKey(provider.id) else { continue }
            try? SecureStore.saveCustomProviderAPIKey(value, providerID: provider.id)
        }
    }
}

private enum CompactTab: Hashable {
    case overview
    case flow
    case payables
    case settings
}

private struct CompactTabRootView: View {
    @State private var selectedTab: CompactTab = .overview

    var body: some View {
        TabView(selection: $selectedTab) {
            CompactOverviewTab()
                .tabItem { Label("Visão", systemImage: "chart.pie.fill") }
                .tag(CompactTab.overview)

            NavigationStack {
                SidebarDetailView(destination: .transactions)
                    .navigationTitle("Lançamentos")
            }
            .aiChatPresentation()
            .tabItem { Label("Fluxo", systemImage: "list.bullet.rectangle.fill") }
            .tag(CompactTab.flow)

            CompactPayablesTab()
                .tabItem { Label("Pagar", systemImage: "calendar.badge.clock") }
                .tag(CompactTab.payables)

            CompactSettingsTab()
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
                .tag(CompactTab.settings)
        }
    }
}

private struct CompactOverviewTab: View {
    @State private var destination: SidebarDestination? = .dashboard

    var body: some View {
        NavigationStack {
            List {
                Section("Visão") {
                    destinationRow(.dashboard)
                    destinationRow(.goals)
                    destinationRow(.wishlist)
                    destinationRow(.investments)
                }
            }
            .navigationTitle("CashFlow")
            .navigationDestination(item: $destination) { item in
                SidebarDetailView(destination: item)
                    .navigationTitle(item.title)
            }
        }
        .aiChatPresentation()
    }

    private func destinationRow(_ item: SidebarDestination) -> some View {
        Button {
            destination = item
        } label: {
            Label(item.title, systemImage: item.symbolName)
        }
    }
}

private struct CompactPayablesTab: View {
    @State private var destination: SidebarDestination? = .bills

    var body: some View {
        NavigationStack {
            List {
                destinationRow(.bills)
                destinationRow(.recurringExpenses)
            }
            .navigationTitle("Contas")
            .navigationDestination(item: $destination) { item in
                SidebarDetailView(destination: item)
                    .navigationTitle(item.title)
            }
        }
        .aiChatPresentation()
    }

    private func destinationRow(_ item: SidebarDestination) -> some View {
        Button {
            destination = item
        } label: {
            Label(item.title, systemImage: item.symbolName)
        }
    }
}

private struct CompactSettingsTab: View {
    @State private var destination: SidebarDestination? = .categories

    var body: some View {
        NavigationStack {
            List {
                destinationRow(.categories)
                destinationRow(.accounts)
                destinationRow(.intelligence)
            }
            .navigationTitle("Ajustes")
            .navigationDestination(item: $destination) { item in
                SidebarDetailView(destination: item)
                    .navigationTitle(item.title)
            }
        }
        .aiChatPresentation()
    }

    private func destinationRow(_ item: SidebarDestination) -> some View {
        Button {
            destination = item
        } label: {
            Label(item.title, systemImage: item.symbolName)
        }
    }
}
