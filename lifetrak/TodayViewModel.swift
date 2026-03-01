import Foundation
import SwiftData

@MainActor
@Observable
final class TodayViewModel {
    private let modelContext: ModelContext

    var todayEntries: [WaterEntry] = []
    var todayTotal: Double = 0.0

    var dailyGoal: Double = 64.0
    var servingSize: Double = 8.0

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        var descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate<WaterEntry> { entry in
                entry.timestamp >= startOfDay && entry.timestamp < tomorrow
            }
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]

        todayEntries = (try? modelContext.fetch(descriptor)) ?? []
        todayTotal = todayEntries.reduce(0.0) { $0 + $1.amount }
    }

    // MARK: - Helpers

    private func formatOunces(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
