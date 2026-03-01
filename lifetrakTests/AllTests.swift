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

    // MARK: - TodayViewModel: Weekly data

    @Test func vm_weeklyDataHasSevenDays() throws {
        let (vm, _) = try makeVM()
        #expect(vm.weeklyData.count == 7)
    }

    @Test func vm_weeklyDataIncludesToday() throws {
        let (vm, _keepAlive) = try makeVM()
        vm.logWater()
        #expect(vm.weeklyData.last?.total == 8.0)
        _ = _keepAlive
    }

    @Test func vm_weeklyDataIncludesPastDays() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        // Add entries for yesterday and 2 days ago
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        context.insert(WaterEntry(timestamp: yesterday, amount: 32.0))
        context.insert(WaterEntry(timestamp: twoDaysAgo, amount: 16.0))
        try context.save()

        let vm = TodayViewModel(modelContext: context, defaults: TestHelpers.makeDefaults())
        // weeklyData is sorted oldest→newest (for chart display)
        // Last entry = today (0), second-to-last = yesterday (32), third-to-last = 2 days ago (16)
        #expect(vm.weeklyData[vm.weeklyData.count - 1].total == 0.0)  // today
        #expect(vm.weeklyData[vm.weeklyData.count - 2].total == 32.0) // yesterday
        #expect(vm.weeklyData[vm.weeklyData.count - 3].total == 16.0) // 2 days ago
    }

    @Test func vm_weeklyDataExcludesOlderThan7Days() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: .now)!
        context.insert(WaterEntry(timestamp: eightDaysAgo, amount: 99.0))
        try context.save()

        let vm = TodayViewModel(modelContext: context, defaults: TestHelpers.makeDefaults())
        let totalAcrossWeek = vm.weeklyData.reduce(0.0) { $0 + $1.total }
        #expect(totalAcrossWeek == 0.0)
    }

    // MARK: - TodayViewModel: Streak

    @Test func vm_streakZeroWhenNoEntries() throws {
        let (vm, _) = try makeVM()
        #expect(vm.currentStreak == 0)
    }

    @Test func vm_streakOneWhenGoalMetToday() throws {
        let (vm, _keepAlive) = try makeVM()
        for _ in 0..<8 { vm.logWater() } // 8 × 8 = 64 oz = goal
        #expect(vm.currentStreak == 1)
        _ = _keepAlive
    }

    @Test func vm_streakCountsConsecutiveDays() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let cal = Calendar.current
        // Today: meet goal
        context.insert(WaterEntry(amount: 64.0))
        // Yesterday: meet goal
        let yesterday = cal.date(byAdding: .day, value: -1, to: .now)!
        context.insert(WaterEntry(timestamp: yesterday, amount: 64.0))
        // 2 days ago: meet goal
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: .now)!
        context.insert(WaterEntry(timestamp: twoDaysAgo, amount: 64.0))
        try context.save()

        let vm = TodayViewModel(modelContext: context, defaults: TestHelpers.makeDefaults())
        #expect(vm.currentStreak == 3)
    }

    @Test func vm_streakBreaksOnMissedDay() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let cal = Calendar.current
        // Today: meet goal
        context.insert(WaterEntry(amount: 64.0))
        // Yesterday: missed (no entries)
        // 2 days ago: meet goal
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: .now)!
        context.insert(WaterEntry(timestamp: twoDaysAgo, amount: 64.0))
        try context.save()

        let vm = TodayViewModel(modelContext: context, defaults: TestHelpers.makeDefaults())
        #expect(vm.currentStreak == 1) // only today counts
    }

    @Test func vm_streakStartsFromYesterdayIfTodayNotMet() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let cal = Calendar.current
        // Today: not met (only 8 oz)
        context.insert(WaterEntry(amount: 8.0))
        // Yesterday: met
        let yesterday = cal.date(byAdding: .day, value: -1, to: .now)!
        context.insert(WaterEntry(timestamp: yesterday, amount: 64.0))
        // 2 days ago: met
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: .now)!
        context.insert(WaterEntry(timestamp: twoDaysAgo, amount: 64.0))
        try context.save()

        let vm = TodayViewModel(modelContext: context, defaults: TestHelpers.makeDefaults())
        // Today not met, but yesterday and day before were — streak = 2
        #expect(vm.currentStreak == 2)
    }

    // MARK: - Date edge cases

    @Test func vm_entryAtExactMidnightBelongsToThatDay() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let cal = Calendar.current

        // Insert entry at exactly midnight (start of today)
        let midnight = cal.startOfDay(for: .now)
        context.insert(WaterEntry(timestamp: midnight, amount: 8.0))
        try context.save()

        let vm = TodayViewModel(modelContext: context, defaults: TestHelpers.makeDefaults())
        #expect(vm.todayTotal == 8.0)
        #expect(vm.todayEntries.count == 1)
    }

    @Test func vm_entryOneSecondBeforeMidnightBelongsToYesterday() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let cal = Calendar.current

        // Insert entry at 23:59:59 yesterday
        let startOfToday = cal.startOfDay(for: .now)
        let oneSecondBefore = startOfToday.addingTimeInterval(-1)
        context.insert(WaterEntry(timestamp: oneSecondBefore, amount: 8.0))
        try context.save()

        let vm = TodayViewModel(modelContext: context, defaults: TestHelpers.makeDefaults())
        #expect(vm.todayTotal == 0.0)
        #expect(vm.todayEntries.isEmpty)
    }

    @Test func history_entryAtExactMidnightGroupedCorrectly() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let cal = Calendar.current

        let startOfToday = cal.startOfDay(for: .now)
        let startOfYesterday = cal.date(byAdding: .day, value: -1, to: startOfToday)!

        // Entry at exact midnight today and exact midnight yesterday
        context.insert(WaterEntry(timestamp: startOfToday, amount: 8.0))
        context.insert(WaterEntry(timestamp: startOfYesterday, amount: 12.0))
        try context.save()

        let hvm = HistoryViewModel(modelContext: context)
        hvm.refresh()
        #expect(hvm.daySummaries.count == 2)
        // Newest first: today then yesterday
        #expect(hvm.daySummaries[0].total == 8.0)
        #expect(hvm.daySummaries[1].total == 12.0)
    }

    @Test func vm_streakAcrossMidnightBoundary() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let cal = Calendar.current

        let startOfToday = cal.startOfDay(for: .now)
        // Today at midnight exactly: meets goal
        context.insert(WaterEntry(timestamp: startOfToday, amount: 64.0))
        // Yesterday at 23:59:59: meets goal for yesterday
        let startOfYesterday = cal.date(byAdding: .day, value: -1, to: startOfToday)!
        let lastSecondYesterday = startOfToday.addingTimeInterval(-1)
        context.insert(WaterEntry(timestamp: lastSecondYesterday, amount: 64.0))
        // 2 days ago at start of day: meets goal
        let startOfTwoDaysAgo = cal.date(byAdding: .day, value: -2, to: startOfToday)!
        context.insert(WaterEntry(timestamp: startOfTwoDaysAgo, amount: 64.0))
        try context.save()

        let vm = TodayViewModel(modelContext: context, defaults: TestHelpers.makeDefaults())
        #expect(vm.currentStreak == 3)
    }

    @Test func vm_weeklyDataSpanningMonthBoundary() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let cal = Calendar.current

        // Add entries for each of the past 7 days with increasing amounts
        let startOfToday = cal.startOfDay(for: .now)
        for daysBack in 0..<7 {
            let date = cal.date(byAdding: .day, value: -daysBack, to: startOfToday)!
            context.insert(WaterEntry(timestamp: date, amount: Double((daysBack + 1) * 8)))
        }
        try context.save()

        let vm = TodayViewModel(modelContext: context, defaults: TestHelpers.makeDefaults())
        #expect(vm.weeklyData.count == 7)
        // All 7 days should have non-zero totals
        for day in vm.weeklyData {
            #expect(day.total > 0)
        }
    }

    @Test func vm_todayFilterExcludesEntryAtStartOfTomorrow() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let cal = Calendar.current

        // Insert entry at start of tomorrow (should NOT appear in today)
        let startOfToday = cal.startOfDay(for: .now)
        let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday)!
        context.insert(WaterEntry(timestamp: startOfTomorrow, amount: 99.0))
        // Also insert today entry for comparison
        context.insert(WaterEntry(timestamp: startOfToday, amount: 8.0))
        try context.save()

        let vm = TodayViewModel(modelContext: context, defaults: TestHelpers.makeDefaults())
        #expect(vm.todayTotal == 8.0)
        #expect(vm.todayEntries.count == 1)
    }

    // MARK: - Validation & defensive tests

    @Test func vm_progressIsZeroWhenDailyGoalIsZero() throws {
        let container = try TestHelpers.makeContainer()
        let defaults = TestHelpers.makeDefaults()
        defaults.set(0.0, forKey: WaterSettings.dailyGoalKey)

        // dailyGoal init guard: storedGoal > 0 ? storedGoal : default
        // So setting 0 should fall back to default (64)
        let vm = TodayViewModel(modelContext: container.mainContext, defaults: defaults)
        #expect(vm.dailyGoal == WaterSettings.defaultDailyGoal)
        #expect(vm.progress == 0.0)
    }

    @Test func vm_progressGuardsAgainstManualZeroGoal() throws {
        let (vm, _keepAlive) = try makeVM()
        vm.dailyGoal = 0.0
        vm.logWater()
        // progress computed property has guard: dailyGoal > 0 else return 0.0
        #expect(vm.progress == 0.0)
        _ = _keepAlive
    }

    @Test func vm_logWaterWithZeroServingSize() throws {
        let (vm, _keepAlive) = try makeVM()
        vm.servingSize = 0.0
        vm.logWater()
        // Should create an entry with amount 0
        #expect(vm.todayTotal == 0.0)
        #expect(vm.todayEntries.count == 1)
        #expect(vm.todayEntries.first?.amount == 0.0)
        _ = _keepAlive
    }

    @Test func vm_logWaterWithNegativeServingSize() throws {
        let (vm, _keepAlive) = try makeVM()
        vm.servingSize = -5.0
        vm.logWater()
        // Currently no validation — records negative amount
        #expect(vm.todayTotal == -5.0)
        #expect(vm.todayEntries.count == 1)
        _ = _keepAlive
    }

    @Test func vm_goalMetWhenDailyGoalIsZero() throws {
        let (vm, _keepAlive) = try makeVM()
        vm.dailyGoal = 0.0
        // todayTotal (0) >= dailyGoal (0) is true
        #expect(vm.goalMet == true)
        _ = _keepAlive
    }

    @Test func vm_veryLargeAmount() throws {
        let (vm, _keepAlive) = try makeVM()
        vm.servingSize = 1_000_000.0
        vm.logWater()
        #expect(vm.todayTotal == 1_000_000.0)
        #expect(vm.progress == 1.0) // capped at 1.0
        _ = _keepAlive
    }

    @Test func vm_fractionalAmountDisplayFormat() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let defaults = TestHelpers.makeDefaults()

        let vm = TodayViewModel(modelContext: context, defaults: defaults)
        vm.servingSize = 8.5
        vm.logWater()
        // 8.5 is not a whole number, so it should format with one decimal
        #expect(vm.todayTotalDisplay == "8.5")
    }

    @Test func vm_negativeGoalInDefaultsFallsBackToDefault() throws {
        let container = try TestHelpers.makeContainer()
        let defaults = TestHelpers.makeDefaults()
        defaults.set(-10.0, forKey: WaterSettings.dailyGoalKey)
        defaults.set(-5.0, forKey: WaterSettings.servingSizeKey)

        // Negative values fail the > 0 check, should fall back to defaults
        let vm = TodayViewModel(modelContext: container.mainContext, defaults: defaults)
        #expect(vm.dailyGoal == WaterSettings.defaultDailyGoal)
        #expect(vm.servingSize == WaterSettings.defaultServingSize)
    }

    @Test func history_addEntryWithZeroAmount() throws {
        let (hvm, _keepAlive) = try makeHistoryVM()
        hvm.addEntry(amount: 0.0)
        hvm.refresh()
        #expect(hvm.daySummaries.count == 1)
        #expect(hvm.daySummaries.first?.total == 0.0)
        #expect(hvm.daySummaries.first?.entries.count == 1)
        _ = _keepAlive
    }

    @Test func history_addEntryWithNegativeAmount() throws {
        let (hvm, _keepAlive) = try makeHistoryVM()
        hvm.addEntry(amount: -8.0)
        hvm.refresh()
        #expect(hvm.daySummaries.count == 1)
        #expect(hvm.daySummaries.first?.total == -8.0)
        _ = _keepAlive
    }

    // MARK: - Settings round-trip persistence

    @Test func vm_settingsFullRoundTrip() throws {
        let container = try TestHelpers.makeContainer()
        let defaults = TestHelpers.makeDefaults()

        // Create first VM and change settings
        let vm1 = TodayViewModel(modelContext: container.mainContext, defaults: defaults)
        vm1.dailyGoal = 128.0
        vm1.servingSize = 16.0

        // Create a brand new VM with the same defaults — settings should persist
        let vm2 = TodayViewModel(modelContext: container.mainContext, defaults: defaults)
        #expect(vm2.dailyGoal == 128.0)
        #expect(vm2.servingSize == 16.0)
    }

    @Test func vm_settingsRoundTripPreservesNonDefaultValues() throws {
        let container = try TestHelpers.makeContainer()
        let defaults = TestHelpers.makeDefaults()

        // Set unusual values
        let vm1 = TodayViewModel(modelContext: container.mainContext, defaults: defaults)
        vm1.dailyGoal = 99.5
        vm1.servingSize = 3.3

        // New VM loads the same fractional values
        let vm2 = TodayViewModel(modelContext: container.mainContext, defaults: defaults)
        #expect(vm2.dailyGoal == 99.5)
        #expect(vm2.servingSize == 3.3)
    }

    @Test func vm_settingsRoundTripMultipleChanges() throws {
        let container = try TestHelpers.makeContainer()
        let defaults = TestHelpers.makeDefaults()

        // Change settings multiple times — only the last value should persist
        let vm1 = TodayViewModel(modelContext: container.mainContext, defaults: defaults)
        vm1.dailyGoal = 32.0
        vm1.dailyGoal = 48.0
        vm1.dailyGoal = 100.0
        vm1.servingSize = 4.0
        vm1.servingSize = 12.0

        let vm2 = TodayViewModel(modelContext: container.mainContext, defaults: defaults)
        #expect(vm2.dailyGoal == 100.0)
        #expect(vm2.servingSize == 12.0)
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
