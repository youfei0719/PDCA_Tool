import SwiftUI
import SwiftData

@main
struct PDCAApp: App {
    var sharedModelContainer: ModelContainer = {
        // 🌟 修复：只保留当前实际存在的两个核心模型，去掉历史遗留的无效模型
        let schema = Schema([
            Goal.self,
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
