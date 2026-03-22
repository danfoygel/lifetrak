import Foundation
import Testing
import SwiftData
@testable import lifetrak

/// All SwiftData tests in a single serialized suite to prevent concurrent
/// ModelContainer creation, which crashes on iOS 26 beta.
@MainActor
@Suite(.serialized)
struct AllTests {

    // =========================================================================
    // MARK: - Activity Model
    // =========================================================================

    @Test func activity_create() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = Activity(name: "Drink Water", emoji: "\u{1F4A7}", quantityUnit: "oz")
        context.insert(activity)
        try context.save()

        let activities = try context.fetch(FetchDescriptor<Activity>())
        #expect(activities.count == 1)
        #expect(activities.first?.name == "Drink Water")
        #expect(activities.first?.emoji == "\u{1F4A7}")
        #expect(activities.first?.quantityUnit == "oz")
    }

    @Test func activity_defaults() throws {
        let activity = Activity(name: "Test", emoji: "T")
        #expect(activity.quantityUnit == nil)
        #expect(activity.tracksDuration == false)
        #expect(activity.defaultQuantity == nil)
        #expect(activity.sortOrder == 0)
    }

    @Test func activity_dataSourceManual() throws {
        let activity = Activity(name: "Water", emoji: "W", source: .manual)
        #expect(activity.source == .manual)
    }

    @Test func activity_dataSourceHealthKit() throws {
        let activity = Activity(name: "Sleep", emoji: "S", source: .healthKit("sleepAnalysis"))
        #expect(activity.source == .healthKit("sleepAnalysis"))
    }

    @Test func activity_withDuration() throws {
        let activity = Activity(name: "Meditation", emoji: "M", tracksDuration: true)
        #expect(activity.tracksDuration == true)
    }

    // =========================================================================
    // MARK: - Event Model
    // =========================================================================

    @Test func event_create() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        let event = Event(activity: activity, quantity: 8.0)
        context.insert(event)
        try context.save()

        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.count == 1)
        #expect(events.first?.quantity == 8.0)
        #expect(events.first?.activity?.name == "Drink Water")
    }

    @Test func event_createWithCustomTimestamp() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        let date = Date(timeIntervalSince1970: 1_000_000)
        let event = Event(activity: activity, timestamp: date, quantity: 12.0)
        context.insert(event)
        try context.save()

        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.first?.timestamp == date)
        #expect(events.first?.quantity == 12.0)
    }

    @Test func event_defaultTimestampIsNow() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        let before = Date.now
        let event = Event(activity: activity, quantity: 8.0)
        let after = Date.now
        #expect(event.timestamp >= before)
        #expect(event.timestamp <= after)
    }

    @Test func event_delete() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        let event = Event(activity: activity, quantity: 8.0)
        context.insert(event)
        try context.save()
        context.delete(event)
        try context.save()

        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.isEmpty)
    }

    @Test func event_durationComputed() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = Activity(name: "Meditation", emoji: "M", tracksDuration: true, source: .manual)
        context.insert(activity)

        let start = Date(timeIntervalSince1970: 1000)
        let end = Date(timeIntervalSince1970: 2200) // 1200 seconds = 20 min
        let event = Event(activity: activity, timestamp: start, endTimestamp: end)
        context.insert(event)

        #expect(event.duration == 1200)
    }

    @Test func event_durationNilWithoutEndTimestamp() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        let event = Event(activity: activity, quantity: 8.0)
        context.insert(event)

        #expect(event.duration == nil)
    }

    @Test func event_fetchToday() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        context.insert(Event(activity: activity, quantity: 8.0))
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        context.insert(Event(activity: activity, timestamp: yesterday, quantity: 16.0))
        try context.save()

        let startOfDay = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.timestamp >= startOfDay && $0.timestamp < tomorrow }
        )

        let todayEvents = try context.fetch(descriptor)
        #expect(todayEvents.count == 1)
        #expect(todayEvents.first?.quantity == 8.0)
    }

    @Test func event_sumToday() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        context.insert(Event(activity: activity, quantity: 8.0))
        context.insert(Event(activity: activity, quantity: 12.0))
        context.insert(Event(activity: activity, quantity: 8.0))
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        context.insert(Event(activity: activity, timestamp: yesterday, quantity: 99.0))
        try context.save()

        let startOfDay = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.timestamp >= startOfDay && $0.timestamp < tomorrow }
        )

        let todayEvents = try context.fetch(descriptor)
        let total = todayEvents.reduce(0.0) { $0 + ($1.quantity ?? 0) }
        #expect(total == 28.0)
    }

    @Test func event_multiplePersist() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        for amount in [8.0, 16.0, 12.0, 8.0, 24.0] {
            context.insert(Event(activity: activity, quantity: amount))
        }
        try context.save()

        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.count == 5)
    }

    @Test func event_update() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        let event = Event(activity: activity, quantity: 8.0)
        context.insert(event)
        try context.save()

        event.quantity = 16.0
        try context.save()

        let events = try context.fetch(FetchDescriptor<Event>())
        #expect(events.first?.quantity == 16.0)
    }

    // =========================================================================
    // MARK: - Routine & Goal Model
    // =========================================================================

    @Test func routine_create() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let routine = Routine(name: "Standard", isDefault: true)
        context.insert(routine)
        try context.save()

        let routines = try context.fetch(FetchDescriptor<Routine>())
        #expect(routines.count == 1)
        #expect(routines.first?.name == "Standard")
        #expect(routines.first?.isDefault == true)
        #expect(routines.first?.isSnapshot == false)
    }

    @Test func routine_withGoals() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        let routine = Routine(name: "Standard", isDefault: true)
        context.insert(routine)

        let goal = Goal(routine: routine, activity: activity, period: .daily, targetQuantity: 64.0)
        context.insert(goal)
        try context.save()

        let routines = try context.fetch(FetchDescriptor<Routine>())
        #expect(routines.first?.goals.count == 1)
        #expect(routines.first?.goals.first?.targetQuantity == 64.0)
        #expect(routines.first?.goals.first?.period == .daily)
    }

    @Test func goal_frequencyTarget() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = Activity(name: "Bright Light", emoji: "S", tracksDuration: true, source: .manual)
        context.insert(activity)
        let routine = Routine(name: "Standard", isDefault: true)
        context.insert(routine)

        let goal = Goal(
            routine: routine,
            activity: activity,
            period: .weekly,
            targetDuration: 1200,
            targetFrequency: 5
        )
        context.insert(goal)
        try context.save()

        #expect(goal.targetDuration == 1200)
        #expect(goal.targetFrequency == 5)
        #expect(goal.period == .weekly)
        #expect(goal.targetQuantity == nil)
    }

    @Test func routine_createSnapshot() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        let routine = Routine(name: "Travel", isDefault: false)
        context.insert(routine)

        let goal = Goal(routine: routine, activity: activity, period: .daily, targetQuantity: 48.0)
        context.insert(goal)
        try context.save()

        let snapshot = routine.createSnapshot()
        context.insert(snapshot)
        try context.save()

        #expect(snapshot.name == "Travel")
        #expect(snapshot.isSnapshot == true)
        #expect(snapshot.isDefault == false)
        #expect(snapshot.goals.count == 1)
        #expect(snapshot.goals.first?.targetQuantity == 48.0)
        #expect(snapshot.goals.first?.activity?.name == "Drink Water")

        // Original and snapshot are independent
        routine.goals.first?.targetQuantity = 32.0
        #expect(snapshot.goals.first?.targetQuantity == 48.0)
    }

    // =========================================================================
    // MARK: - RoutineSchedule Model
    // =========================================================================

    @Test func routineSchedule_create() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let routine = Routine(name: "Travel", isDefault: false)
        context.insert(routine)

        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        let end = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 5))!
        let schedule = RoutineSchedule(routine: routine, startDate: start, endDate: end)
        context.insert(schedule)
        try context.save()

        let schedules = try context.fetch(FetchDescriptor<RoutineSchedule>())
        #expect(schedules.count == 1)
        #expect(schedules.first?.routine?.name == "Travel")
    }

    @Test func routineSchedule_resolvesForDate() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let defaultRoutine = Routine(name: "Standard", isDefault: true)
        let travelRoutine = Routine(name: "Travel", isDefault: false)
        context.insert(defaultRoutine)
        context.insert(travelRoutine)

        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        let end = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 5))!
        let schedule = RoutineSchedule(routine: travelRoutine, startDate: start, endDate: end)
        context.insert(schedule)
        try context.save()

        // May 3 should resolve to Travel
        let may3 = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 3))!
        let scheduleDescriptor = FetchDescriptor<RoutineSchedule>(
            predicate: #Predicate<RoutineSchedule> { s in
                s.startDate <= may3 && s.endDate >= may3
            }
        )
        let matches = try context.fetch(scheduleDescriptor)
        #expect(matches.count == 1)
        #expect(matches.first?.routine?.name == "Travel")

        // May 10 should have no schedule (falls back to default)
        let may10 = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 10))!
        let noMatchDescriptor = FetchDescriptor<RoutineSchedule>(
            predicate: #Predicate<RoutineSchedule> { s in
                s.startDate <= may10 && s.endDate >= may10
            }
        )
        let noMatches = try context.fetch(noMatchDescriptor)
        #expect(noMatches.isEmpty)
    }

    // =========================================================================
    // MARK: - TodayViewModel: Basic
    // =========================================================================

    @Test func todayVM_initialState() throws {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        #expect(vm.todayTotal == 0.0)
        #expect(vm.progress == 0.0)
        #expect(vm.goalMet == false)
        #expect(vm.todayEntries.isEmpty)
    }

    @Test func todayVM_autoCreatesDefaults() throws {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        #expect(vm.waterActivity != nil)
        #expect(vm.waterActivity?.name == "Drink Water")
        #expect(vm.activeRoutine != nil)
        #expect(vm.activeRoutine?.name == "Standard")
        #expect(vm.dailyGoal == 64.0)
        #expect(vm.servingSize == 8.0)
    }

    @Test func todayVM_logWater() throws {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        vm.logWater()

        #expect(vm.todayEntries.count == 1)
        #expect(vm.todayTotal == 8.0)
    }

    @Test func todayVM_logWaterMultiple() throws {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        vm.logWater()
        vm.logWater()
        vm.logWater()

        #expect(vm.todayEntries.count == 3)
        #expect(vm.todayTotal == 24.0)
    }

    @Test func todayVM_progress() throws {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        // Default: 8 oz serving, 64 oz goal
        vm.logWater() // 8/64 = 0.125
        #expect(vm.progress == 0.125)
    }

    @Test func todayVM_progressCapsAtOne() throws {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        // Log 9 servings = 72 oz, goal is 64
        for _ in 0..<9 {
            vm.logWater()
        }
        #expect(vm.progress == 1.0)
        #expect(vm.todayTotal == 72.0)
    }

    @Test func todayVM_goalMet() throws {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        // Log 8 servings = 64 oz = goal
        for _ in 0..<8 {
            vm.logWater()
        }
        #expect(vm.goalMet == true)
    }

    @Test func todayVM_excludesYesterday() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        TestHelpers.makeDefaultRoutine(context: context, waterActivity: activity)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let event = Event(activity: activity, timestamp: yesterday, quantity: 99.0)
        context.insert(event)
        try context.save()

        let vm = TodayViewModel(modelContext: context)
        #expect(vm.todayTotal == 0.0)
        #expect(vm.todayEntries.isEmpty)
    }

    @Test func todayVM_customDailyGoal() throws {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        vm.updateDailyGoal(100.0)
        #expect(vm.dailyGoal == 100.0)

        vm.logWater() // 8 oz
        #expect(vm.progress == 0.08) // 8/100
    }

    @Test func todayVM_customServingSize() throws {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        vm.updateServingSize(16.0)
        #expect(vm.servingSize == 16.0)

        vm.logWater()
        #expect(vm.todayTotal == 16.0)
    }

    @Test func todayVM_displayString() throws {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        #expect(vm.todayTotalDisplay == "0")
        vm.logWater()
        #expect(vm.todayTotalDisplay == "8")
    }

    @Test func todayVM_dailyGoalDisplay() throws {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        #expect(vm.dailyGoalDisplay == "64")
    }

    @Test func todayVM_progressZeroWhenGoalIsZero() throws {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        vm.updateDailyGoal(0)
        vm.logWater()
        #expect(vm.progress == 0.0)
    }

    // =========================================================================
    // MARK: - TodayViewModel: Weekly Data
    // =========================================================================

    @Test func todayVM_weeklyDataAlwaysSeven() throws {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        #expect(vm.weeklyData.count == 7)
    }

    @Test func todayVM_weeklyDataIncludesToday() throws {
        let container = try TestHelpers.makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        vm.logWater()

        let today = Calendar.current.startOfDay(for: .now)
        let todayData = vm.weeklyData.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        #expect(todayData?.total == 8.0)
    }

    @Test func todayVM_weeklyDataIncludesPastDays() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        TestHelpers.makeDefaultRoutine(context: context, waterActivity: activity)

        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: .now)!
        context.insert(Event(activity: activity, timestamp: threeDaysAgo, quantity: 20.0))
        try context.save()

        let vm = TodayViewModel(modelContext: context)

        let dayData = vm.weeklyData.first {
            Calendar.current.isDate($0.date, inSameDayAs: Calendar.current.startOfDay(for: threeDaysAgo))
        }
        #expect(dayData?.total == 20.0)
    }

    @Test func todayVM_weeklyDataExcludesOlderThan7Days() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        TestHelpers.makeDefaultRoutine(context: context, waterActivity: activity)

        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: .now)!
        context.insert(Event(activity: activity, timestamp: eightDaysAgo, quantity: 50.0))
        try context.save()

        let vm = TodayViewModel(modelContext: context)

        let allTotals = vm.weeklyData.map(\.total)
        #expect(!allTotals.contains(50.0))
    }

    // =========================================================================
    // MARK: - TodayViewModel: Streak
    // =========================================================================

    private struct StreakCase: CustomTestStringConvertible, Sendable {
        let daysMetGoal: [Int]   // days-ago offsets where goal (64 oz) was met
        let expected: Int
        var testDescription: String
    }

    @Test(arguments: [
        StreakCase(daysMetGoal: [],          expected: 0, testDescription: "noEntries"),
        StreakCase(daysMetGoal: [0],         expected: 1, testDescription: "todayOnly"),
        StreakCase(daysMetGoal: [0, 1, 2],  expected: 3, testDescription: "threeConsecutive"),
        StreakCase(daysMetGoal: [0, 2],      expected: 1, testDescription: "skipsYesterday"),
        StreakCase(daysMetGoal: [1, 2],      expected: 2, testDescription: "onlyPriorDays"),
    ])
    func todayVM_streak(_ c: StreakCase) throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        TestHelpers.makeDefaultRoutine(context: context, waterActivity: activity)

        for daysAgo in c.daysMetGoal {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
            context.insert(Event(activity: activity, timestamp: date, quantity: 64.0))
        }
        try context.save()

        let vm = TodayViewModel(modelContext: context)
        #expect(vm.currentStreak == c.expected)
    }

    // =========================================================================
    // MARK: - TodayViewModel: Date Edge Cases
    // =========================================================================

    @Test func todayVM_entryAtExactMidnightBelongsToThatDay() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        TestHelpers.makeDefaultRoutine(context: context, waterActivity: activity)

        let midnight = Calendar.current.startOfDay(for: .now)
        context.insert(Event(activity: activity, timestamp: midnight, quantity: 8.0))
        try context.save()

        let vm = TodayViewModel(modelContext: context)
        #expect(vm.todayTotal == 8.0)
    }

    @Test func todayVM_entryBeforeMidnightExcluded() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        TestHelpers.makeDefaultRoutine(context: context, waterActivity: activity)

        let midnight = Calendar.current.startOfDay(for: .now)
        let justBefore = midnight.addingTimeInterval(-1)
        context.insert(Event(activity: activity, timestamp: justBefore, quantity: 8.0))
        try context.save()

        let vm = TodayViewModel(modelContext: context)
        #expect(vm.todayTotal == 0.0)
    }

    // =========================================================================
    // MARK: - TodayViewModel: Settings Persistence
    // =========================================================================

    @Test func todayVM_settingsRoundTrip() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        // First VM: change settings
        let vm1 = TodayViewModel(modelContext: context)
        vm1.updateDailyGoal(100.0)
        vm1.updateServingSize(16.0)

        // Second VM: should load the changed settings
        let vm2 = TodayViewModel(modelContext: context)
        #expect(vm2.dailyGoal == 100.0)
        #expect(vm2.servingSize == 16.0)
    }

    @Test func todayVM_settingsPreservesFractionalValues() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let vm1 = TodayViewModel(modelContext: context)
        vm1.updateDailyGoal(33.3)
        vm1.updateServingSize(6.5)

        let vm2 = TodayViewModel(modelContext: context)
        #expect(vm2.dailyGoal == 33.3)
        #expect(vm2.servingSize == 6.5)
    }

    // =========================================================================
    // MARK: - HistoryViewModel: Basic
    // =========================================================================

    @Test func historyVM_initiallyEmpty() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        // Create water activity so the VM can query for it
        TestHelpers.makeWaterActivity(context: context)
        try context.save()

        let vm = HistoryViewModel(modelContext: context)
        #expect(vm.daySummaries.isEmpty)
    }

    @Test func historyVM_groupsByDay() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)

        let today = Date.now
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        context.insert(Event(activity: activity, timestamp: today, quantity: 8.0))
        context.insert(Event(activity: activity, timestamp: yesterday, quantity: 16.0))
        try context.save()

        let vm = HistoryViewModel(modelContext: context)
        #expect(vm.daySummaries.count == 2)
    }

    @Test func historyVM_daySummaryTotal() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)

        context.insert(Event(activity: activity, quantity: 8.0))
        context.insert(Event(activity: activity, quantity: 12.0))
        context.insert(Event(activity: activity, quantity: 4.0))
        try context.save()

        let vm = HistoryViewModel(modelContext: context)
        #expect(vm.daySummaries.first?.total == 24.0)
    }

    @Test func historyVM_sortedNewestFirst() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)

        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!

        context.insert(Event(activity: activity, timestamp: twoDaysAgo, quantity: 1.0))
        context.insert(Event(activity: activity, timestamp: yesterday, quantity: 2.0))
        context.insert(Event(activity: activity, quantity: 3.0))
        try context.save()

        let vm = HistoryViewModel(modelContext: context)
        #expect(vm.daySummaries.count == 3)
        #expect(vm.daySummaries[0].total == 3.0) // today
        #expect(vm.daySummaries[1].total == 2.0) // yesterday
        #expect(vm.daySummaries[2].total == 1.0) // 2 days ago
    }

    @Test func historyVM_entriesWithinDaySortedNewestFirst() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let morning = cal.date(byAdding: .hour, value: 8, to: today)!
        let noon = cal.date(byAdding: .hour, value: 12, to: today)!

        context.insert(Event(activity: activity, timestamp: morning, quantity: 8.0))
        context.insert(Event(activity: activity, timestamp: noon, quantity: 16.0))
        try context.save()

        let vm = HistoryViewModel(modelContext: context)
        let entries = vm.daySummaries.first?.entries ?? []
        #expect(entries.count == 2)
        #expect(entries[0].quantity == 16.0) // noon first (newest)
        #expect(entries[1].quantity == 8.0)  // morning second
    }

    @Test func historyVM_addEntry() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        TestHelpers.makeWaterActivity(context: context)
        try context.save()

        let vm = HistoryViewModel(modelContext: context)
        vm.addEntry(amount: 12.0)

        #expect(vm.daySummaries.count == 1)
        #expect(vm.daySummaries.first?.total == 12.0)
    }

    @Test func historyVM_addEntryWithCustomDate() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        TestHelpers.makeWaterActivity(context: context)
        try context.save()

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let vm = HistoryViewModel(modelContext: context)
        vm.addEntry(amount: 10.0, timestamp: yesterday)

        #expect(vm.daySummaries.count == 1)
        #expect(vm.daySummaries.first?.total == 10.0)
    }

    @Test func historyVM_deleteEntry() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        TestHelpers.makeWaterActivity(context: context)
        try context.save()

        let vm = HistoryViewModel(modelContext: context)
        vm.addEntry(amount: 8.0)
        vm.addEntry(amount: 12.0)

        let entry = vm.daySummaries.first!.entries.first!
        vm.deleteEntry(entry)

        #expect(vm.daySummaries.first?.entries.count == 1)
    }

    @Test func historyVM_deleteLastEntryRemovesDay() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        TestHelpers.makeWaterActivity(context: context)
        try context.save()

        let vm = HistoryViewModel(modelContext: context)
        vm.addEntry(amount: 8.0)

        let entry = vm.daySummaries.first!.entries.first!
        vm.deleteEntry(entry)

        #expect(vm.daySummaries.isEmpty)
    }

    @Test func historyVM_updateEntryAmount() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        TestHelpers.makeWaterActivity(context: context)
        try context.save()

        let vm = HistoryViewModel(modelContext: context)
        vm.addEntry(amount: 8.0)

        let entry = vm.daySummaries.first!.entries.first!
        vm.updateEntry(entry, amount: 20.0)

        #expect(vm.daySummaries.first?.total == 20.0)
    }

    @Test func historyVM_updateEntryTimestamp() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        TestHelpers.makeWaterActivity(context: context)
        try context.save()

        let vm = HistoryViewModel(modelContext: context)
        vm.addEntry(amount: 8.0)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let entry = vm.daySummaries.first!.entries.first!
        vm.updateEntry(entry, timestamp: yesterday)

        // Entry moved to yesterday — today should be empty, yesterday should have it
        let todayStart = Calendar.current.startOfDay(for: .now)
        let yesterdayStart = Calendar.current.startOfDay(for: yesterday)
        let todaySummary = vm.daySummaries.first { Calendar.current.isDate($0.date, inSameDayAs: todayStart) }
        let yesterdaySummary = vm.daySummaries.first { Calendar.current.isDate($0.date, inSameDayAs: yesterdayStart) }
        #expect(todaySummary == nil)
        #expect(yesterdaySummary?.total == 8.0)
    }

    // =========================================================================
    // MARK: - SleepNight Model
    // =========================================================================

    @Test func sleepNight_timeInBed() {
        let night = SleepNight(
            date: .now,
            inBedInterval: DateInterval(start: .now.addingTimeInterval(-28800), duration: 28800),
            totalSleepDuration: 25200,
            stages: nil
        )
        #expect(night.timeInBed == 28800) // 8 hours
    }

    @Test func sleepNight_efficiency() {
        let night = SleepNight(
            date: .now,
            inBedInterval: DateInterval(start: .now.addingTimeInterval(-28800), duration: 28800),
            totalSleepDuration: 25200,
            stages: nil
        )
        #expect(night.efficiency == 25200.0 / 28800.0) // 87.5%
    }

    @Test func sleepNight_efficiencyZeroWhenNoTimeInBed() {
        let night = SleepNight(
            date: .now,
            inBedInterval: DateInterval(start: .now, duration: 0),
            totalSleepDuration: 0,
            stages: nil
        )
        #expect(night.efficiency == 0)
    }

    // =========================================================================
    // MARK: - TimeInterval Formatting
    // =========================================================================

    @Test func sleepFormatted_hoursAndMinutes() {
        let duration: TimeInterval = 7 * 3600 + 32 * 60
        #expect(duration.sleepFormatted == "7h 32m")
    }

    @Test func sleepFormatted_minutesOnly() {
        let duration: TimeInterval = 45 * 60
        #expect(duration.sleepFormatted == "45m")
    }

    @Test func sleepFormatted_zero() {
        let duration: TimeInterval = 0
        #expect(duration.sleepFormatted == "0m")
    }

    @Test func sleepFormatted_exactHours() {
        let duration: TimeInterval = 8 * 3600
        #expect(duration.sleepFormatted == "8h 0m")
    }

    // =========================================================================
    // MARK: - SleepAggregator
    // =========================================================================

    @Test func aggregator_emptyInput() {
        let result = SleepAggregator.aggregate([])
        #expect(result.isEmpty)
    }

    @Test func aggregator_singleNight() {
        let samples = [
            RawSleepSample(
                startDate: date(2026, 3, 1, 23, 0),
                endDate: date(2026, 3, 2, 7, 0),
                category: .asleepUnspecified
            )
        ]
        let result = SleepAggregator.aggregate(samples)
        #expect(result.count == 1)
        #expect(result.first?.totalSleepDuration == 28800.0)
    }

    @Test func aggregator_assignsToWakeUpDay() {
        let samples = [
            RawSleepSample(
                startDate: date(2026, 3, 1, 23, 0),
                endDate: date(2026, 3, 2, 7, 0),
                category: .asleepUnspecified
            )
        ]
        let result = SleepAggregator.aggregate(samples)
        let cal = Calendar.current
        let expectedDate = cal.startOfDay(for: date(2026, 3, 2, 7, 0))
        #expect(result.first?.date == expectedDate)
    }

    @Test func aggregator_aggregatesStages() {
        let samples = [
            RawSleepSample(startDate: date(2026, 3, 1, 23, 0), endDate: date(2026, 3, 2, 1, 0), category: .asleepCore),
            RawSleepSample(startDate: date(2026, 3, 2, 1, 0), endDate: date(2026, 3, 2, 2, 30), category: .asleepDeep),
            RawSleepSample(startDate: date(2026, 3, 2, 2, 30), endDate: date(2026, 3, 2, 4, 0), category: .asleepREM),
            RawSleepSample(startDate: date(2026, 3, 2, 4, 0), endDate: date(2026, 3, 2, 4, 15), category: .awake),
            RawSleepSample(startDate: date(2026, 3, 2, 4, 15), endDate: date(2026, 3, 2, 7, 0), category: .asleepCore),
        ]
        let result = SleepAggregator.aggregate(samples)
        #expect(result.count == 1)
        let stages = result.first!.stages!
        #expect(stages.core == 17100.0)  // 2h + 2h45m = 4h45m = 17100s
        #expect(stages.deep == 5400.0)   // 1h30m = 5400s
        #expect(stages.rem == 5400.0)    // 1h30m = 5400s
        #expect(stages.awake == 900.0)   // 15m = 900s
    }

    @Test func aggregator_noStagesWhenOnlyUnspecified() {
        let samples = [
            RawSleepSample(startDate: date(2026, 3, 1, 23, 0), endDate: date(2026, 3, 2, 7, 0), category: .asleepUnspecified)
        ]
        let result = SleepAggregator.aggregate(samples)
        #expect(result.first?.stages == nil)
    }

    @Test func aggregator_inBedDoesntCountAsSleep() {
        let samples = [
            RawSleepSample(startDate: date(2026, 3, 1, 22, 30), endDate: date(2026, 3, 1, 23, 0), category: .inBed),
            RawSleepSample(startDate: date(2026, 3, 1, 23, 0), endDate: date(2026, 3, 2, 7, 0), category: .asleepUnspecified),
        ]
        let result = SleepAggregator.aggregate(samples)
        #expect(result.first?.totalSleepDuration == 28800.0)
    }

    @Test func aggregator_filtersOutNaps() {
        let samples = [
            // 2-hour nap (< 3 hours)
            RawSleepSample(startDate: date(2026, 3, 2, 14, 0), endDate: date(2026, 3, 2, 16, 0), category: .asleepUnspecified),
        ]
        let result = SleepAggregator.aggregate(samples)
        #expect(result.isEmpty)
    }

    @Test func aggregator_keepsSleepJustOver3Hours() {
        let samples = [
            RawSleepSample(startDate: date(2026, 3, 2, 2, 0), endDate: date(2026, 3, 2, 5, 1), category: .asleepUnspecified),
        ]
        let result = SleepAggregator.aggregate(samples)
        #expect(result.count == 1)
    }

    @Test func aggregator_separatesMultipleNights() {
        let samples = [
            RawSleepSample(startDate: date(2026, 3, 1, 23, 0), endDate: date(2026, 3, 2, 7, 0), category: .asleepUnspecified),
            RawSleepSample(startDate: date(2026, 3, 2, 23, 0), endDate: date(2026, 3, 3, 6, 30), category: .asleepUnspecified),
        ]
        let result = SleepAggregator.aggregate(samples)
        #expect(result.count == 2)
    }

    @Test func aggregator_mergesAdjacentSamples() {
        let samples = [
            RawSleepSample(startDate: date(2026, 3, 1, 23, 0), endDate: date(2026, 3, 2, 3, 0), category: .asleepUnspecified),
            RawSleepSample(startDate: date(2026, 3, 2, 3, 10), endDate: date(2026, 3, 2, 7, 0), category: .asleepUnspecified),
        ]
        let result = SleepAggregator.aggregate(samples)
        #expect(result.count == 1)
    }

    @Test func aggregator_splitsLargeGap() {
        let samples = [
            RawSleepSample(startDate: date(2026, 3, 1, 23, 0), endDate: date(2026, 3, 2, 6, 0), category: .asleepUnspecified),
            RawSleepSample(startDate: date(2026, 3, 2, 23, 0), endDate: date(2026, 3, 3, 7, 0), category: .asleepUnspecified),
        ]
        let result = SleepAggregator.aggregate(samples)
        #expect(result.count == 2)
    }

    // =========================================================================
    // MARK: - HistoryViewModel + Sleep Integration
    // =========================================================================

    @Test func historyVM_mergesSleepWithWater() async throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        context.insert(Event(activity: activity, quantity: 8.0))
        try context.save()

        let mock = MockHealthKitService()
        let today = Calendar.current.startOfDay(for: .now)
        mock.mockSleepNights = [
            SleepNight(
                date: today,
                inBedInterval: DateInterval(start: today.addingTimeInterval(-28800), duration: 28800),
                totalSleepDuration: 25200,
                stages: nil
            )
        ]

        let vm = HistoryViewModel(modelContext: context, healthService: mock)
        await vm.refreshWithSleep()

        #expect(vm.daySummaries.count == 1)
        #expect(vm.daySummaries.first?.sleepNight != nil)
        #expect(vm.daySummaries.first?.total == 8.0)
    }

    @Test func historyVM_sleepOnlyDay() async throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        TestHelpers.makeWaterActivity(context: context)
        try context.save()

        let mock = MockHealthKitService()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let yesterdayStart = Calendar.current.startOfDay(for: yesterday)
        mock.mockSleepNights = [
            SleepNight(
                date: yesterdayStart,
                inBedInterval: DateInterval(start: yesterdayStart.addingTimeInterval(-28800), duration: 28800),
                totalSleepDuration: 25200,
                stages: nil
            )
        ]

        let vm = HistoryViewModel(modelContext: context, healthService: mock)
        await vm.refreshWithSleep()

        #expect(vm.daySummaries.count == 1)
        #expect(vm.daySummaries.first?.sleepNight != nil)
        #expect(vm.daySummaries.first?.entries.isEmpty == true)
    }

    @Test func historyVM_waterOnlyDayNilSleep() async throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        context.insert(Event(activity: activity, quantity: 8.0))
        try context.save()

        let mock = MockHealthKitService()
        mock.mockSleepNights = []

        let vm = HistoryViewModel(modelContext: context, healthService: mock)
        await vm.refreshWithSleep()

        #expect(vm.daySummaries.count == 1)
        #expect(vm.daySummaries.first?.sleepNight == nil)
    }

    @Test func historyVM_healthKitUnavailable() async throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        TestHelpers.makeWaterActivity(context: context)
        try context.save()

        let mock = MockHealthKitService()
        mock.isAvailable = false

        let vm = HistoryViewModel(modelContext: context, healthService: mock)
        await vm.refreshWithSleep()

        #expect(vm.healthAuthStatus == .unavailable)
    }

    @Test func historyVM_requestsAuthOnFirstLoad() async throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        TestHelpers.makeWaterActivity(context: context)
        try context.save()

        let mock = MockHealthKitService()
        let vm = HistoryViewModel(modelContext: context, healthService: mock)
        await vm.refreshWithSleep()

        #expect(mock.authorizationRequested == true)
        #expect(vm.healthAuthStatus == .requested)
    }

    @Test func historyVM_authRequestedOnlyOnce() async throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        TestHelpers.makeWaterActivity(context: context)
        try context.save()

        let mock = MockHealthKitService()
        let vm = HistoryViewModel(modelContext: context, healthService: mock)
        await vm.refreshWithSleep()
        mock.authorizationRequested = false
        await vm.refreshWithSleep()

        #expect(mock.authorizationRequested == false)
    }

    @Test func historyVM_sleepFetchFailureShowsWater() async throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        context.insert(Event(activity: activity, quantity: 8.0))
        try context.save()

        let mock = MockHealthKitService()
        mock.shouldThrowOnFetch = true

        let vm = HistoryViewModel(modelContext: context, healthService: mock)
        await vm.refreshWithSleep()

        #expect(vm.daySummaries.count == 1)
        #expect(vm.daySummaries.first?.total == 8.0)
        #expect(vm.daySummaries.first?.sleepNight == nil)
    }

    @Test func historyVM_authFailureShowsWater() async throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        context.insert(Event(activity: activity, quantity: 8.0))
        try context.save()

        let mock = MockHealthKitService()
        mock.shouldThrowOnAuth = true

        let vm = HistoryViewModel(modelContext: context, healthService: mock)
        await vm.refreshWithSleep()

        #expect(vm.daySummaries.count == 1)
        #expect(vm.daySummaries.first?.total == 8.0)
    }

    @Test func historyVM_noHealthServiceSkipsSleep() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        context.insert(Event(activity: activity, quantity: 8.0))
        try context.save()

        // No health service — backward compatible
        let vm = HistoryViewModel(modelContext: context)
        #expect(vm.daySummaries.count == 1)
        #expect(vm.daySummaries.first?.sleepNight == nil)
    }

    // =========================================================================
    // MARK: - WaterEntry (Legacy — kept while model exists)
    // =========================================================================

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

    // =========================================================================
    // MARK: - Helpers
    // =========================================================================

    /// Convenience to create a date with explicit components.
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
