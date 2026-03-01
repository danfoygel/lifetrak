import Foundation
import SwiftData

/// Keys for water settings stored in UserDefaults.
enum WaterSettings {
    static let dailyGoalKey = "waterDailyGoal"
    static let servingSizeKey = "waterServingSize"

    static let defaultDailyGoal: Double = 64.0
    static let defaultServingSize: Double = 8.0
}

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
    private let defaults: UserDefaults

    var todayEntries: [WaterEntry] = []
    var todayTotal: Double = 0.0
    var weeklyData: [DayTotal] = []
    var currentStreak: Int = 0

    var dailyGoal: Double {
        didSet { defaults.set(dailyGoal, forKey: WaterSettings.dailyGoalKey) }
    }
    var servingSize: Double {
        didSet { defaults.set(servingSize, forKey: WaterSettings.servingSizeKey) }
    }

    init(modelContext: ModelContext, defaults: UserDefaults = .standard) {
        self.modelContext = modelContext
        self.defaults = defaults

        let storedGoal = defaults.double(forKey: WaterSettings.dailyGoalKey)
        self.dailyGoal = storedGoal > 0 ? storedGoal : WaterSettings.defaultDailyGoal

        let storedServing = defaults.double(forKey: WaterSettings.servingSizeKey)
        self.servingSize = storedServing > 0 ? storedServing : WaterSettings.defaultServingSize

        refresh()
    }

    // MARK: - Computed

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
        let entry = WaterEntry(amount: servingSize)
        modelContext.insert(entry)
        try? modelContext.save()
        refresh()
    }

    func refresh() {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: .now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch today's entries
        var todayDescriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate<WaterEntry> { entry in
                entry.timestamp >= startOfDay && entry.timestamp < tomorrow
            }
        )
        todayDescriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]

        todayEntries = (try? modelContext.fetch(todayDescriptor)) ?? []
        todayTotal = todayEntries.reduce(0.0) { $0 + $1.amount }

        // Fetch last 7 days for weekly chart
        let sevenDaysAgo = cal.date(byAdding: .day, value: -6, to: startOfDay)!
        let weekDescriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate<WaterEntry> { entry in
                entry.timestamp >= sevenDaysAgo && entry.timestamp < tomorrow
            }
        )
        let weekEntries = (try? modelContext.fetch(weekDescriptor)) ?? []

        // Group by day and build array for 7 days (oldest → newest for chart)
        let grouped = Dictionary(grouping: weekEntries) { entry in
            cal.startOfDay(for: entry.timestamp)
        }
        weeklyData = (0..<7).map { daysBack in
            let dayStart = cal.date(byAdding: .day, value: -(6 - daysBack), to: startOfDay)!
            let dayTotal = (grouped[dayStart] ?? []).reduce(0.0) { $0 + $1.amount }
            return DayTotal(date: dayStart, total: dayTotal)
        }

        // Calculate streak
        currentStreak = computeStreak()
    }

    // MARK: - Streak

    private func computeStreak() -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        // Fetch all entries (we'll walk backwards day by day)
        // Start from today — if today's goal is met, count it; otherwise start from yesterday
        var streak = 0
        let startDay = goalMet ? today : cal.date(byAdding: .day, value: -1, to: today)!
        var checkDate = startDay

        // Walk backwards checking each day
        for _ in 0..<365 { // reasonable upper bound
            let dayStart = checkDate
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!

            let descriptor = FetchDescriptor<WaterEntry>(
                predicate: #Predicate<WaterEntry> { entry in
                    entry.timestamp >= dayStart && entry.timestamp < dayEnd
                }
            )
            let entries = (try? modelContext.fetch(descriptor)) ?? []
            let dayTotal = entries.reduce(0.0) { $0 + $1.amount }

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
