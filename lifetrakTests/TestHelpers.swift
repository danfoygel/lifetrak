import Foundation
import SwiftData
@testable import lifetrak

/// Shared test helpers for creating isolated SwiftData containers.
@MainActor
enum TestHelpers {
    /// Creates a unique in-memory ModelContainer.
    /// Each call returns an isolated container that won't conflict with others.
    static func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            "test-\(UUID().uuidString)",
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: WaterEntry.self, configurations: config)
    }

    /// Creates an ephemeral UserDefaults suite for testing.
    static func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    }
}
