import Foundation

class AIManager {
    static let shared = AIManager()
    private init() {}
    
    func verifyConfiguration(apiKey: String, baseURL: String, model: String) async throws -> Bool {
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "hi"]],
            "max_tokens": 5
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if httpResponse.statusCode == 200 { return true }
        else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "未知错误"
            throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "验证失败(状态码 \(httpResponse.statusCode)): \(errorMsg)"])
        }
    }
    
    func decomposeGoal(title: String, apiKey: String, baseURL: String, model: String) async throws -> [String] {
        let systemPrompt = "你是一个精通PDCA工作法的效率专家。请将用户的目标拆解为3-5个具体的、可执行的原子任务。请只返回JSON数组格式，例如：[\"任务1\", \"任务2\"]，不要有任何其他解释。"
        return try await fetchAIResponse(systemPrompt: systemPrompt, userMessage: "目标：\(title)", responseFormat: "json_object", apiKey: apiKey, baseURL: baseURL, model: model)
    }
    
    // 🌟 深度重构：加入大目标上下文，彻底解决“为什么不用网页版AI”的问题
    func analyzeTask(goalTitle: String, taskTitle: String, isCompleted: Bool, apiKey: String, baseURL: String, model: String) async throws -> String {
        let statusText = isCompleted ? "已完成复盘" : "执行遇到卡点"
        
        let systemPrompt = """
        你是一个顶级的敏捷项目管理专家。
        用户的宏观项目目标是：【\(goalTitle)】。
        当前正在执行的子任务是：【\(taskTitle)】，状态为：\(statusText)。
        
        请结合宏观目标，针对这个具体的子任务给出破局洞察。
        严格使用以下 Markdown 格式输出（不要用 ###，直接用 ** 加粗）：
        
        **🔍 核心阻力剖析**
        (分析该任务在整个项目中最容易踩坑的地方，1-2句话)
        
        **💡 破局策略**
        (给出 2 条极其具体的操作建议)
        
        **🎯 5分钟下一步动作**
        (列出 1-2 个可以立刻动手执行的原子动作)
        """
        
        let responseArray = try await fetchAIResponse(systemPrompt: systemPrompt, userMessage: "请输出针对【\(taskTitle)】的洞察。", responseFormat: "text", apiKey: apiKey, baseURL: baseURL, model: model)
        return responseArray.first ?? "抱歉，分析数据时出现了一点小偏差。"
    }
    
    private func fetchAIResponse(systemPrompt: String, userMessage: String, responseFormat: String, apiKey: String, baseURL: String, model: String) async throws -> [String] {
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        let messages = [["role": "system", "content": systemPrompt], ["role": "user", "content": userMessage]]
        let requestBody: [String: Any] = ["model": model, "messages": messages, "response_format": ["type": responseFormat == "json_object" ? "json_object" : "text"]]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        
        let result = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
        let content = result.choices.first?.message.content ?? ""
        
        if responseFormat == "json_object" {
            let backticks = String(repeating: "`", count: 3)
            let cleanContent = content.replacingOccurrences(of: backticks + "json", with: "").replacingOccurrences(of: backticks, with: "")
            if let jsonData = cleanContent.data(using: .utf8), let tasks = try? JSONDecoder().decode([String].self, from: jsonData) { return tasks }
            return [content]
        } else {
            return [content]
        }
    }
}

struct DeepSeekResponse: Codable {
    let choices: [Choice]
    struct Choice: Codable { let message: Message }
    struct Message: Codable { let content: String }
}
