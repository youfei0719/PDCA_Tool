import SwiftUI
import SwiftData

// MARK: - 1. 根视图 (显示大目标)
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
                            Image(systemName: "flag")
                                .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.3))
                        } description: {
                            Text("伟大的计划始于第一个微动作。")
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
            .listStyle(.insetGrouped) // 回归 Apple 最原生的分组列表样式
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

// MARK: - 主页生理状态组件
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

// MARK: - 主页列表 Row
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

// MARK: - 2. 目标详情页 (大阶段视图)
struct GoalDetailView: View {
    @Bindable var goal: Goal
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("aiAPIKey") private var storedAPIKey = ""
    @AppStorage("aiBaseURL") private var storedBaseURL = "https://api.deepseek.com/v1/chat/completions"
    @AppStorage("aiModelName") private var storedModelName = "deepseek-chat"
    
    @State private var isGenerating = false
    @State private var showingAPIKeySheet = false
    
    var body: some View {
        List {
            // 极致纯净的原生大标题
            Section {
                TextField("输入宏观大目标...", text: $goal.title, axis: .vertical)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(4)
                    .padding(.vertical, 8)
            }
            
            Section(header: Text("项目阶段规划").font(.subheadline.bold()).textCase(nil)) {
                if goal.milestones.isEmpty {
                    ContentUnavailableView {
                        Image(systemName: "flag")
                            .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.3))
                    } description: {
                        Text("点击下方由 AI 为您构建阶段蓝图。")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(goal.milestones.sorted(by: { $0.creationDate < $1.creationDate })) { milestone in
                        NavigationLink(destination: MilestoneDetailView(milestone: milestone, goalTitle: goal.title)) {
                            MilestoneCleanCard(milestone: milestone)
                        }
                    }
                    .onDelete(perform: deleteMilestones)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("项目总览")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button(action: triggerAIMilestoneGeneration) {
                HStack {
                    if isGenerating { ProgressView().tint(.white).padding(.trailing, 5) }
                    Text(isGenerating ? "AI 正在思考蓝图..." : (goal.milestones.isEmpty ? "AI 智能拆解阶段" : "重新规划阶段"))
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

// 极致干净的阶段行
struct MilestoneCleanCard: View {
    @Bindable var milestone: Milestone
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(milestone.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(milestone.progress == 1.0 ? .secondary : .primary)
                    .lineLimit(2)
                Spacer()
                Text("\(Int(milestone.progress * 100))%")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(milestone.progress == 1.0 ? .green : .blue)
            }
            
            HStack {
                Text("包含 \(milestone.tasks.count) 个微动作")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                ProgressView(value: milestone.progress)
                    .progressViewStyle(.linear)
                    .tint(milestone.progress == 1.0 ? .green : .blue)
                    .frame(width: 60)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 🏆 阶段详情页 (原生 List + 纯净列表)
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
                TextField("输入当前阶段核心...", text: $milestone.title, axis: .vertical)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .padding(.vertical, 8)
            }

            Section(header: Text("待执行清单").font(.subheadline.bold()).textCase(nil)) {
                if milestone.tasks.isEmpty {
                    ContentUnavailableView {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.3))
                    } description: {
                        Text("点击下方由 AI 为您拆解可执行动作。")
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
        .navigationTitle("阶段蓝图")
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - ✨ 终极爽感微动作：果冻弹簧完成动画 + 无删除线排版
struct TaskRowWrapper: View {
    @Bindable var task: PDCATask
    let goalTitle: String
    @State private var showingDetailSheet = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            
            // 【爽感来源】：精准的 Haptic 震动 + 瞬间的弹簧缩放动画
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : Color(UIColor.tertiaryLabel))
                .font(.title2)
                .scaleEffect(task.isCompleted ? 1.1 : 1.0) // 选中时微放大
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: task.isCompleted)
                .padding(.top, 2)
                .contentShape(Rectangle())
                .onTapGesture {
                    // 完成任务给予极强烈的成功震动反馈
                    let generator = UIImpactFeedbackGenerator(style: task.isCompleted ? .light : .rigid)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        task.isCompleted.toggle()
                    }
                }
            
            VStack(alignment: .leading, spacing: 6) {
                // 【视觉降噪】：绝对不用删除线，完成的任务平滑变灰，未完成的保持对比度
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

// MARK: - 智能解析引擎 (用于剥离 Markdown 构建 Health 风格卡片)
struct ParsedSection: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let icon: String
}

func parseInsight(markdown: String) -> [ParsedSection] {
    var sections: [ParsedSection] = []
    let parts = markdown.components(separatedBy: "**")
    var i = 1
    
    let iconMap: [String: String] = [
        "核心阻力剖析": "magnifyingglass",
        "官方最佳实践": "list.bullet.clipboard",
        "5分钟立刻行动": "bolt.fill",
        "阻力剖析": "magnifyingglass",
        "SOP 操作指南": "list.bullet.clipboard",
        "立刻行动": "bolt.fill"
    ]
    
    while i < parts.count {
        let titlePart = parts[i].trimmingCharacters(in: .whitespacesAndNewlines)
        if !titlePart.isEmpty {
            var contentPart = ""
            if i + 1 < parts.count { contentPart = parts[i+1].trimmingCharacters(in: .whitespacesAndNewlines) }
            
            // 清理多余图标
            let cleanTitle = titlePart.replacingOccurrences(of: "💡 ", with: "").replacingOccurrences(of: "🎯 ", with: "").replacingOccurrences(of: "🔍 ", with: "")
            
            // 匹配图标，如果没有精确匹配，则使用默认的
            let matchedIcon = iconMap.first(where: { cleanTitle.contains($0.key) })?.value ?? "lightbulb"
            
            sections.append(ParsedSection(title: cleanTitle, content: contentPart, icon: matchedIcon))
            i += 2
        } else {
            i += 1
        }
    }
    let valid = sections.filter { !$0.title.isEmpty && !$0.content.isEmpty }
    return valid.isEmpty ? [ParsedSection(title: "专家指南", content: markdown, icon: "lightbulb")] : valid
}

// MARK: - 🌟 方案 A：Apple Health 风格的“数据堆叠卡片” (彻底消除长文恐惧)
struct HealthStyleInsightCard: View {
    let section: ParsedSection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(section.title.isEmpty ? "执行要点" : section.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            Text(LocalizedStringKey(section.content))
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true) // 保证文本不被截断
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 核心：使用标准的 Apple 二级卡片背景
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // 动态根据内容分配极其克制的辅助色
    private var iconColor: Color {
        if section.title.contains("阻力") { return .orange }
        if section.title.contains("行动") || section.title.contains("步骤") { return .blue }
        return .indigo
    }
}

// MARK: - 4. 任务详情抽屉 (解决网络请求重叠 Bug)
struct TaskDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: PDCATask
    let goalTitle: String
    
    @AppStorage("aiAPIKey") private var storedAPIKey = ""
    @AppStorage("aiBaseURL") private var storedBaseURL = "https://api.deepseek.com/v1/chat/completions"
    @AppStorage("aiModelName") private var storedModelName = "deepseek-chat"
    
    @State private var isAnalyzing = false
    @State private var showingAPIKeySheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 使用原生群组背景，突出上面的卡片
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // 彻底静默的标题编辑
                        TextField("输入执行动作...", text: $task.title, axis: .vertical)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 24)
                            .padding(.top, 32)
                        
                        // 优雅的 Health 风格卡片渲染区
                        VStack(alignment: .leading, spacing: 16) {
                            if isAnalyzing {
                                HStack {
                                    ProgressView().padding(.trailing, 8)
                                    Text("正在为您提炼结构化方案...").font(.subheadline).foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                            } else if let insight = task.aiInsight, !insight.isEmpty {
                                
                                // 🌟 核心：将枯燥的长文切割成原生、清爽的卡片块
                                let parsedSections = parseInsight(markdown: insight)
                                ForEach(parsedSections) { section in
                                    HealthStyleInsightCard(section: section)
                                }
                                
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "square.text.square")
                                        .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.3))
                                    Text("没有头绪？让 AI 为您提炼\n极简的实操落地指南。")
                                        .font(.subheadline).foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(6)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // 【网络修复】：按钮仅作为主动触发器，绝不自动触发 TLS 报错
                        Button(action: { triggerAIAnalysis() }) {
                            HStack {
                                Image(systemName: task.aiInsight == nil ? "wand.and.stars" : "arrow.triangle.2.circlepath")
                                Text(task.aiInsight == nil ? "获取专家指导" : "重新生成指导")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                            }
                            .foregroundColor(isAnalyzing ? .gray : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            // 按钮样式原生化
                            .background(RoundedRectangle(cornerRadius: 16).fill(isAnalyzing ? Color(UIColor.systemGray4) : Color.indigo))
                        }
                        .disabled(isAnalyzing)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("动作详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.fontWeight(.bold)
                }
            }
        }
        .sheet(isPresented: $showingAPIKeySheet) { APIKeySettingSheet() }
    }
    
    // 这个函数现在只有在用户手动点击按钮时才会被调用
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
                    // 即使失败，也会保留之前的旧数据（如果存在），不再用报错信息覆盖掉好不容易生成的文本
                    if self.task.aiInsight == nil {
                        self.task.aiInsight = "分析失败：\(error.localizedDescription)"
                    }
                    self.isAnalyzing = false
                }
            }
        }
    }
}

// MARK: - 5. API 配置页 (保持不变)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
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
                await MainActor.run { isVerifying = false; isVerifiedSuccess = false; verifyStatusMessage = "❌ \(error.localizedDescription)" }
            }
        }
    }
}
