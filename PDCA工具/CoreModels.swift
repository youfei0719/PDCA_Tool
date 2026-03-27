import Foundation
import SwiftData

// 1. 顶层：宏观目标 (Goal)
@Model
final class Goal {
    var title: String
    var creationDate: Date
    
    // 级联删除：目标被删，下面的里程碑跟着删
    @Relationship(deleteRule: .cascade, inverse: \Milestone.goal)
    var milestones: [Milestone] = []
    
    init(title: String, creationDate: Date = Date()) {
        self.title = title
        self.creationDate = creationDate
    }
}

// 2. 中层：大计划/里程碑 (Milestone)
@Model
final class Milestone {
    var title: String
    var creationDate: Date
    
    @Relationship(deleteRule: .cascade, inverse: \PDCATask.milestone)
    var tasks: [PDCATask] = []
    
    var goal: Goal?
    
    init(title: String, creationDate: Date = Date()) {
        self.title = title
        self.creationDate = creationDate
    }
    
    // 计算属性：进度百分比
    var progress: Double {
        if tasks.isEmpty { return 0.0 }
        let completed = tasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(tasks.count)
    }
}

// 3. 底层：原子级微动作 (PDCATask)
@Model
final class PDCATask {
    var title: String
    var isCompleted: Bool
    var aiInsight: String?
    var creationDate: Date
    var milestone: Milestone?
    
    init(title: String, isCompleted: Bool = false, aiInsight: String? = nil, creationDate: Date = Date()) {
        self.title = title
        self.isCompleted = isCompleted
        self.aiInsight = aiInsight
        self.creationDate = creationDate
    }
}
