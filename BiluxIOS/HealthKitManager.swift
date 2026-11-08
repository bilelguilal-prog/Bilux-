import Foundation
import Combine
import HealthKit

struct DailyHealthSummary {
    var steps: Double?
    var activeKcal: Double?
    var heartRateBPM: Double?
    var weightKG: Double?
    var sleepHours: Double?
    var workoutMinutes: Double?
    var consumedKcal: Double?
    var protein: Double?
    var carbs: Double?
    var fats: Double?
    var nutritionSource: String = "Apple Santé"
    var isMFPDetected: Bool = false
}

@MainActor
final class HealthKitManager: ObservableObject {
    @Published private(set) var today = DailyHealthSummary()
    @Published private(set) var loading = false
    @Published private(set) var hasRequested = UserDefaults.standard.bool(forKey: "bilux-health-requested")
    @Published var message: String?
    private let store = HKHealthStore()

    private let nutritionTypes: [HKQuantityTypeIdentifier] = [.dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal]
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType(), HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!]
        let quantity: [HKQuantityTypeIdentifier] = [.stepCount, .activeEnergyBurned, .heartRate, .bodyMass] + nutritionTypes
        for type in quantity { if let object = HKObjectType.quantityType(forIdentifier: type) { types.insert(object) } }
        return types
    }
    func connect() async {
        guard HKHealthStore.isHealthDataAvailable() else { message = "Apple Santé n'est pas disponible sur cet appareil."; return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            hasRequested = true
            UserDefaults.standard.set(true, forKey: "bilux-health-requested")
            // Apple ne dévoile pas quelles autorisations de lecture ont été accordées.
            await refresh()
        } catch { message = "Accès à Santé non configuré : \(error.localizedDescription)" }
    }
    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        loading = true
        defer { loading = false }
        let start = Calendar.current.startOfDay(for: .now)
        let end = Date()
        var next = DailyHealthSummary()
        do {
            next.steps = try await sum(.stepCount, unit: .count(), start: start, end: end)
            next.activeKcal = try await sum(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)
            next.heartRateBPM = try await latest(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()), since: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? start)
            next.weightKG = try await latest(.bodyMass, unit: .gramUnit(with: .kilo), since: Calendar.current.date(byAdding: .year, value: -2, to: .now) ?? start)
            next.workoutMinutes = try await workoutTime(start: start, end: end)
            next.sleepHours = try await sleepTime()
            let energy = try await nutrient(.dietaryEnergyConsumed, unit: .kilocalorie(), start: start, end: end)
            let protein = try await nutrient(.dietaryProtein, unit: .gram(), start: start, end: end)
            let carbs = try await nutrient(.dietaryCarbohydrates, unit: .gram(), start: start, end: end)
            let fats = try await nutrient(.dietaryFatTotal, unit: .gram(), start: start, end: end)
            next.consumedKcal = energy.value
            next.protein = protein.value
            next.carbs = carbs.value
            next.fats = fats.value
            next.isMFPDetected = [energy, protein, carbs, fats].contains(where: { $0.fromMFP })
            next.nutritionSource = next.isMFPDetected ? "MyFitnessPal → Apple Santé" : "Apple Santé (autre source)"
            today = next
        } catch {
            today = next
            message = "Lecture Santé incomplète : \(error.localizedDescription). Vérifie les autorisations dans Réglages > Santé."
        }
    }
    private func sum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end), options: .cumulativeSum) { _, statistics, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }
    private func samples(type: HKSampleType, predicate: NSPredicate?, limit: Int = HKObjectQueryNoLimit, sort: [NSSortDescriptor]? = nil) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: sort) { _, objects, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: objects ?? []) }
            }
            store.execute(query)
        }
    }
    private func latest(_ id: HKQuantityTypeIdentifier, unit: HKUnit, since: Date) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: since, end: .now)
        let list = try await samples(type: type, predicate: predicate, limit: 1, sort: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)])
        return (list.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
    }
    private func workoutTime(start: Date, end: Date) async throws -> Double? {
        let list = try await samples(type: HKObjectType.workoutType(), predicate: HKQuery.predicateForSamples(withStart: start, end: end))
        guard !list.isEmpty else { return nil }
        return list.compactMap { $0 as? HKWorkout }.reduce(0) { $0 + $1.duration / 60.0 }
    }
    private func sleepTime() async throws -> Double? {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let previousEvening = Calendar.current.date(byAdding: .hour, value: -6, to: startOfDay) ?? startOfDay
        let list = try await samples(type: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!, predicate: HKQuery.predicateForSamples(withStart: previousEvening, end: .now))
        let sleepingValues = Set([HKCategoryValueSleepAnalysis.asleep.rawValue, HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue])
        let total = list.compactMap { $0 as? HKCategorySample }.filter { sleepingValues.contains($0.value) }.reduce(0.0) { seconds, sample in
            seconds + max(0, min(Date(), sample.endDate).timeIntervalSince(max(previousEvening, sample.startDate)))
        }
        return total > 0 ? total / 3600 : nil
    }
    private func nutrient(_ id: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> (value: Double?, fromMFP: Bool) {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return (nil, false) }
        let list = try await samples(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: end))
        let values = list.compactMap { $0 as? HKQuantitySample }
        if values.isEmpty { return (nil, false) }
        // On donne priorité aux échantillons MyFitnessPal lorsqu'ils existent.
        // Ne jamais additionner MFP + un autre export de la même alimentation.
        let mfp = values.filter { $0.sourceRevision.source.name.localizedCaseInsensitiveContains("myfitnesspal") }
        let chosen = mfp.isEmpty ? values : mfp
        return (chosen.reduce(0) { $0 + $1.quantity.doubleValue(for: unit) }, !mfp.isEmpty)
    }
}
