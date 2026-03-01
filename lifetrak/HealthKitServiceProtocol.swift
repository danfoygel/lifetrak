import Foundation

/// Categories for sleep samples, mirroring HKCategoryValueSleepAnalysis.
enum SleepCategory: Sendable {
    case inBed
    case asleepUnspecified
    case asleepCore
    case asleepDeep
    case asleepREM
    case awake
}

/// A simplified representation of a HealthKit sleep sample for aggregation.
/// Decoupled from HKCategorySample for testability.
struct RawSleepSample: Sendable {
    let startDate: Date
    let endDate: Date
    let category: SleepCategory
}

/// Errors that can occur during HealthKit operations.
enum HealthKitError: Error {
    case notAvailable
    case authorizationDenied
    case queryFailed(underlying: Error?)
}

/// Authorization status for HealthKit.
enum HealthAuthStatus {
    case notRequested
    case requested   // authorization has been requested (may or may not be granted)
    case unavailable // device doesn't support HealthKit
}

/// Protocol for HealthKit access, enabling mock injection in tests.
protocol HealthKitServiceProtocol {
    /// Whether HealthKit is available on this device.
    var isAvailable: Bool { get }

    /// Request read authorization for sleep data.
    func requestSleepAuthorization() async throws

    /// Fetch aggregated sleep nights for a date range.
    /// Returns one SleepNight per night, sorted newest first.
    func fetchSleepNights(from startDate: Date, to endDate: Date) async throws -> [SleepNight]
}
