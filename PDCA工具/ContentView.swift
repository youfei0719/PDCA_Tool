import SwiftUI
import SwiftData

struct TaskInsightResponse: Codable {
    let insights: [InsightCard]
}

struct InsightCard: Codable, Identifiable {
    var id: String { title }
    let title: String
    let icon: String
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case title, icon, content
    }
}

// MARK: - 1. 根视图 (主列表页)
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.creationDate, order: .reverse) private var goals: [Goal]
    @State private var healthManager = HealthManager.shared
    
    @State private var isShowingAddGoalAlert = false
    @State private var newGoalTitle = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HealthGlassCard(healthManager: healthManager)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                
                Section(header: Text("宏观目标规划")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(nil)
                ) {
                    if goals.isEmpty {
                        ContentUnavailableView {
                            Image(systemName: "target")
                                .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.3))
                        } description: {
                            Text("伟大的计划始于第一个动作。")
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(goals) { goal in
                            NavigationLink(destination: GoalDetailView(goal: goal)) {
                                GoalRow(goal: goal)
                            }
                        }
                        .onDelete(perform: deleteGoals)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Flow PDCA")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: promptAddGoal) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .alert("确立核心目标", isPresented: $isShowingAddGoalAlert) {
                TextField("例如：小红书年度战略", text: $newGoalTitle)
                Button("取消", role: .cancel) { newGoalTitle = "" }
                Button("创建", action: saveNewGoal)
            }
        }
    }
    
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
            newGoalTitle = ""
        }
    }

    private func deleteGoals(offsets: IndexSet) {
        withAnimation { for index in offsets { modelContext.delete(goals[index]) } }
    }
}

// MARK: - 主页组件
struct HealthGlassCard: View {
    var healthManager: HealthManager
    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Label("生理能效状态", systemImage: "bolt.heart.fill")
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
        .background(Color(UIColor.secondarySystemGroupedBackground))
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
    var totalTasks: Int { goal.milestones.reduce(0) { $0 + $1.tasks.count } }
    var completedTasks: Int { goal.milestones.reduce(0) { sum, milestone in sum + milestone.tasks.filter { $0.isCompleted }.count } }
    var isAllCompleted: Bool { totalTasks > 0 && totalTasks == completedTasks }
    var progressText: String {
        if goal.milestones.isEmpty { return "待开启 AI 规划" }
        if totalTasks == 0 { return "已建骨架，待细化" }
        return "完成 \(completedTasks)/\(totalTasks)"
    }
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: isAllCompleted ? "checkmark.circle.fill" : "target")
                .font(.title2)
                .foregroundStyle(isAllCompleted ? Color.green : Color.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text("共 \(goal.milestones.count) 阶段规划 • \(progressText)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 🏆 大标题排版 (已清空所有多余英文)
struct NativeGoalHeader: View {
    @Bindable var goal: Goal
    var completedTasks: Int { goal.milestones.reduce(0) { sum, milestone in sum + milestone.tasks.filter { $0.isCompleted }.count } }
    var totalTasks: Int { goal.milestones.reduce(0) { $0 + $1.tasks.count } }
    var progress: Double { totalTasks == 0 ? 0 : Double(completedTasks) / Double(totalTasks) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("输入宏观大目标...", text: $goal.title, axis: .vertical)
                .font(.system(size: 30, weight: .heavy, design: .default))
                .minimumScaleFactor(0.85)
                .foregroundColor(.primary)
                .lineSpacing(2)
                .padding(.top, 10)
            
            HStack(spacing: 16) {
                Label(goal.creationDate.formatted(date: .numeric, time: .omitted), systemImage: "calendar")
                Label("\(goal.milestones.count) 阶段", systemImage: "flag")
                Label("\(Int(progress * 100))%", systemImage: "chart.bar.fill")
            }
            .font(.caption.weight(.medium))
            .foregroundColor(.secondary)
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
}

// MARK: - 2. 目标详情页
struct GoalDetailView: View {
    @Bindable var goal: Goal
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("aiAPIKey") private var storedAPIKey = ""
    @AppStorage("aiBaseURL") private var storedBaseURL = "https://api.deepseek.com/v1/chat/completions"
    @AppStorage("aiModelName") private var storedModelName = "deepseek-chat"
    
    @State private var isGenerating = false
    @State private var showingAPIKeySheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                NativeGoalHeader(goal: goal)

                LazyVStack(spacing: 12) {
                    HStack {
                        Text("项目执行阶段")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                    
                    if goal.milestones.isEmpty {
                        ContentUnavailableView {
                            Image(systemName: "flag")
                                .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.3))
                        } description: {
                            Text("点击下方由 AI 为您构建阶段蓝图。")
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(goal.milestones.sorted(by: { $0.creationDate < $1.creationDate })) { milestone in
                            NavigationLink(destination: MilestoneDetailView(milestone: milestone, goalTitle: goal.title)) {
                                MilestoneNativeCard(milestone: milestone)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 20)
                        }
                        .onDelete(perform: deleteMilestones)
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isGenerating) // 防误退
        .safeAreaInset(edge: .bottom) {
            Button(action: triggerAIMilestoneGeneration) {
                HStack {
                    if isGenerating { ProgressView().tint(.white).padding(.trailing, 5) }
                    Text(isGenerating ? "AI 正在思考阶段..." : (goal.milestones.isEmpty ? "AI 智能拆解阶段" : "重新规划阶段"))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(isGenerating ? Color.gray : Color.blue))
                .padding(.horizontal, 24).padding(.bottom, 12).padding(.top, 12)
            }
            .disabled(isGenerating)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingAPIKeySheet) { APIKeySettingSheet() }
    }
    
    private func deleteMilestones(offsets: IndexSet) {
        let sorted = goal.milestones.sorted(by: { $0.creationDate < $1.creationDate })
        withAnimation { for index in offsets { modelContext.delete(sorted[index]) } }
    }
    
    private func triggerAIMilestoneGeneration() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        guard !storedAPIKey.trimmingCharacters(in: .whitespaces).isEmpty else { showingAPIKeySheet = true; return }
        isGenerating = true
        Task {
            do {
                let phaseTitles = try await AIManager.shared.generateMilestones(goalTitle: goal.title, apiKey: storedAPIKey, baseURL: storedBaseURL, model: storedModelName)
                await MainActor.run {
                    withAnimation(.spring()) {
                        for m in goal.milestones { modelContext.delete(m) }
                        goal.milestones.removeAll()
                        for title in phaseTitles {
                            let newMilestone = Milestone(title: title)
                            newMilestone.goal = goal
                            modelContext.insert(newMilestone)
                        }
                        isGenerating = false
                    }
                }
            } catch { await MainActor.run { isGenerating = false } }
        }
    }
}

// 阶段卡片
struct MilestoneNativeCard: View {
    @Bindable var milestone: Milestone
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(milestone.title)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundColor(milestone.progress == 1.0 ? .secondary : .primary)
                    .lineLimit(2)
                Spacer()
                Text("\(Int(milestone.progress * 100))%")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundColor(milestone.progress == 1.0 ? .green : .accentColor)
            }
            
            HStack {
                Text("包含 \(milestone.tasks.count) 个微动作")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                ProgressView(value: milestone.progress)
                    .progressViewStyle(.linear)
                    .tint(milestone.progress == 1.0 ? .green : .accentColor)
                    .frame(width: 60)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - 3. 阶段详情页 (大标题完全清空冗余元素)
struct MilestoneDetailView: View {
    @Bindable var milestone: Milestone
    let goalTitle: String
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("aiAPIKey") private var storedAPIKey = ""
    @AppStorage("aiBaseURL") private var storedBaseURL = "https://api.deepseek.com/v1/chat/completions"
    @AppStorage("aiModelName") private var storedModelName = "deepseek-chat"
    
    @State private var isGenerating = false
    @State private var showingAPIKeySheet = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("输入阶段核心目标...", text: $milestone.title, axis: .vertical)
                        .font(.system(size: 30, weight: .heavy, design: .default))
                        .minimumScaleFactor(0.85) // 防断行
                        .foregroundColor(.primary)
                        .padding(.top, 24) // 加大顶部边距，避开返回键
                }
            }
            .listRowBackground(Color.clear) // 彻底隐藏默认白底框
            .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 20, trailing: 0))
            .listRowSeparator(.hidden)

            Section(header: Text("执行清单").font(.subheadline.bold()).textCase(nil)) {
                if milestone.tasks.isEmpty {
                    ContentUnavailableView {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.3))
                    } description: {
                        Text("点击下方由 AI 拆解具体执行动作。")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(milestone.tasks.sorted(by: { $0.creationDate < $1.creationDate })) { task in
                        TaskRowWrapper(task: task, goalTitle: goalTitle)
                    }
                    .onDelete(perform: deleteTasks)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isGenerating) // 防误退
        .safeAreaInset(edge: .bottom) {
            Button(action: triggerAITaskGeneration) {
                HStack {
                    if isGenerating { ProgressView().tint(.white).padding(.trailing, 5) }
                    Text(isGenerating ? "AI 正在拆解动作..." : "AI 细化执行清单")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(isGenerating ? Color.gray : Color.indigo))
                .padding(.horizontal, 24).padding(.bottom, 12).padding(.top, 12)
            }
            .disabled(isGenerating)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingAPIKeySheet) { APIKeySettingSheet() }
    }
    
    private func deleteTasks(offsets: IndexSet) {
        let sorted = milestone.tasks.sorted(by: { $0.creationDate < $1.creationDate })
        withAnimation { for index in offsets { modelContext.delete(sorted[index]) } }
    }
    
    private func triggerAITaskGeneration() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        guard !storedAPIKey.trimmingCharacters(in: .whitespaces).isEmpty else { showingAPIKeySheet = true; return }
        isGenerating = true
        Task {
            do {
                let taskTitles = try await AIManager.shared.generateSubTasks(goalTitle: goalTitle, milestoneTitle: milestone.title, apiKey: storedAPIKey, baseURL: storedBaseURL, model: storedModelName)
                await MainActor.run {
                    withAnimation(.spring()) {
                        let tasksToDelete = milestone.tasks.filter { !$0.isCompleted }
                        for t in tasksToDelete { modelContext.delete(t) }
                        milestone.tasks.removeAll { !$0.isCompleted }
                        for title in taskTitles {
                            let newTask = PDCATask(title: title)
                            newTask.milestone = milestone
                            modelContext.insert(newTask)
                        }
                        isGenerating = false
                    }
                }
            } catch { await MainActor.run { isGenerating = false } }
        }
    }
}

// 任务行
struct TaskRowWrapper: View {
    @Bindable var task: PDCATask
    let goalTitle: String
    @State private var showingDetailSheet = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : Color(UIColor.tertiaryLabel))
                .font(.title2)
                .scaleEffect(task.isCompleted ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: task.isCompleted)
                .padding(.top, 2)
                .contentShape(Rectangle())
                .onTapGesture {
                    let generator = UIImpactFeedbackGenerator(style: task.isCompleted ? .light : .rigid)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        task.isCompleted.toggle()
                    }
                }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(task.isCompleted ? .regular : .medium)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                
                if task.aiInsight != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("点击查看 AI 指南")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(task.isCompleted ? .secondary : .indigo)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { showingDetailSheet = true }
        .sheet(isPresented: $showingDetailSheet) {
            TaskDetailSheet(task: task, goalTitle: goalTitle)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - 🌟 动作详情抽屉 (防弹 JSON 提取 + 严格阻断下滑关闭)
struct TaskDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: PDCATask
    let goalTitle: String
    
    @AppStorage("aiAPIKey") private var storedAPIKey = ""
    @AppStorage("aiBaseURL") private var storedBaseURL = "https://api.deepseek.com/v1/chat/completions"
    @AppStorage("aiModelName") private var storedModelName = "deepseek-chat"
    
    @State private var isAnalyzing = false
    @State private var showingAPIKeySheet = false
    
    // 防弹级 JSON 解析器
    private func parseInsights(from string: String) -> [InsightCard] {
        guard let firstBrace = string.firstIndex(of: "{"),
              let lastBrace = string.lastIndex(of: "}") else { return [] }
        
        let jsonString = String(string[firstBrace...lastBrace])
        guard let data = jsonString.data(using: .utf8) else { return [] }
        
        do {
            if let response = try? JSONDecoder().decode(TaskInsightResponse.self, from: data) {
                return response.insights
            }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let insightsArray = json["insights"] as? [[String: Any]] {
                return insightsArray.compactMap { dict in
                    let title = dict["title"] as? String ?? "指南"
                    let icon = dict["icon"] as? String ?? "sparkles"
                    let content = dict["content"] as? String ?? ""
                    if content.isEmpty { return nil }
                    return InsightCard(title: title, icon: icon, content: content)
                }
            }
        } catch {
            print("JSON 解析保护拦截：\(error)")
        }
        return []
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        TextField("输入执行动作...", text: $task.title, axis: .vertical)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.top, 32)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            if isAnalyzing {
                                HStack {
                                    ProgressView().padding(.trailing, 8)
                                    Text("专家大脑正在深度提炼...").font(.subheadline).foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                                
                            } else if let insightString = task.aiInsight, !insightString.isEmpty {
                                
                                let cards = parseInsights(from: insightString)
                                
                                if !cards.isEmpty {
                                    VStack(spacing: 16) {
                                        ForEach(cards) { card in
                                            InsightAppleCard(card: card)
                                        }
                                    }
                                } else {
                                    // 拦截所有乱码，保护 UI
                                    VStack(spacing: 12) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 40)).foregroundColor(.orange.opacity(0.8))
                                        Text("排版构建出现偏差")
                                            .font(.headline).foregroundColor(.primary)
                                        Text("系统已自动拦截乱码，请点击下方按钮重新生成卡片。")
                                            .font(.subheadline).foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 20)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                }
                                
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "square.grid.2x2")
                                        .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.3))
                                    Text("让 AI 为您生成极简的行动卡片。")
                                        .font(.subheadline).foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Button(action: { triggerAIAnalysis() }) {
                            HStack {
                                Image(systemName: task.aiInsight == nil ? "wand.and.stars" : "arrow.triangle.2.circlepath")
                                Text(task.aiInsight == nil ? "获取行动卡片" : "重新提炼卡片")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                            }
                            .foregroundColor(isAnalyzing ? .gray : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(isAnalyzing ? Color(UIColor.systemGray4) : Color.indigo))
                        }
                        .disabled(isAnalyzing) // 🌟 生成中禁用按钮
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("动作详情")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isAnalyzing) // 🌟 锁定：防向下滑动关闭
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.bold)
                        .disabled(isAnalyzing) // 🌟 锁定：完成按钮变灰
                }
            }
        }
        .sheet(isPresented: $showingAPIKeySheet) { APIKeySettingSheet() }
    }
    
    private func triggerAIAnalysis() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        guard !storedAPIKey.trimmingCharacters(in: .whitespaces).isEmpty else { showingAPIKeySheet = true; return }
        
        isAnalyzing = true
        Task {
            do {
                let result = try await AIManager.shared.analyzeTask(goalTitle: goalTitle, taskTitle: task.title, isCompleted: task.isCompleted, apiKey: storedAPIKey, baseURL: storedBaseURL, model: storedModelName)
                await MainActor.run { self.task.aiInsight = result; self.isAnalyzing = false }
            } catch {
                await MainActor.run {
                    if self.task.aiInsight == nil {
                        self.task.aiInsight = "分析失败：\(error.localizedDescription)"
                    }
                    self.isAnalyzing = false
                }
            }
        }
    }
}

// Apple Health 风格卡片
struct InsightAppleCard: View {
    let card: InsightCard
    
    var iconTint: Color {
        if card.title.contains("阻力") || card.title.contains("坑") { return .orange }
        if card.title.contains("行动") || card.title.contains("立刻") { return .blue }
        return .indigo
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconTint.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: card.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconTint)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(card.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(card.content)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
    }
}

// MARK: - 5. API 配置页
enum AIProvider: String, CaseIterable, Identifiable {
    case deepseek = "DeepSeek (深度求索)"
    case kimi = "Kimi (月之暗面)"
    case qwen = "通义千问 (阿里)"
    case zhipu = "智谱 GLM"
    case openai = "OpenAI"
    case custom = "自定义其他模型"
    var id: String { self.rawValue }
    var defaultURL: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com/v1/chat/completions"
        case .kimi: return "https://api.moonshot.cn/v1/chat/completions"
        case .qwen: return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        case .zhipu: return "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .custom: return ""
        }
    }
    var defaultModel: String {
        switch self {
        case .deepseek: return "deepseek-chat"
        case .kimi: return "moonshot-v1-8k"
        case .qwen: return "qwen-plus"
        case .zhipu: return "glm-4"
        case .openai: return "gpt-4o-mini"
        case .custom: return ""
        }
    }
}

struct APIKeySettingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aiAPIKey") private var storedAPIKey = ""
    @AppStorage("aiBaseURL") private var storedBaseURL = "https://api.deepseek.com/v1/chat/completions"
    @AppStorage("aiModelName") private var storedModelName = "deepseek-chat"
    @State private var selectedProvider: AIProvider = .deepseek
    @State private var tempKey = ""
    @State private var tempURL = ""
    @State private var tempModel = ""
    @State private var isVerifying = false
    @State private var verifyStatusMessage = ""
    @State private var isVerifiedSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("选择大模型服务商")) {
                    Picker("服务商", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .onChange(of: selectedProvider) {
                        if selectedProvider != .custom {
                            tempURL = selectedProvider.defaultURL
                            tempModel = selectedProvider.defaultModel
                            resetVerification()
                        }
                    }
                }
                Section(header: Text("接口配置")) {
                    TextField("Base URL", text: $tempURL).textInputAutocapitalization(.never)
                    TextField("Model Name", text: $tempModel).textInputAutocapitalization(.never)
                    SecureField("API Key", text: $tempKey)
                }
                Section {
                    Button(action: testConnection) {
                        HStack {
                            Spacer()
                            Text(isVerifying ? "测试中..." : "测试连接").fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .disabled(isVerifying || tempKey.isEmpty)
                    if !verifyStatusMessage.isEmpty {
                        Text(verifyStatusMessage)
                            .font(.footnote)
                            .foregroundColor(isVerifiedSuccess ? .green : .red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                Section {
                    Button("保存并启用") {
                        storedAPIKey = tempKey.trimmingCharacters(in: .whitespaces)
                        storedBaseURL = tempURL.trimmingCharacters(in: .whitespaces)
                        storedModelName = tempModel.trimmingCharacters(in: .whitespaces)
                        dismiss()
                    }
                    .disabled(!isVerifiedSuccess)
                }
            }
            .navigationTitle("AI 网络设置")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isVerifying)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }.disabled(isVerifying)
                }
            }
            .onAppear {
                tempKey = storedAPIKey; tempURL = storedBaseURL; tempModel = storedModelName
                selectedProvider = AIProvider.allCases.first(where: { $0.defaultURL == tempURL && $0.defaultModel == tempModel }) ?? .custom
            }
            .onChange(of: tempKey) { resetVerification() }
            .onChange(of: tempURL) { checkIfCustom(); resetVerification() }
            .onChange(of: tempModel) { checkIfCustom(); resetVerification() }
        }
    }
    
    private func checkIfCustom() {
        if selectedProvider != .custom && (tempURL != selectedProvider.defaultURL || tempModel != selectedProvider.defaultModel) {
            selectedProvider = .custom
        }
    }
    private func resetVerification() { isVerifiedSuccess = false; verifyStatusMessage = "" }
    
    private func testConnection() {
        isVerifying = true
        verifyStatusMessage = ""
        Task {
            do {
                let success = try await AIManager.shared.verifyConfiguration(apiKey: tempKey, baseURL: tempURL, model: tempModel)
                await MainActor.run { isVerifying = false; isVerifiedSuccess = success; verifyStatusMessage = success ? "✅ 连接成功！" : "❌ 验证失败" }
            } catch {
                await MainActor.run { isVerifying = false; isVerifiedSuccess = false; verifyStatusMessage = "❌ 验证失败：\(error.localizedDescription)" }
            }
        }
    }
}
