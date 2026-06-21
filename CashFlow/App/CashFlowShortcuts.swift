import AppIntents

enum CashFlowShortcutKeys {
    nonisolated static let pendingAction = "cashflow.pendingShortcut"
}

struct OpenCashFlowIntent: AppIntent {
    static var title: LocalizedStringResource = "Abrir CashFlow"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct OpenAIChatIntent: AppIntent {
    static var title: LocalizedStringResource = "Conversar com a Gio"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set("openChat", forKey: CashFlowShortcutKeys.pendingAction)
        return .result()
    }
}

struct CashFlowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenCashFlowIntent(),
            phrases: [
                "Abrir \(.applicationName)",
                "Ver finanças no \(.applicationName)"
            ],
            shortTitle: "Abrir CashFlow",
            systemImageName: "chart.pie.fill"
        )
        AppShortcut(
            intent: OpenAIChatIntent(),
            phrases: [
                "Conversar com a Gio no \(.applicationName)",
                "Perguntar para a Gio no \(.applicationName)"
            ],
            shortTitle: "Chat com Gio",
            systemImageName: "bubble.left.and.bubble.right.fill"
        )
    }
}
