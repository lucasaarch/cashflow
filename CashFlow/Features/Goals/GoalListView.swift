import SwiftUI
import SwiftData

struct GoalListView: View {
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @EnvironmentObject private var spotlightNavigation: SpotlightNavigationState
    #endif

    @Query(sort: [SortDescriptor(\FinancialGoal.createdAt, order: .reverse)])
    private var goals: [FinancialGoal]

    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse)])
    private var transactions: [Transaction]

    @State private var showingAdd = false
    @State private var editingGoal: FinancialGoal?
    #if os(macOS)
    @State private var highlightedGoalID: UUID?
    @State private var spotlightFocusTask: Task<Void, Never>?
    #endif

    private var activeGoals: [FinancialGoal] {
        goals.filter { !$0.isCompleted }
    }

    private var completedGoals: [FinancialGoal] {
        goals.filter { $0.isCompleted }
    }

    var body: some View {
        Group {
            if goals.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Metas")
        .detailToolbarAdd(help: "Cadastrar meta de longo prazo") {
            showingAdd = true
        }
        .sheet(isPresented: $showingAdd) {
            AddGoalSheet()
        }
        .sheet(item: $editingGoal) { goal in
            AddGoalSheet(editing: goal)
        }
        .cfGlassDetailChrome()
    }

    private var emptyState: some View {
        CFEmptyState(
            symbol: "flag.fill",
            title: "Nenhuma meta definida",
            message: "Crie metas para reserva de emergência, viagem, aposentadoria ou qualquer objetivo de longo prazo.",
            actionTitle: "Criar meta"
        ) {
            showingAdd = true
        }
    }

    private var content: some View {
        ScrollViewReader { proxy in
            CFGlassPage {
                CFGlassPageStack {
                    if !activeGoals.isEmpty {
                        goalsSection(
                            title: "Em andamento",
                            goals: activeGoals,
                            staggerIndex: 0
                        )
                    }

                    if !completedGoals.isEmpty {
                        goalsSection(
                            title: "Concluídas",
                            goals: completedGoals,
                            dimmed: true,
                            staggerIndex: activeGoals.isEmpty ? 0 : 1
                        )
                    }
                }
            }
            #if os(macOS)
            .spotlightScrollTarget(
                navigation: spotlightNavigation,
                kind: .goal,
                highlightedID: $highlightedGoalID,
                focusTask: $spotlightFocusTask,
                proxy: proxy,
                onReveal: { id in
                    if let goal = goals.first(where: { $0.id == id }) {
                        editingGoal = goal
                    }
                }
            )
            #endif
        }
    }

    private func goalsSection(
        title: String,
        goals: [FinancialGoal],
        dimmed: Bool = false,
        staggerIndex: Int
    ) -> some View {
        CFGlassSection(title: title, staggerIndex: staggerIndex) {
            CFGlassEnumeratedPanel(items: goals, dividerStyle: .fullWidth) { goal, _ in
                let snapshot = GoalProgressCalculator.snapshot(for: goal, transactions: transactions)
                CFGlassRowButton {
                    editingGoal = goal
                } label: {
                    GoalProgressCard(snapshot: snapshot, goal: goal)
                }
                .id(goal.id)
                #if os(macOS)
                .spotlightFocused(highlightedGoalID == goal.id)
                #endif
                .opacity(dimmed ? 0.75 : 1)
                .contextMenu {
                    if !goal.isCompleted {
                        Button {
                            goal.isCompleted = true
                            goal.completedAt = .now
                        } label: {
                            Label("Marcar como concluída", systemImage: "checkmark.circle")
                        }
                    } else {
                        Button {
                            goal.isCompleted = false
                            goal.completedAt = nil
                        } label: {
                            Label("Reabrir meta", systemImage: "arrow.uturn.backward")
                        }
                    }
                    Button {
                        editingGoal = goal
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        modelContext.delete(goal)
                    } label: {
                        Label("Excluir", systemImage: "trash")
                    }
                }
            }
        }
    }
}
