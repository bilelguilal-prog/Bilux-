import Foundation
import Combine
import HealthKit

/// Relevés locaux facultatifs sur la montre. Lecture uniquement, sans écriture Santé.
@MainActor
final class WatchHealthReader: ObservableObject {
    @Published private(set) var heartRateBPM: Double?
    @Published private(set) var steps: Double?
    @Published private(set) var activeKcal: Double?
    @Published private(set) var loading = false
    @Published var message: String?
    private let store = HKHealthStore()

    func authorizeAndRefresh() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            message = "Apple Santé n'est pas disponible."
            return
        }
        do {
            let types: Set<HKObjectType> = [
                HKObjectType.quantityType(forIdentifier: .heartRate)!,
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
            ]
            try await store.requestAuthorization(toShare: [], read: types)
            await refresh()
        } catch { message = "Autorisation Santé : \(error.localizedDescription)" }
    }

    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable(), !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let day = Calendar.current.startOfDay(for: .now)
            steps = try await total(.stepCount, .count(), since: day)
            activeKcal = try await total(.activeEnergyBurned, .kilocalorie(), since: day)
            heartRateBPM = try await lastHeartRate()
        } catch { message = "Données Santé indisponibles : \(error.localizedDescription)" }
    }

    private func total(_ typeID: HKQuantityTypeIdentifier, _ unit: HKUnit, since: Date) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: typeID) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: since, end: Date()),
                options: .cumulativeSum) { _, stats, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit)) }
                }
            store.execute(query)
        }
    }

    private func lastHeartRate() async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return nil }
        let since = Date().addingTimeInterval(-86_400)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type,
                predicate: HKQuery.predicateForSamples(withStart: since, end: Date()),
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
                    if let error { continuation.resume(throwing: error) }
                    else {
                        let sample = samples?.first as? HKQuantitySample
                        let unit = HKUnit.count().unitDivided(by: .minute())
                        continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
                    }
                }
            store.execute(query)
        }
    }
}
