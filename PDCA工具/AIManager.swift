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
        
        let requestBody: [String: Any] = ["model": model, "messages": [["role": "user", "content": "hi"]], "max_tokens": 5]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if httpResponse.statusCode == 200 { return true }
        else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "未知错误"
            throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "验证失败(状态码 \(httpResponse.statusCode)): \(errorMsg)"])
        }
    }
    
    func generateMilestones(goalTitle: String, apiKey: String, baseURL: String, model: String) async throws -> [String] {
        let systemPrompt = """
        你是一个顶尖的项目管理专家。用户的总目标是：【\(goalTitle)】。
        请将该目标拆解为 3-4 个逻辑递进的核心执行阶段。
        要求：全程中文，必须只返回一维 JSON 字符串数组，例如：["前期资产准备", "核心内容测试", "商业化放量"]
        """
        return try await fetchAIResponse(systemPrompt: systemPrompt, userMessage: "请输出大阶段拆解。", responseFormat: "json_object", apiKey: apiKey, baseURL: baseURL, model: model)
    }
    
    func generateSubTasks(goalTitle: String, milestoneTitle: String, apiKey: String, baseURL: String, model: String) async throws -> [String] {
        let systemPrompt = """
        你是敏捷执行教练。总目标：【\(goalTitle)】。当前阶段：【\(milestoneTitle)】。
        请为当前阶段生成 3-5 个极其落地的微动作。
        要求：动作明确，必须只返回一维 JSON 字符串数组，例如：["分析3个对标账号", "撰写首条测试文案"]
        """
        return try await fetchAIResponse(systemPrompt: systemPrompt, userMessage: "请输出微动作拆解。", responseFormat: "json_object", apiKey: apiKey, baseURL: baseURL, model: model)
    }
    
    func analyzeTask(goalTitle: String, taskTitle: String, isCompleted: Bool, apiKey: String, baseURL: String, model: String) async throws -> String {
        let statusText = isCompleted ? "已完成" : "遇到卡点"
        let systemPrompt = """
        你是顶级商业顾问。宏观目标：【\(goalTitle)】。当前微动作：【\(taskTitle)】 (\(statusText))。
        请深思熟虑后，提供极简、专业的实操落地指导。绝不要长篇大论。

        【严格输出 JSON 格式】：
        必须返回如下结构的 JSON，不要包含任何 markdown 标记：
        {
          "insights": [
            {
              "title": "核心阻力",
              "icon": "exclamationmark.triangle.fill",
              "content": "用一两句话直击痛点，指出做这件事最大的坑是什么。"
            },
            {
              "title": "最佳实践",
              "icon": "star.fill",
              "content": "给出1个可以直接套用的标准动作或SOP。"
            },
            {
              "title": "立刻行动",
              "icon": "bolt.fill",
              "content": "明确下一步马上能做的一件具体动作。"
            }
          ]
        }
        """
        
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        let messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "请针对【\(taskTitle)】输出专家指导。请严格输出 JSON。"]
        ]
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "response_format": ["type": "json_object"]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        
        let result = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
        let content = result.choices.first?.message.content ?? ""
        
        let marker = String(repeating: "`", count: 3)
        var cleanContent = content.replacingOccurrences(of: "\(marker)json", with: "")
        cleanContent = cleanContent.replacingOccurrences(of: marker, with: "")
        return cleanContent.trimmingCharacters(in: .whitespacesAndNewlines)
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
            let marker = String(repeating: "`", count: 3)
            var cleanContent = content.replacingOccurrences(of: "\(marker)json", with: "")
            cleanContent = cleanContent.replacingOccurrences(of: marker, with: "")
            cleanContent = cleanContent.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let jsonData = cleanContent.data(using: .utf8) {
                if let parsed = try? JSONDecoder().decode([String].self, from: jsonData) { return parsed }
                if let parsedDicts = try? JSONDecoder().decode([[String: String]].self, from: jsonData) {
                    let extracted = parsedDicts.compactMap { $0["task"] ?? $0["title"] ?? $0.values.first }
                    if !extracted.isEmpty { return extracted }
                }
            }
            return ["分析格式异常，请重试"]
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


