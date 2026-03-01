import Foundation
import SwiftData

/// A single day's worth of water entries with a computed total.
struct DaySummary: Identifiable {
    let date: Date          // start of day
    let entries: [WaterEntry]

    var id: Date { date }
    var total: Double { entries.reduce(0.0) { $0 + $1.amount } }
}

@MainActor
@Observable
final class HistoryViewModel {
    private let modelContext: ModelContext

    var daySummaries: [DaySummary] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }

    // MARK: - Actions

    func addEntry(amount: Double, timestamp: Date = .now) {
        let entry = WaterEntry(timestamp: timestamp, amount: amount)
        modelContext.insert(entry)
        try? modelContext.save()
        refresh()
    }

    func deleteEntry(_ entry: WaterEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        refresh()
    }

    func updateEntry(_ entry: WaterEntry, amount: Double? = nil, timestamp: Date? = nil) {
        if let amount { entry.amount = amount }
        if let timestamp { entry.timestamp = timestamp }
        try? modelContext.save()
        refresh()
    }

    // MARK: - Refresh

    func refresh() {
        var descriptor = FetchDescriptor<WaterEntry>()
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]

        let allEntries = (try? modelContext.fetch(descriptor)) ?? []

        // Group by start-of-day
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: allEntries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }

        // Sort groups by date (newest first), entries within each group newest first
        daySummaries = grouped
            .map { date, entries in
                DaySummary(
                    date: date,
                    entries: entries.sorted { $0.timestamp > $1.timestamp }
                )
            }
            .sorted { $0.date > $1.date }
    }
}
