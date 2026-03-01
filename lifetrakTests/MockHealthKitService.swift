import Foundation
@testable import lifetrak

/// Mock HealthKit service for testing. Returns configurable data without
/// touching the real HealthKit store.
@MainActor
final class MockHealthKitService: HealthKitServiceProtocol {
    var isAvailable = true
    var mockSleepNights: [SleepNight] = []
    var shouldThrowOnAuth = false
    var shouldThrowOnFetch = false
    var authorizationRequested = false

    func requestSleepAuthorization() async throws {
        authorizationRequested = true
        if shouldThrowOnAuth {
            throw HealthKitError.authorizationDenied
        }
    }

    func fetchSleepNights(from startDate: Date, to endDate: Date) async throws -> [SleepNight] {
        if shouldThrowOnFetch {
            throw HealthKitError.queryFailed(underlying: nil)
        }
        return mockSleepNights.filter { $0.date >= startDate && $0.date <= endDate }
    }
}
