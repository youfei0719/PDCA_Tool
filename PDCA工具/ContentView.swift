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

// MARK: - 主页组件
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
    
    @AppStorage("aiAPIKey") private var storedAPIKey = ""
    @AppStorage("aiBaseURL") private var storedBaseURL = "https://api.deepseek.com/v1/chat/completions"
    @AppStorage("aiModelName") private var storedModelName = "deepseek-chat"
    
    @State private var isDecomposing = false
    @State private var showingAIOptions = false
    @State private var showingAPIKeySheet = false
    
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
        .sheet(isPresented: $showingAPIKeySheet) {
            APIKeySettingSheet()
                .interactiveDismissDisabled(true)
        }
    }
    
    private func handleAIButtonClick() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        guard !storedAPIKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            showingAPIKeySheet = true
            return
        }
        
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
                let taskTitles = try await AIManager.shared.decomposeGoal(
                    title: goal.title,
                    apiKey: storedAPIKey,
                    baseURL: storedBaseURL,
                    model: storedModelName
                )
                
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

struct TaskRowView: View {
    @Bindable var task: PDCATask
    
    @AppStorage("aiAPIKey") private var storedAPIKey = ""
    @AppStorage("aiBaseURL") private var storedBaseURL = "https://api.deepseek.com/v1/chat/completions"
    @AppStorage("aiModelName") private var storedModelName = "deepseek-chat"
    
    @State private var isAnalyzing = false
    @State private var showingAnalysisSheet = false
    @State private var showingAPIKeySheet = false
    
    private var iconName: String { task.isCompleted ? "checkmark.circle.fill" : "circle" }
    private var iconColor: Color { task.isCompleted ? .green : .blue }
    private var titleColor: Color { task.isCompleted ? .secondary : .primary }
    
    // 逻辑：如果已经存有洞察数据，则直接打开；否则说明还没生成过
    private var subtitleText: String {
        if isAnalyzing { return "AI 正在思考破局方案..." }
        if task.aiInsight != nil { return "左滑删除 • 右滑查看已存 AI 洞察" }
        return "左滑删除 • 右滑获取 AI 破局方案"
    }
    
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
                
                Text(subtitleText)
                    .font(.system(size: 10))
                    .foregroundColor(task.aiInsight != nil ? .indigo : Color(UIColor.tertiaryLabel))
            }
            Spacer()
            
            if isAnalyzing { ProgressView().controlSize(.mini) }
        }
        .padding()
        .modifier(TaskCardStyleModifier())
        .onTapGesture {
            guard !isAnalyzing else { return }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                task.isCompleted.toggle()
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                triggerAIAnalysis(forceRegenerate: false)
            } label: {
                Label("AI 洞察", systemImage: "sparkles")
            }
            .tint(.indigo)
        }
        .sheet(isPresented: $showingAnalysisSheet) {
            // 传入闭包以支持在卡片内点击“重新生成”
            AIInsightSheet(taskTitle: task.title, markdownText: task.aiInsight ?? "加载中...", onRegenerate: {
                triggerAIAnalysis(forceRegenerate: true)
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            APIKeySettingSheet()
        }
    }
    
    // 🌟 核心控制逻辑：带有缓存机制的 AI 触发器
    private func triggerAIAnalysis(forceRegenerate: Bool) {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        guard !storedAPIKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            showingAPIKeySheet = true
            return
        }
        
        // 如果不是强制刷新，且本地已有记录，直接秒开展示
        if !forceRegenerate, let existing = task.aiInsight, !existing.isEmpty {
            showingAnalysisSheet = true
            return
        }
        
        isAnalyzing = true
        
        Task {
            do {
                let goalTitle = task.goal?.title ?? "未知项目"
                let result = try await AIManager.shared.analyzeTask(
                    goalTitle: goalTitle,
                    taskTitle: task.title,
                    isCompleted: task.isCompleted,
                    apiKey: storedAPIKey,
                    baseURL: storedBaseURL,
                    model: storedModelName
                )
                
                await MainActor.run {
                    self.task.aiInsight = result // 🔥 永久保存进数据库
                    self.isAnalyzing = false
                    self.showingAnalysisSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isAnalyzing = false
                    self.task.aiInsight = "抱歉，网络请求失败。请检查配置或重试。\n\n错误信息：\(error.localizedDescription)"
                    self.showingAnalysisSheet = true
                }
            }
        }
    }
}

// 🌟 全新设计：符合 HIG 规范的高级半屏卡片
struct AIInsightSheet: View {
    @Environment(\.dismiss) private var dismiss
    let taskTitle: String
    let markdownText: String
    var onRegenerate: () -> Void // 重新生成回调
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("当前聚焦任务")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Text(taskTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // 完美适配的 Markdown 文本解析
                    if let attrStr = try? AttributedString(markdown: markdownText, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                        Text(attrStr)
                            .font(.system(.body, design: .rounded))
                            .lineSpacing(6)
                            .padding(.top, 5)
                    } else {
                        Text(markdownText)
                            .font(.system(.body, design: .rounded))
                            .lineSpacing(6)
                            .padding(.top, 5)
                    }
                    
                    Spacer(minLength: 40)
                    
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        dismiss()
                        // 给关闭动画留出时间，再触发重新请求
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onRegenerate()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("重新生成洞察")
                        }
                        .fontWeight(.bold)
                        .foregroundColor(.indigo)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo.opacity(0.1))
                        .cornerRadius(15)
                    }
                }
                .padding(24)
            }
            .navigationTitle("AI 破局洞察")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // 🌟 修复 UI 问题：使用标准的系统级完成按钮
                    Button("关闭") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

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

struct GoalDetailBottomBar: View {
    var isDecomposing: Bool
    var onAction: () -> Void
    
    var body: some View {
        Button(action: onAction) {
            HStack {
                if isDecomposing { ProgressView().tint(.white).padding(.trailing, 5) }
                Text(isDecomposing ? "AI 正在思考..." : "AI 更新执行计划").fontWeight(.bold)
            }
            .foregroundColor(.white).frame(maxWidth: .infinity).padding()
            .background(RoundedRectangle(cornerRadius: 15).fill(isDecomposing ? Color.gray : Color.blue))
        }
        .disabled(isDecomposing).padding(.horizontal, 20).padding(.bottom, 10).padding(.top, 10)
        .background(.ultraThinMaterial)
    }
}

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
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .onChange(of: selectedProvider) {
                        if selectedProvider != .custom {
                            tempURL = selectedProvider.defaultURL
                            tempModel = selectedProvider.defaultModel
                            resetVerification()
                        }
                    }
                }
                
                Section(header: Text("接口配置"), footer: Text("选择对应服务商后，系统会自动填写接口地址和模型名称。您也可以手动修改它们。")) {
                    VStack(alignment: .leading) {
                        Text("Base URL (接口地址)").font(.caption).foregroundColor(.secondary)
                        TextField("例如：https://api.deepseek.com/...", text: $tempURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Model Name (模型名称)").font(.caption).foregroundColor(.secondary)
                        TextField("例如：deepseek-chat", text: $tempModel)
                            .textInputAutocapitalization(.never)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("API Key (密钥)").font(.caption).foregroundColor(.secondary)
                        SecureField("sk-xxxxxxxxxxxxxxxxxxxx", text: $tempKey)
                    }
                }
                
                Section {
                    Button(action: testConnection) {
                        HStack {
                            Spacer()
                            if isVerifying {
                                ProgressView().padding(.trailing, 5)
                                Text("正在连接测试...").foregroundColor(.secondary)
                            } else {
                                Text("测试连接").fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isVerifying || tempKey.isEmpty || tempURL.isEmpty || tempModel.isEmpty)
                    
                    if !verifyStatusMessage.isEmpty {
                        Text(verifyStatusMessage)
                            .font(.footnote)
                            .foregroundColor(isVerifiedSuccess ? .green : .red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                Section(footer: Text("必须通过【测试连接】验证可用后，方可保存配置。密钥仅保存在本地设备。")) {
                    Button("保存并启用") {
                        storedAPIKey = tempKey.trimmingCharacters(in: .whitespaces)
                        storedBaseURL = tempURL.trimmingCharacters(in: .whitespaces)
                        storedModelName = tempModel.trimmingCharacters(in: .whitespaces)
                        dismiss()
                    }
                    .disabled(!isVerifiedSuccess)
                    .foregroundColor(isVerifiedSuccess ? .blue : .gray)
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
                tempKey = storedAPIKey
                tempURL = storedBaseURL
                tempModel = storedModelName
                
                if let match = AIProvider.allCases.first(where: { $0.defaultURL == tempURL && $0.defaultModel == tempModel }) {
                    selectedProvider = match
                } else {
                    selectedProvider = .custom
                }
            }
            .onChange(of: tempKey) { resetVerification() }
            .onChange(of: tempURL) {
                checkIfCustom()
                resetVerification()
            }
            .onChange(of: tempModel) {
                checkIfCustom()
                resetVerification()
            }
        }
    }
    
    private func checkIfCustom() {
        if selectedProvider != .custom {
            if tempURL != selectedProvider.defaultURL || tempModel != selectedProvider.defaultModel {
                selectedProvider = .custom
            }
        }
    }
    
    private func resetVerification() {
        isVerifiedSuccess = false
        verifyStatusMessage = ""
    }
    
    private func testConnection() {
        isVerifying = true
        verifyStatusMessage = ""
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        Task {
            do {
                let success = try await AIManager.shared.verifyConfiguration(
                    apiKey: tempKey.trimmingCharacters(in: .whitespaces),
                    baseURL: tempURL.trimmingCharacters(in: .whitespaces),
                    model: tempModel.trimmingCharacters(in: .whitespaces)
                )
                
                await MainActor.run {
                    isVerifying = false
                    isVerifiedSuccess = success
                    verifyStatusMessage = success ? "✅ 连接成功！模型响应正常。" : "❌ 验证失败，请检查参数。"
                    if success {
                        let successGenerator = UINotificationFeedbackGenerator()
                        successGenerator.notificationOccurred(.success)
                    }
                }
            } catch {
                await MainActor.run {
                    isVerifying = false
                    isVerifiedSuccess = false
                    verifyStatusMessage = "❌ \(error.localizedDescription)"
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                }
            }
        }
    }
}
