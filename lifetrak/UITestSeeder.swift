#if DEBUG
import Foundation
import SwiftData

enum UITestSeeder {
    static func seed(container: ModelContainer) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--seed-partial-day")    { seedPartialDay(container) }
        if args.contains("--seed-goal-met")        { seedGoalMet(container) }
        if args.contains("--seed-water-history")   { seedWaterHistory(container) }
    }

    // Creates the "Drink Water" activity + default routine + 64 oz goal.
    // TodayViewModel.ensureDefaults() will find these and skip re-creating them.
    private static func makeDefaults(context: ModelContext) -> Activity {
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

        let routine = Routine(name: "Standard", isDefault: true)
        context.insert(routine)

        let goal = Goal(
            routine: routine,
            activity: activity,
            period: .daily,
            targetQuantity: 64.0
        )
        context.insert(goal)

        return activity
    }

    // 3 × 8 oz today → 24 oz of 64 oz goal (37.5 %)
    private static func seedPartialDay(_ container: ModelContainer) {
        let context = container.mainContext
        let activity = makeDefaults(context: context)
        for _ in 0..<3 {
            context.insert(Event(activity: activity, timestamp: .now, quantity: 8))
        }
        try? context.save()
    }

    // 8 × 8 oz today → exactly 64 oz, goal met
    private static func seedGoalMet(_ container: ModelContainer) {
        let context = container.mainContext
        let activity = makeDefaults(context: context)
        for _ in 0..<8 {
            context.insert(Event(activity: activity, timestamp: .now, quantity: 8))
        }
        try? context.save()
    }

    // 64 oz/day for the past 30 days → 30-day streak (today inclusive)
    private static func seedWaterHistory(_ container: ModelContainer) {
        let context = container.mainContext
        let activity = makeDefaults(context: context)
        let cal = Calendar.current
        for dayOffset in 0..<30 {
            let date = cal.date(byAdding: .day, value: -dayOffset, to: .now)!
            context.insert(Event(activity: activity, timestamp: date, quantity: 64))
        }
        try? context.save()
    }
}
#endif
