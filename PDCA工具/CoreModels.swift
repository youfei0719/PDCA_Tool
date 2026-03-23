import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID = UUID()
    var title: String
    var creationDate: Date = Date()
    var targetDate: Date?
    var isCompleted: Bool = false
    
    // 一对多关系：一个目标包含多个任务
    @Relationship(deleteRule: .cascade, inverse: \PDCATask.goal)
    var tasks: [PDCATask] = []
    
    init(title: String, targetDate: Date? = nil) {
        self.title = title
        self.targetDate = targetDate
    }
}

@Model
final class PDCATask {
    var id: UUID = UUID()
    var title: String
    var difficultyLevel: Int = 3
    var scheduledDate: Date = Date()
    var isCompleted: Bool = false
    var goal: Goal?
    
    @Relationship(deleteRule: .cascade, inverse: \PDCACycle.task)
    var pdcaCycles: [PDCACycle] = []
    
    init(title: String) {
        self.title = title
    }
}

@Model
final class PDCACycle {
    var id: UUID = UUID()
    var date: Date = Date()
    var reflectionDiary: String = ""
    var sleepHoursLastNight: Double?
    var stepsToday: Int?
    var task: PDCATask?
    
    init() {}
}

@Model
final class AppSettings {
    var isPremium: Bool = false
    var customAIKey: String = ""
    init() {}
}
