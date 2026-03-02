import Foundation
import SwiftData

/// A single day's total for chart display.
struct DayTotal: Identifiable {
    let date: Date
    let total: Double
    var id: Date { date }
}

@MainActor
@Observable
final class TodayViewModel {
    private let modelContext: ModelContext

    var todayEntries: [Event] = []
    var todayTotal: Double = 0.0
    var weeklyData: [DayTotal] = []
    var currentStreak: Int = 0

    /// The water activity — created on first access if needed.
    private(set) var waterActivity: Activity?
    /// The routine in effect today (resolved via RoutineSchedule or default).
    private(set) var activeRoutine: Routine?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        ensureDefaults()
        refresh()
    }

    // MARK: - Computed

    var dailyGoal: Double {
        guard let routine = activeRoutine, let water = waterActivity else { return 64.0 }
        let waterID = water.persistentModelID
        let goal = routine.goals.first { $0.activity?.persistentModelID == waterID }
        return goal?.targetQuantity ?? 64.0
    }

    var servingSize: Double {
        waterActivity?.defaultQuantity ?? 8.0
    }

    var progress: Double {
        guard dailyGoal > 0 else { return 0.0 }
        return min(todayTotal / dailyGoal, 1.0)
    }

    var goalMet: Bool {
        todayTotal >= dailyGoal
    }

    var todayTotalDisplay: String {
        formatOunces(todayTotal)
    }

    var dailyGoalDisplay: String {
        formatOunces(dailyGoal)
    }

    // MARK: - Actions

    func logWater() {
        guard let activity = waterActivity else { return }
        let event = Event(
            activity: activity,
            timestamp: .now,
            quantity: activity.defaultQuantity ?? 8.0
        )
        modelContext.insert(event)
        try? modelContext.save()
        refresh()
    }

    func updateDailyGoal(_ newGoal: Double) {
        guard let routine = activeRoutine, let water = waterActivity else { return }
        let waterID = water.persistentModelID
        if let goal = routine.goals.first(where: { $0.activity?.persistentModelID == waterID }) {
            goal.targetQuantity = newGoal
        } else {
            let goal = Goal(routine: routine, activity: water, period: .daily, targetQuantity: newGoal)
            modelContext.insert(goal)
        }
        try? modelContext.save()
        refresh()
    }

    func updateServingSize(_ newSize: Double) {
        waterActivity?.defaultQuantity = newSize
        try? modelContext.save()
    }

    func refresh() {
        fetchWaterActivity()
        resolveActiveRoutine()

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: .now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch today's events
        var todayDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.timestamp >= startOfDay && event.timestamp < tomorrow
            }
        )
        todayDescriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]

        let allTodayEvents = (try? modelContext.fetch(todayDescriptor)) ?? []
        // Filter to water events in memory (SwiftData predicates can't reliably traverse relationships)
        let waterID = waterActivity?.persistentModelID
        todayEntries = allTodayEvents.filter { $0.activity?.persistentModelID == waterID }
        todayTotal = todayEntries.reduce(0.0) { $0 + ($1.quantity ?? 0) }

        // Fetch last 7 days for weekly chart
        let sevenDaysAgo = cal.date(byAdding: .day, value: -6, to: startOfDay)!
        let weekDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.timestamp >= sevenDaysAgo && event.timestamp < tomorrow
            }
        )
        let weekEvents = (try? modelContext.fetch(weekDescriptor)) ?? []
        let waterWeekEvents = weekEvents.filter { $0.activity?.persistentModelID == waterID }

        let grouped = Dictionary(grouping: waterWeekEvents) { event in
            cal.startOfDay(for: event.timestamp)
        }
        weeklyData = (0..<7).map { daysBack in
            let dayStart = cal.date(byAdding: .day, value: -(6 - daysBack), to: startOfDay)!
            let dayTotal = (grouped[dayStart] ?? []).reduce(0.0) { $0 + ($1.quantity ?? 0) }
            return DayTotal(date: dayStart, total: dayTotal)
        }

        currentStreak = computeStreak()
    }

    // MARK: - Setup

    private func ensureDefaults() {
        fetchWaterActivity()
        if waterActivity == nil {
            let activity = Activity(
                name: "Drink Water",
                emoji: "\u{1F4A7}",
                quantityUnit: "oz",
                tracksDuration: false,
                defaultQuantity: 8.0,
                source: .manual,
                sortOrder: 0
            )
            modelContext.insert(activity)
            waterActivity = activity
        }

        resolveActiveRoutine()
        if activeRoutine == nil {
            let routine = Routine(name: "Standard", isDefault: true)
            modelContext.insert(routine)

            let goal = Goal(
                routine: routine,
                activity: waterActivity!,
                period: .daily,
                targetQuantity: 64.0
            )
            modelContext.insert(goal)
            activeRoutine = routine
        }

        try? modelContext.save()
    }

    private func fetchWaterActivity() {
        if waterActivity != nil { return }
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate<Activity> { $0.name == "Drink Water" }
        )
        waterActivity = try? modelContext.fetch(descriptor).first
    }

    private func resolveActiveRoutine() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        // Check for a RoutineSchedule covering today
        let scheduleDescriptor = FetchDescriptor<RoutineSchedule>(
            predicate: #Predicate<RoutineSchedule> { schedule in
                schedule.startDate <= today && schedule.endDate >= today
            }
        )
        if let schedule = try? modelContext.fetch(scheduleDescriptor).first,
           let routine = schedule.routine {
            activeRoutine = routine
            return
        }

        // Fall back to the default routine
        let defaultDescriptor = FetchDescriptor<Routine>(
            predicate: #Predicate<Routine> { $0.isDefault == true && $0.isSnapshot == false }
        )
        activeRoutine = try? modelContext.fetch(defaultDescriptor).first
    }

    // MARK: - Streak

    private func computeStreak() -> Int {
        guard let waterID = waterActivity?.persistentModelID else { return 0 }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        var streak = 0
        let startDay = goalMet ? today : cal.date(byAdding: .day, value: -1, to: today)!
        var checkDate = startDay

        for _ in 0..<365 {
            let dayStart = checkDate
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!

            let descriptor = FetchDescriptor<Event>(
                predicate: #Predicate<Event> { event in
                    event.timestamp >= dayStart && event.timestamp < dayEnd
                }
            )
            let events = (try? modelContext.fetch(descriptor)) ?? []
            let dayTotal = events
                .filter { $0.activity?.persistentModelID == waterID }
                .reduce(0.0) { $0 + ($1.quantity ?? 0) }

            if dayTotal >= dailyGoal {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Helpers

    private func formatOunces(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

// Expose serving size formatting for the view
extension TodayViewModel {
    func formatServingSize() -> String {
        let size = servingSize
        if size == size.rounded() {
            return String(Int(size))
        }
        return String(format: "%.1f", size)
    }
}
