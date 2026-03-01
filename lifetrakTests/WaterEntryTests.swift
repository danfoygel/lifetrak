import Foundation
import Testing
import SwiftData
@testable import lifetrak

@MainActor
struct WaterEntryTests {

    /// Helper: creates an in-memory ModelContainer for testing.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: WaterEntry.self, configurations: config)
    }

    // MARK: - Creation

    @Test func createEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let entry = WaterEntry(amount: 8.0)
        context.insert(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WaterEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.amount == 8.0)
    }

    @Test func createEntryWithCustomTimestamp() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let date = Date(timeIntervalSince1970: 1_000_000)
        let entry = WaterEntry(timestamp: date, amount: 12.0)
        context.insert(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WaterEntry>())
        #expect(entries.first?.timestamp == date)
        #expect(entries.first?.amount == 12.0)
    }

    @Test func defaultTimestampIsNow() throws {
        let before = Date.now
        let entry = WaterEntry(amount: 8.0)
        let after = Date.now

        #expect(entry.timestamp >= before)
        #expect(entry.timestamp <= after)
    }

    // MARK: - Deletion

    @Test func deleteEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let entry = WaterEntry(amount: 8.0)
        context.insert(entry)
        try context.save()

        context.delete(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WaterEntry>())
        #expect(entries.isEmpty)
    }

    // MARK: - Querying today's entries

    @Test func fetchTodayEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Today's entry
        let todayEntry = WaterEntry(amount: 8.0)
        context.insert(todayEntry)

        // Yesterday's entry
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let oldEntry = WaterEntry(timestamp: yesterday, amount: 16.0)
        context.insert(oldEntry)

        try context.save()

        let startOfDay = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        var descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate<WaterEntry> { entry in
                entry.timestamp >= startOfDay && entry.timestamp < tomorrow
            }
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp)]

        let todayEntries = try context.fetch(descriptor)
        #expect(todayEntries.count == 1)
        #expect(todayEntries.first?.amount == 8.0)
    }

    // MARK: - Summing today's total

    @Test func sumTodayTotal() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(WaterEntry(amount: 8.0))
        context.insert(WaterEntry(amount: 12.0))
        context.insert(WaterEntry(amount: 8.0))

        // Yesterday — should not be counted
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        context.insert(WaterEntry(timestamp: yesterday, amount: 99.0))

        try context.save()

        let startOfDay = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate<WaterEntry> { entry in
                entry.timestamp >= startOfDay && entry.timestamp < tomorrow
            }
        )

        let todayEntries = try context.fetch(descriptor)
        let total = todayEntries.reduce(0.0) { $0 + $1.amount }
        #expect(total == 28.0)
    }

    // MARK: - Multiple entries

    @Test func multipleEntriesPersist() throws {
        let container = try makeContainer()
        let context = container.mainContext

        for i in 1...5 {
            context.insert(WaterEntry(amount: Double(i) * 4.0))
        }
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WaterEntry>())
        #expect(entries.count == 5)
    }

    // MARK: - Update

    @Test func updateEntryAmount() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let entry = WaterEntry(amount: 8.0)
        context.insert(entry)
        try context.save()

        entry.amount = 16.0
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WaterEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.amount == 16.0)
    }
}
