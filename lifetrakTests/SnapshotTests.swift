import SnapshotTesting
import SwiftUI
import SwiftData
import XCTest
@testable import lifetrak

@MainActor
final class SnapshotTests: XCTestCase {

    func testRendersEmptyState() throws {
        let (vm, container) = try makeVM(oz: 0)
        assertSnapshot(
            of: TodayView(viewModel: vm).modelContainer(container),
            as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro))
        )
    }

    func testRendersPartialProgress() throws {
        let (vm, container) = try makeVM(oz: 24)   // 24/64 = 37.5%
        assertSnapshot(
            of: TodayView(viewModel: vm).modelContainer(container),
            as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro))
        )
    }

    func testRendersGoalMet() throws {
        let (vm, container) = try makeVM(oz: 64)   // green ring + "Goal reached!"
        assertSnapshot(
            of: TodayView(viewModel: vm).modelContainer(container),
            as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro))
        )
    }

    func testRendersWithStreak() throws {
        let (vm, container) = try makeVM(oz: 64, priorDaysMeetingGoal: 2)
        assertSnapshot(
            of: TodayView(viewModel: vm).modelContainer(container),
            as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro))
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
