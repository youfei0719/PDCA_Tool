import Foundation
import SwiftData

@Model
final class Goal {
    var title: String
    var creationDate: Date
    @Relationship(deleteRule: .cascade, inverse: \PDCATask.goal)
    var tasks: [PDCATask] = []
    
    init(title: String, creationDate: Date = Date()) {
        self.title = title
        self.creationDate = creationDate
    }
}

@Model
final class PDCATask {
    var title: String
    var isCompleted: Bool
    // 🌟 新增：永久保存 AI 洞察记录，拒绝“阅后即焚”
    var aiInsight: String?
    var goal: Goal?
    
    init(title: String, isCompleted: Bool = false, aiInsight: String? = nil) {
        self.title = title
        self.isCompleted = isCompleted
        self.aiInsight = aiInsight
    }
}
