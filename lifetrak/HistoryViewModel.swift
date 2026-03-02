import Foundation
import SwiftData

/// A single day's worth of water events and optional sleep data.
struct DaySummary: Identifiable {
    let date: Date          // start of day
    let entries: [Event]
    let sleepNight: SleepNight?

    var id: Date { date }
    var total: Double { entries.reduce(0.0) { $0 + ($1.quantity ?? 0) } }
}

@MainActor
@Observable
final class HistoryViewModel {
    private let modelContext: ModelContext
    private let healthService: (any HealthKitServiceProtocol)?

    var daySummaries: [DaySummary] = []
    var healthAuthStatus: HealthAuthStatus = .notRequested

    // Internal storage for merging two data sources
    private var waterByDay: [Date: [Event]] = [:]
    private var sleepByDay: [Date: SleepNight] = [:]
    private var waterActivity: Activity?

    init(modelContext: ModelContext, healthService: (any HealthKitServiceProtocol)? = nil) {
        self.modelContext = modelContext
        self.healthService = healthService
        fetchWaterActivity()
        refresh()
    }

    // MARK: - Actions

    func addEntry(amount: Double, timestamp: Date = .now) {
        guard let activity = waterActivity else { return }
        let event = Event(activity: activity, timestamp: timestamp, quantity: amount)
        modelContext.insert(event)
        try? modelContext.save()
        refresh()
    }

    func deleteEntry(_ entry: Event) {
        modelContext.delete(entry)
        try? modelContext.save()
        refresh()
    }

    func updateEntry(_ entry: Event, amount: Double? = nil, timestamp: Date? = nil) {
        if let amount { entry.quantity = amount }
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

    private func fetchWaterActivity() {
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate<Activity> { $0.name == "Drink Water" }
        )
        waterActivity = try? modelContext.fetch(descriptor).first
    }

    private func refreshWater() {
        fetchWaterActivity()

        var descriptor = FetchDescriptor<Event>()
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]

        let allEvents = (try? modelContext.fetch(descriptor)) ?? []
        let waterID = waterActivity?.persistentModelID
        let waterEvents = allEvents.filter { $0.activity?.persistentModelID == waterID }

        let calendar = Calendar.current
        waterByDay = Dictionary(grouping: waterEvents) { event in
            calendar.startOfDay(for: event.timestamp)
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
