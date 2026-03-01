import Foundation
import HealthKit

/// Production HealthKit service that queries the real Health store.
final class HealthKitService: HealthKitServiceProtocol {
    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestSleepAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        let sleepType = HKCategoryType(.sleepAnalysis)
        try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
    }

    func fetchSleepNights(from startDate: Date, to endDate: Date) async throws -> [SleepNight] {
        guard isAvailable else { return [] }

        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let store = healthStore
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                } else {
                    continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
                }
            }
            store.execute(query)
        }

        let rawSamples = samples.map { sample in
            RawSleepSample(
                startDate: sample.startDate,
                endDate: sample.endDate,
                category: SleepCategory(healthKitValue: sample.value)
            )
        }

        return SleepAggregator.aggregate(rawSamples)
    }
}

extension SleepCategory {
    init(healthKitValue: Int) {
        switch HKCategoryValueSleepAnalysis(rawValue: healthKitValue) {
        case .inBed: self = .inBed
        case .asleepUnspecified: self = .asleepUnspecified
        case .asleepCore: self = .asleepCore
        case .asleepDeep: self = .asleepDeep
        case .asleepREM: self = .asleepREM
        case .awake: self = .awake
        default: self = .asleepUnspecified
        }
    }
}
