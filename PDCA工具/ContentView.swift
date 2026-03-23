import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.creationDate, order: .reverse) private var goals: [Goal]
    @State private var healthManager = HealthManager.shared

    @State private var isShowingAddGoalAlert = false
    @State private var newGoalTitle = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // UI 锁定：全局背景
                LinearGradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1), .white],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                List {
                    Section {
                        HealthGlassCard(healthManager: healthManager)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    
                    Section(header: Text("我的目标")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .textCase(nil)
                    ) {
                        ForEach(goals) { goal in
                            NavigationLink(destination: GoalDetailView(goal: goal)) {
                                GoalRow(goal: goal)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: deleteGoals)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Flow PDCA")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: promptAddGoal) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.blue.gradient)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton().font(.subheadline)
                }
            }
            .alert("设定新目标", isPresented: $isShowingAddGoalAlert) {
                TextField("例如：本周看完一本商业管理书", text: $newGoalTitle)
                Button("取消", role: .cancel) { }
                Button("确定", action: saveNewGoal)
            } message: {
                Text("输入明确的目标，AI 才能给出精准的拆解计划。")
            }
        }
    }
    
    // MARK: - 意图分离
    private func promptAddGoal() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        newGoalTitle = ""
        isShowingAddGoalAlert = true
    }

    private func saveNewGoal() {
        guard !newGoalTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            let newGoal = Goal(title: newGoalTitle)
            modelContext.insert(newGoal)
        }
    }

    private func deleteGoals(offsets: IndexSet) {
        withAnimation {
            for index in offsets { modelContext.delete(goals[index]) }
        }
    }
}

// MARK: - 主页组件化
struct HealthGlassCard: View {
    var healthManager: HealthManager
    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Label("今日生理状态", systemImage: "sparkles")
                    .font(.caption).fontWeight(.bold).foregroundStyle(.blue.opacity(0.8))
                Spacer()
                if !healthManager.isAuthorized {
                    Button("授权") { healthManager.requestAuthorization() }
                        .font(.caption2).buttonStyle(.bordered).controlSize(.mini)
                }
            }
            HStack {
                StatView(icon: "figure.walk", value: "\(healthManager.todaySteps)", label: "步数", color: .green)
                Spacer()
                StatView(icon: "moon.stars.fill", value: "\(healthManager.sleepHoursLastNight)", label: "睡眠", color: .indigo)
                Spacer()
                StatView(icon: "brain.head.profile", value: "\(healthManager.focusMinutesToday)", label: "专注", color: .orange)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.5), lineWidth: 1))
        .padding(.vertical, 10)
    }
}

struct StatView: View {
    let icon: String; let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.title3).foregroundStyle(color.gradient)
            Text(value).font(.headline).bold()
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct GoalRow: View {
    let goal: Goal
    
    var isAllCompleted: Bool {
        goal.tasks.count > 0 && goal.tasks.allSatisfy { $0.isCompleted }
    }
    
    var progressText: String {
        let total = goal.tasks.count
        if total == 0 { return "待开启 PDCA" }
        let completed = goal.tasks.filter { $0.isCompleted }.count
        return "进行中 (已完成 \(completed)/\(total))"
    }
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                 Circle()
                    .fill(isAllCompleted ? Color.green.opacity(0.12) : Color.blue.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: isAllCompleted ? "checkmark" : "target")
                    .font(.caption)
                    .foregroundStyle(isAllCompleted ? Color.green : Color.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                Text("左滑可删除 • \(progressText)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 详情页
enum AIOperationMode {
    case append
    case rewriteUncompleted
    case clearAll
}

struct GoalDetailView: View {
    @Bindable var goal: Goal
    @Environment(\.modelContext) private var modelContext
    
    @State private var isDecomposing = false
    @State private var showingAIOptions = false
    
    var body: some View {
        List {
            GoalDetailHeader(goal: goal)
            
            if goal.tasks.isEmpty {
                GoalDetailEmptyState()
            } else {
                GoalDetailTaskList(goal: goal)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            GoalDetailBottomBar(isDecomposing: isDecomposing, onAction: handleAIButtonClick)
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("你想如何更新执行计划？", isPresented: $showingAIOptions, titleVisibility: .visible) {
            Button("补充更多关联任务") { executeAI(mode: .append) }
            Button("仅重写未完成的任务") { executeAI(mode: .rewriteUncompleted) }
            Button("推翻并重新生成 (清空所有)", role: .destructive) { executeAI(mode: .clearAll) }
            Button("取消", role: .cancel) { }
        } message: {
            Text("已完成的打卡记录建议保留。")
        }
    }
    
    private func handleAIButtonClick() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        if goal.tasks.isEmpty {
            executeAI(mode: .clearAll)
        } else {
            showingAIOptions = true
        }
    }
    
    private func executeAI(mode: AIOperationMode) {
        isDecomposing = true
        Task {
            do {
                let taskTitles = try await AIService.shared.decomposeGoal(title: goal.title)
                
                await MainActor.run {
                    withAnimation(.spring()) {
                        switch mode {
                        case .append:
                            break
                        case .rewriteUncompleted:
                            let tasksToDelete = goal.tasks.filter { !$0.isCompleted }
                            for oldTask in tasksToDelete { modelContext.delete(oldTask) }
                            goal.tasks.removeAll { !$0.isCompleted }
                        case .clearAll:
                            for oldTask in goal.tasks { modelContext.delete(oldTask) }
                            goal.tasks.removeAll()
                        }
                        
                        for title in taskTitles {
                            let newTask = PDCATask(title: title)
                            newTask.goal = goal
                            modelContext.insert(newTask)
                        }
                        isDecomposing = false
                    }
                }
            } catch {
                print("AI 拆解失败: \(error)")
                await MainActor.run { isDecomposing = false }
            }
        }
    }
}

// MARK: - 详情页子组件
struct GoalDetailHeader: View {
    @Bindable var goal: Goal
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 15) {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 30))
                    .foregroundStyle(.blue.gradient)
                
                TextField("输入目标标题", text: $goal.title, axis: .vertical)
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                    .background(Color.clear)
                    .environment(\.locale, Locale(identifier: "zh-Hans"))
            }
            .padding(.vertical, 5)
            .listRowBackground(Color.clear)
        }
    }
}

struct GoalDetailEmptyState: View {
    var body: some View {
        Section {
            Text("点击下方按钮，让 AI 结合 PDCA 逻辑为你拆解该目标。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .listRowBackground(Color.clear)
        }
    }
}

// 提取的修饰器
struct TaskCardStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white.opacity(0.6))
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            )
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .contentShape(Rectangle())
    }
}

// 独立的任务行组件
struct TaskRowView: View {
    let task: PDCATask
    
    private var iconName: String { task.isCompleted ? "checkmark.circle.fill" : "circle" }
    private var iconColor: Color { task.isCompleted ? .green : .blue }
    private var titleColor: Color { task.isCompleted ? .secondary : .primary }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(titleColor)
                
                Text("点击完成打卡")
                    .font(.system(size: 10))
                    // 修复点：彻底消灭类型报错，使用原生桥接颜色
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            Spacer()
        }
        .padding()
        .modifier(TaskCardStyleModifier())
        .onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                task.isCompleted.toggle()
            }
        }
    }
}

// 极其清爽的列表组件
struct GoalDetailTaskList: View {
    var goal: Goal
    
    var body: some View {
        Section(header: Text("执行计划")) {
            ForEach(goal.tasks) { task in
                TaskRowView(task: task)
            }
        }
        .textCase(nil)
    }
}

// 底层物理隔离的安全底部栏
struct GoalDetailBottomBar: View {
    var isDecomposing: Bool
    var onAction: () -> Void
    
    private var buttonColor: Color {
        isDecomposing ? Color.gray : Color.blue
    }
    
    private var buttonText: String {
        isDecomposing ? "AI 正在思考..." : "AI 更新执行计划"
    }
    
    var body: some View {
        Button(action: onAction) {
            HStack {
                if isDecomposing {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 5)
                }
                Text(buttonText)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(buttonColor)
            )
        }
        .disabled(isDecomposing)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .padding(.top, 10)
        .background(.ultraThinMaterial)
    }
}
