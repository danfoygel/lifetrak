import Foundation
import SwiftData

/// A single day's worth of water entries and optional sleep data.
struct DaySummary: Identifiable {
    let date: Date          // start of day
    let entries: [WaterEntry]
    let sleepNight: SleepNight?

    var id: Date { date }
    var total: Double { entries.reduce(0.0) { $0 + $1.amount } }
}

@MainActor
@Observable
final class HistoryViewModel {
    private let modelContext: ModelContext
    private let healthService: (any HealthKitServiceProtocol)?

    var daySummaries: [DaySummary] = []
    var healthAuthStatus: HealthAuthStatus = .notRequested

    // Internal storage for merging two data sources
    private var waterByDay: [Date: [WaterEntry]] = [:]
    private var sleepByDay: [Date: SleepNight] = [:]

    init(modelContext: ModelContext, healthService: (any HealthKitServiceProtocol)? = nil) {
        self.modelContext = modelContext
        self.healthService = healthService
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

    /// Synchronous refresh: loads water immediately, kicks off async sleep fetch.
    func refresh() {
        refreshWater()
        buildDaySummaries()

        if let service = healthService {
            Task {
                await refreshSleep(service: service)
                buildDaySummaries()
            }
        }
    }

    /// Async refresh: loads both water and sleep before returning.
    /// Use in tests for deterministic results.
    func refreshWithSleep() async {
        refreshWater()
        if let service = healthService {
            await refreshSleep(service: service)
        }
        buildDaySummaries()
    }

    // MARK: - Private

    private func refreshWater() {
        var descriptor = FetchDescriptor<WaterEntry>()
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]

        let allEntries = (try? modelContext.fetch(descriptor)) ?? []

        let calendar = Calendar.current
        waterByDay = Dictionary(grouping: allEntries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
    }

    private func refreshSleep(service: any HealthKitServiceProtocol) async {
        if !service.isAvailable {
            healthAuthStatus = .unavailable
            return
        }

        if healthAuthStatus == .notRequested {
            try? await service.requestSleepAuthorization()
            healthAuthStatus = .requested
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let startDate = calendar.date(byAdding: .day, value: -30, to: startOfToday)!

        let nights = (try? await service.fetchSleepNights(from: startDate, to: endDate)) ?? []
        sleepByDay = Dictionary(uniqueKeysWithValues: nights.map { ($0.date, $0) })
    }

    private func buildDaySummaries() {
        let allDates = Set(waterByDay.keys).union(Set(sleepByDay.keys))

        daySummaries = allDates.map { date in
            let entries = (waterByDay[date] ?? []).sorted { $0.timestamp > $1.timestamp }
            return DaySummary(
                date: date,
                entries: entries,
                sleepNight: sleepByDay[date]
            )
        }
        .sorted { $0.date > $1.date }
    }
}
