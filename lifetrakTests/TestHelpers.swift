import Foundation
import SwiftData
@testable import lifetrak

/// Shared test helpers for creating isolated SwiftData containers.
@MainActor
enum TestHelpers {
    /// Creates a unique in-memory ModelContainer with all app models.
    /// Each call returns an isolated container that won't conflict with others.
    static func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            "test-\(UUID().uuidString)",
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: Activity.self, Event.self, Routine.self, Goal.self,
            RoutineSchedule.self, WaterEntry.self,
            configurations: config
        )
    }

    /// Creates an ephemeral UserDefaults suite for testing.
    static func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    }

    /// Creates a "Drink Water" activity and inserts it into the context.
    @discardableResult
    static func makeWaterActivity(context: ModelContext) -> Activity {
        let activity = Activity(
            name: "Drink Water",
            emoji: "\u{1F4A7}",
            quantityUnit: "oz",
            tracksDuration: false,
            defaultQuantity: 8.0,
            source: .manual,
            sortOrder: 0
        )
        context.insert(activity)
        return activity
    }

    /// Creates a default routine with a water goal and inserts it into the context.
    @discardableResult
    static func makeDefaultRoutine(
        context: ModelContext,
        waterActivity: Activity,
        dailyGoal: Double = 64.0
    ) -> Routine {
        let routine = Routine(name: "Standard", isDefault: true)
        context.insert(routine)

        let goal = Goal(
            routine: routine,
            activity: waterActivity,
            period: .daily,
            targetQuantity: dailyGoal
        )
        context.insert(goal)

        return routine
    }
}
