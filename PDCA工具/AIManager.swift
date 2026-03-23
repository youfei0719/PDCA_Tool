import Foundation

enum AIError: Error {
    case invalidURL
    case networkError
    case decodingError
}

struct AIService {
    static let shared = AIService()
    
    // 这里使用了你之前提供的 DeepSeek Key
    private let apiKey = "sk-e541860b53e2430893a5804ccfa11807"
    private let endpoint = "https://api.deepseek.com/v1/chat/completions"
    
    /// 调用 AI 将目标拆解为任务列表
    func decomposeGoal(title: String) async throws -> [String] {
        guard let url = URL(string: endpoint) else { throw AIError.invalidURL }
        
        let prompt = """
        你是一个精通 PDCA 逻辑的个人成长助手。
        用户现在的目标是：'\(title)'
        请将其拆解为 3 到 5 个具体的、可立即执行的微任务。
        
        要求：
        1. 每个任务字数简短（不超过15字）。
        2. 仅返回任务内容，每行一个任务。
        3. 不要包含编号或多余的解释。
        """
        
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": "你是一个高效的任务规划专家。"],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AIError.networkError
        }
        
        // 解析返回结果
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            // 将返回的多行文本拆分为数组
            let tasks = content.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            return tasks
        }
        
        throw AIError.decodingError
    }
}
