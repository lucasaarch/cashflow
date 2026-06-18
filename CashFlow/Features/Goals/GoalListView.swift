import SwiftUI
import SwiftData

struct GoalListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\FinancialGoal.createdAt, order: .reverse)])
    private var goals: [FinancialGoal]

    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse)])
    private var transactions: [Transaction]

    @State private var showingAdd = false
    @State private var editingGoal: FinancialGoal?

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Nova meta", systemImage: "plus")
                }
                .help("Cadastrar meta de longo prazo")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddGoalSheet()
        }
        .sheet(item: $editingGoal) { goal in
            AddGoalSheet(editing: goal)
        }
        .cfPageBackground()
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
        CFScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !activeGoals.isEmpty {
                    section(title: "Em andamento", goals: activeGoals)
                }
                if !completedGoals.isEmpty {
                    section(title: "Concluídas", goals: completedGoals, dimmed: true)
                }
            }
            .padding(20)
        }
    }

    private func section(title: String, goals: [FinancialGoal], dimmed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            ForEach(goals) { goal in
                let snapshot = GoalProgressCalculator.snapshot(for: goal, transactions: transactions)
                CFHoverRow {
                    GoalProgressCard(snapshot: snapshot, goal: goal)
                }
                .opacity(dimmed ? 0.75 : 1)
                .contentShape(Rectangle())
                .onTapGesture { editingGoal = goal }
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
