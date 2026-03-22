import SnapshotTesting
import SwiftUI
import SwiftData
import Testing
@testable import lifetrak

@MainActor
@Suite("TodayView Snapshots", .serialized)
struct SnapshotTests {

    @Test func rendersEmptyState() throws {
        let (vm, container) = try makeVM(oz: 0)
        assertSnapshot(
            of: TodayView(viewModel: vm).modelContainer(container),
            as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro)),
            named: "1"
        )
    }

    @Test func rendersPartialProgress() throws {
        let (vm, container) = try makeVM(oz: 24)   // 24/64 = 37.5%
        assertSnapshot(
            of: TodayView(viewModel: vm).modelContainer(container),
            as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro)),
            named: "1"
        )
    }

    @Test func rendersGoalMet() throws {
        let (vm, container) = try makeVM(oz: 64)   // green ring + "Goal reached!"
        assertSnapshot(
            of: TodayView(viewModel: vm).modelContainer(container),
            as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro)),
            named: "1"
        )
    }

    @Test func rendersWithStreak() throws {
        let (vm, container) = try makeVM(oz: 64, priorDaysMeetingGoal: 2)
        assertSnapshot(
            of: TodayView(viewModel: vm).modelContainer(container),
            as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro)),
            named: "1"
        )
    }

    // MARK: - Helpers

    private func makeVM(oz: Double, priorDaysMeetingGoal: Int = 0) throws -> (TodayViewModel, ModelContainer) {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext

        let activity = TestHelpers.makeWaterActivity(context: context)
        TestHelpers.makeDefaultRoutine(context: context, waterActivity: activity, dailyGoal: 64)

        if oz > 0 {
            context.insert(Event(activity: activity, timestamp: .now, quantity: oz))
        }

        if priorDaysMeetingGoal > 0 {
            let cal = Calendar.current
            for dayOffset in 1...priorDaysMeetingGoal {
                let date = cal.date(byAdding: .day, value: -dayOffset, to: .now)!
                context.insert(Event(activity: activity, timestamp: date, quantity: 64))
            }
        }

        try context.save()
        return (TodayViewModel(modelContext: context), container)
    }
}

// MARK: - HistoryView Snapshots

@MainActor
@Suite("HistoryView Snapshots", .serialized)
struct HistoryViewSnapshotTests {

    @Test func historyView_rendersEmptyState() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        TestHelpers.makeWaterActivity(context: context)
        try context.save()

        let vm = HistoryViewModel(modelContext: context)
        assertSnapshot(
            of: HistoryView(viewModel: vm).modelContainer(container),
            as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro)),
            named: "1"
        )
    }

    @Test func rendersWithEntries() throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let activity = TestHelpers.makeWaterActivity(context: context)
        context.insert(Event(activity: activity, quantity: 8.0))
        context.insert(Event(activity: activity, quantity: 16.0))
        try context.save()

        let vm = HistoryViewModel(modelContext: context)
        assertSnapshot(
            of: HistoryView(viewModel: vm).modelContainer(container),
            as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro)),
            named: "1"
        )
    }

    @Test func rendersWithSleepAndWater() async throws {
        let container = try TestHelpers.makeContainer()
        let context = container.mainContext
        let activity = TestHelpers.makeWaterActivity(context: context)
        context.insert(Event(activity: activity, quantity: 24.0))
        try context.save()

        let mock = MockHealthKitService()
        let today = Calendar.current.startOfDay(for: .now)
        mock.mockSleepNights = [
            SleepNight(
                date: today,
                inBedInterval: DateInterval(
                    start: Calendar.current.date(byAdding: .hour, value: -8, to: .now)!,
                    duration: 8 * 3600
                ),
                totalSleepDuration: 7 * 3600 + 32 * 60,
                stages: SleepStages(
                    core: 3 * 3600 + 51 * 60,
                    deep: 1 * 3600 + 22 * 60,
                    rem: 1 * 3600 + 48 * 60,
                    awake: 31 * 60
                )
            )
        ]

        let vm = HistoryViewModel(modelContext: context, healthService: mock)
        await vm.refreshWithSleep()
        assertSnapshot(
            of: HistoryView(viewModel: vm).modelContainer(container),
            as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro)),
            named: "1"
        )
    }
}

// MARK: - SleepCard Snapshots

@MainActor
@Suite("SleepCard Snapshots", .serialized)
struct SleepCardSnapshotTests {

    @Test func rendersWithStages() {
        let today = Calendar.current.startOfDay(for: .now)
        let sleepNight = SleepNight(
            date: today,
            inBedInterval: DateInterval(
                start: Calendar.current.date(byAdding: .hour, value: -8, to: .now)!,
                duration: 8 * 3600
            ),
            totalSleepDuration: 7 * 3600 + 32 * 60,
            stages: SleepStages(
                core: 3 * 3600 + 51 * 60,
                deep: 1 * 3600 + 22 * 60,
                rem: 1 * 3600 + 48 * 60,
                awake: 31 * 60
            )
        )
        assertSnapshot(
            of: List { SleepCard(sleepNight: sleepNight) },
            as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro)),
            named: "1"
        )
    }

    @Test func rendersWithoutStages() {
        let today = Calendar.current.startOfDay(for: .now)
        let sleepNight = SleepNight(
            date: today,
            inBedInterval: DateInterval(
                start: Calendar.current.date(byAdding: .hour, value: -8, to: .now)!,
                duration: 8 * 3600
            ),
            totalSleepDuration: 7 * 3600 + 32 * 60,
            stages: nil
        )
        assertSnapshot(
            of: List { SleepCard(sleepNight: sleepNight) },
            as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro)),
            named: "1"
        )
    }
}
