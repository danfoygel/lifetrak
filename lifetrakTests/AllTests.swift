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

    // MARK: - Helpers

    /// Returns (ViewModel, ModelContainer). The container MUST be kept alive
    /// for the test's duration — ModelContext holds a weak reference to it.
    private func makeVM() throws -> (TodayViewModel, ModelContainer) {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext, defaults: TestHelpers.makeDefaults())
        return (vm, container)
    }
}
