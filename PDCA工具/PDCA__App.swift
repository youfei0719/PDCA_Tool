import SwiftUI
import SwiftData

@main
struct PDCAApp: App {
    var sharedModelContainer: ModelContainer = {
        // 注册全新的三层架构
        let schema = Schema([
            Goal.self,
            Milestone.self,
            PDCATask.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("无法创建数据库：\(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
