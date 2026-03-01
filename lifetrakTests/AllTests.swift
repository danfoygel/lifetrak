import Foundation
import Testing
import SwiftData
@testable import lifetrak

/// All SwiftData tests in a single serialized suite to prevent concurrent
/// ModelContainer creation, which crashes on iOS 26 beta.
@MainActor
@Suite(.serialized)
struct AllTests {

    // MARK: - WaterEntry: Creation

    @Test func waterEntry_create() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let entry = WaterEntry(amount: 8.0)
        context.insert(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WaterEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.amount == 8.0)
    }

    @Test func waterEntry_createWithCustomTimestamp() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let date = Date(timeIntervalSince1970: 1_000_000)
        let entry = WaterEntry(timestamp: date, amount: 12.0)
        context.insert(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WaterEntry>())
        #expect(entries.first?.timestamp == date)
        #expect(entries.first?.amount == 12.0)
    }

    @Test func waterEntry_defaultTimestampIsNow() throws {
        let before = Date.now
        let entry = WaterEntry(amount: 8.0)
        let after = Date.now
        #expect(entry.timestamp >= before)
        #expect(entry.timestamp <= after)
    }

    // MARK: - WaterEntry: Deletion

    @Test func waterEntry_delete() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let entry = WaterEntry(amount: 8.0)
        context.insert(entry)
        try context.save()
        context.delete(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WaterEntry>())
        #expect(entries.isEmpty)
    }

    // MARK: - WaterEntry: Queries

    @Test func waterEntry_fetchToday() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        context.insert(WaterEntry(amount: 8.0))
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        context.insert(WaterEntry(timestamp: yesterday, amount: 16.0))
        try context.save()

        let startOfDay = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        var descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate<WaterEntry> { $0.timestamp >= startOfDay && $0.timestamp < tomorrow }
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp)]

        let todayEntries = try context.fetch(descriptor)
        #expect(todayEntries.count == 1)
        #expect(todayEntries.first?.amount == 8.0)
    }

    @Test func waterEntry_sumToday() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        context.insert(WaterEntry(amount: 8.0))
        context.insert(WaterEntry(amount: 12.0))
        context.insert(WaterEntry(amount: 8.0))
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        context.insert(WaterEntry(timestamp: yesterday, amount: 99.0))
        try context.save()

        let startOfDay = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate<WaterEntry> { $0.timestamp >= startOfDay && $0.timestamp < tomorrow }
        )
        let todayEntries = try context.fetch(descriptor)
        let total = todayEntries.reduce(0.0) { $0 + $1.amount }
        #expect(total == 28.0)
    }

    @Test func waterEntry_multiplePersist() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        for i in 1...5 {
            context.insert(WaterEntry(amount: Double(i) * 4.0))
        }
        try context.save()

        let entries = try context.fetch(FetchDescriptor<WaterEntry>())
        #expect(entries.count == 5)
    }

    @Test func waterEntry_update() throws {
        let container = try TestHelpers.makeContainer()
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

    // MARK: - TodayViewModel: Initial state

    @Test func vm_initialTodayTotalIsZero() throws {
        let (vm, _) = try makeVM()
        #expect(vm.todayTotal == 0.0)
    }

    @Test func vm_initialProgressIsZero() throws {
        let (vm, _) = try makeVM()
        #expect(vm.progress == 0.0)
    }

    // MARK: - TodayViewModel: Logging

    @Test func vm_logWaterIncreasesTotal() throws {
        let (vm, _keepAlive) = try makeVM()
        vm.logWater()
        #expect(vm.todayTotal == 8.0)
        _ = _keepAlive
    }

    @Test func vm_logWaterMultipleTimes() throws {
        let (vm, _keepAlive) = try makeVM()
        vm.logWater()
        vm.logWater()
        vm.logWater()
        #expect(vm.todayTotal == 24.0)
        _ = _keepAlive
    }

    @Test func vm_logWaterCreatesEntry() throws {
        let (vm, _keepAlive) = try makeVM()
        vm.logWater()
        #expect(vm.todayEntries.count == 1)
        #expect(vm.todayEntries.first?.amount == 8.0)
        _ = _keepAlive
    }

    // MARK: - TodayViewModel: Progress

    @Test func vm_progressCalculation() throws {
        let (vm, _keepAlive) = try makeVM()
        vm.logWater()
        #expect(vm.progress == 8.0 / 64.0)
        _ = _keepAlive
    }

    @Test func vm_progressCapsAtOne() throws {
        let (vm, _keepAlive) = try makeVM()
        for _ in 0..<10 { vm.logWater() }
        #expect(vm.progress == 1.0)
        _ = _keepAlive
    }

    // MARK: - TodayViewModel: Goal

    @Test func vm_goalMetAtTarget() throws {
        let (vm, _keepAlive) = try makeVM()
        for _ in 0..<8 { vm.logWater() }
        #expect(vm.goalMet == true)
        _ = _keepAlive
    }

    @Test func vm_goalNotMetBelowTarget() throws {
        let (vm, _keepAlive) = try makeVM()
        vm.logWater()
        #expect(vm.goalMet == false)
        _ = _keepAlive
    }

    @Test func vm_excludesYesterday() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        context.insert(WaterEntry(timestamp: yesterday, amount: 32.0))
        try context.save()

        let vm = TodayViewModel(modelContext: context, defaults: TestHelpers.makeDefaults())
        vm.refresh()
        #expect(vm.todayTotal == 0.0)
        #expect(vm.todayEntries.isEmpty)
    }

    // MARK: - TodayViewModel: Custom settings

    @Test func vm_customServingSize() throws {
        let (vm, _keepAlive) = try makeVM()
        vm.servingSize = 12.0
        vm.logWater()
        #expect(vm.todayTotal == 12.0)
        _ = _keepAlive
    }

    @Test func vm_customGoal() throws {
        let (vm, _keepAlive) = try makeVM()
        vm.dailyGoal = 32.0
        vm.logWater()
        #expect(vm.progress == 8.0 / 32.0)
        _ = _keepAlive
    }

    // MARK: - TodayViewModel: Display strings

    @Test func vm_todayTotalDisplay() throws {
        let (vm, _keepAlive) = try makeVM()
        vm.logWater()
        vm.logWater()
        #expect(vm.todayTotalDisplay == "16")
        _ = _keepAlive
    }

    @Test func vm_dailyGoalDisplay() throws {
        let (vm, _) = try makeVM()
        #expect(vm.dailyGoalDisplay == "64")
    }

    // MARK: - TodayViewModel: Settings persistence

    @Test func vm_settingsPersistToDefaults() throws {
        let container = try TestHelpers.makeContainer()
        let defaults = TestHelpers.makeDefaults()
        let vm = TodayViewModel(modelContext: container.mainContext, defaults: defaults)

        vm.dailyGoal = 100.0
        vm.servingSize = 16.0

        #expect(defaults.double(forKey: WaterSettings.dailyGoalKey) == 100.0)
        #expect(defaults.double(forKey: WaterSettings.servingSizeKey) == 16.0)
    }

    @Test func vm_settingsLoadFromDefaults() throws {
        let container = try TestHelpers.makeContainer()
        let defaults = TestHelpers.makeDefaults()
        defaults.set(100.0, forKey: WaterSettings.dailyGoalKey)
        defaults.set(16.0, forKey: WaterSettings.servingSizeKey)

        let vm = TodayViewModel(modelContext: container.mainContext, defaults: defaults)
        #expect(vm.dailyGoal == 100.0)
        #expect(vm.servingSize == 16.0)
    }

    // MARK: - HistoryViewModel: Initial state

    @Test func history_initiallyEmpty() throws {
        let (hvm, _) = try makeHistoryVM()
        #expect(hvm.daySummaries.isEmpty)
    }

    // MARK: - HistoryViewModel: Day summaries

    @Test func history_groupsByDay() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        // Today: 2 entries
        context.insert(WaterEntry(amount: 8.0))
        context.insert(WaterEntry(amount: 12.0))
        // Yesterday: 1 entry
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        context.insert(WaterEntry(timestamp: yesterday, amount: 16.0))
        try context.save()

        let hvm = HistoryViewModel(modelContext: context)
        hvm.refresh()
        #expect(hvm.daySummaries.count == 2)
    }

    @Test func history_daySummaryTotal() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        context.insert(WaterEntry(amount: 8.0))
        context.insert(WaterEntry(amount: 12.0))
        context.insert(WaterEntry(amount: 4.0))
        try context.save()

        let hvm = HistoryViewModel(modelContext: context)
        hvm.refresh()
        #expect(hvm.daySummaries.count == 1)
        #expect(hvm.daySummaries.first?.total == 24.0)
    }

    @Test func history_daySummariesSortedNewestFirst() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: .now)!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        context.insert(WaterEntry(timestamp: threeDaysAgo, amount: 8.0))
        context.insert(WaterEntry(amount: 12.0)) // today
        context.insert(WaterEntry(timestamp: yesterday, amount: 16.0))
        try context.save()

        let hvm = HistoryViewModel(modelContext: context)
        hvm.refresh()
        #expect(hvm.daySummaries.count == 3)
        // Newest first
        let dates = hvm.daySummaries.map(\.date)
        #expect(dates[0] > dates[1])
        #expect(dates[1] > dates[2])
    }

    @Test func history_daySummaryEntriesSortedNewestFirst() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let morning = cal.date(byAdding: .hour, value: 8, to: today)!
        let afternoon = cal.date(byAdding: .hour, value: 14, to: today)!
        let evening = cal.date(byAdding: .hour, value: 20, to: today)!

        context.insert(WaterEntry(timestamp: afternoon, amount: 12.0))
        context.insert(WaterEntry(timestamp: morning, amount: 8.0))
        context.insert(WaterEntry(timestamp: evening, amount: 16.0))
        try context.save()

        let hvm = HistoryViewModel(modelContext: context)
        hvm.refresh()
        let entries = hvm.daySummaries.first!.entries
        #expect(entries.count == 3)
        // Newest first within day
        #expect(entries[0].timestamp >= entries[1].timestamp)
        #expect(entries[1].timestamp >= entries[2].timestamp)
    }

    @Test func history_daySummaryEntryCount() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        context.insert(WaterEntry(amount: 8.0))
        context.insert(WaterEntry(amount: 12.0))
        try context.save()

        let hvm = HistoryViewModel(modelContext: context)
        hvm.refresh()
        #expect(hvm.daySummaries.first?.entries.count == 2)
    }

    // MARK: - HistoryViewModel: Add entry

    @Test func history_addEntry() throws {
        let (hvm, _keepAlive) = try makeHistoryVM()
        let date = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        hvm.addEntry(amount: 16.0, timestamp: date)
        hvm.refresh()
        #expect(hvm.daySummaries.count == 1)
        #expect(hvm.daySummaries.first?.total == 16.0)
        _ = _keepAlive
    }

    @Test func history_addEntryDefaultsToNow() throws {
        let (hvm, _keepAlive) = try makeHistoryVM()
        let before = Date.now
        hvm.addEntry(amount: 8.0)
        let after = Date.now
        hvm.refresh()
        let entry = hvm.daySummaries.first?.entries.first
        #expect(entry != nil)
        #expect(entry!.timestamp >= before)
        #expect(entry!.timestamp <= after)
        _ = _keepAlive
    }

    // MARK: - HistoryViewModel: Delete entry

    @Test func history_deleteEntry() throws {
        let (hvm, _keepAlive) = try makeHistoryVM()
        hvm.addEntry(amount: 8.0)
        hvm.addEntry(amount: 12.0)
        hvm.refresh()
        #expect(hvm.daySummaries.first?.entries.count == 2)

        let entry = hvm.daySummaries.first!.entries.first!
        hvm.deleteEntry(entry)
        hvm.refresh()
        #expect(hvm.daySummaries.first?.entries.count == 1)
        _ = _keepAlive
    }

    @Test func history_deleteLastEntryRemovesDay() throws {
        let (hvm, _keepAlive) = try makeHistoryVM()
        hvm.addEntry(amount: 8.0)
        hvm.refresh()

        let entry = hvm.daySummaries.first!.entries.first!
        hvm.deleteEntry(entry)
        hvm.refresh()
        #expect(hvm.daySummaries.isEmpty)
        _ = _keepAlive
    }

    // MARK: - HistoryViewModel: Update entry

    @Test func history_updateEntryAmount() throws {
        let (hvm, _keepAlive) = try makeHistoryVM()
        hvm.addEntry(amount: 8.0)
        hvm.refresh()

        let entry = hvm.daySummaries.first!.entries.first!
        hvm.updateEntry(entry, amount: 16.0)
        hvm.refresh()
        #expect(hvm.daySummaries.first?.total == 16.0)
        _ = _keepAlive
    }

    @Test func history_updateEntryTimestamp() throws {
        let (hvm, _keepAlive) = try makeHistoryVM()
        hvm.addEntry(amount: 8.0)
        hvm.refresh()

        let entry = hvm.daySummaries.first!.entries.first!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        hvm.updateEntry(entry, timestamp: yesterday)
        hvm.refresh()
        // Entry moved to a different day, so now we have 1 summary for yesterday
        #expect(hvm.daySummaries.count == 1)
        #expect(hvm.daySummaries.first?.entries.first?.timestamp == yesterday)
        _ = _keepAlive
    }

    // MARK: - Helpers

    /// Returns (TodayViewModel, ModelContainer). The container MUST be kept alive
    /// for the test's duration — ModelContext holds a weak reference to it.
    private func makeVM() throws -> (TodayViewModel, ModelContainer) {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext, defaults: TestHelpers.makeDefaults())
        return (vm, container)
    }

    /// Returns (HistoryViewModel, ModelContainer). The container MUST be kept alive.
    private func makeHistoryVM() throws -> (HistoryViewModel, ModelContainer) {
        let container = try TestHelpers.makeContainer()
        let hvm = HistoryViewModel(modelContext: container.mainContext)
        return (hvm, container)
    }
}
