import Foundation
import HealthKit
import Observation

@Observable
final class HealthManager {
    static let shared = HealthManager()
    private let healthStore = HKHealthStore()
    
    var isAuthorized: Bool = false
    var todaySteps: Int = 0
    var sleepHoursLastNight: Double = 0.0
    var focusMinutesToday: Double = 0.0
    
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
    private let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession)!
    
    private init() {}
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let typesToRead: Set<HKObjectType> = [stepType, sleepType, mindfulType]
        
        // 现在直接使用 Task，不再需要 Swift. 前缀，绝对不会报错
        Task {
            do {
                try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
                await MainActor.run {
                    self.isAuthorized = true
                }
                await fetchAllData()
            } catch {
                print("授权失败: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchAllData() async {
        await fetchTodaySteps()
        await fetchLastNightSleep()
        await fetchTodayFocusMinutes()
    }
    
    private func fetchTodaySteps() async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else { return }
            let steps = Int(sum.doubleValue(for: HKUnit.count()))
            DispatchQueue.main.async { self.todaySteps = steps }
        }
        healthStore.execute(query)
    }
    
    private func fetchLastNightSleep() async {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -1, to: endDate) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else { return }
            let totalSleepSeconds = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            DispatchQueue.main.async { self.sleepHoursLastNight = (totalSleepSeconds / 3600.0 * 10).rounded() / 10 }
        }
        healthStore.execute(query)
    }
    
    private func fetchTodayFocusMinutes() async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: []) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else { return }
            let totalMinutes = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 60.0
            DispatchQueue.main.async { self.focusMinutesToday = (totalMinutes * 10).rounded() / 10 }
        }
        healthStore.execute(query)
    }
}
