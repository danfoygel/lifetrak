import Foundation
import Testing
import SwiftData
@testable import lifetrak

@MainActor
struct TodayViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: WaterEntry.self, configurations: config)
    }

    // MARK: - Initial state

    @Test func initialTodayTotalIsZero() throws {
        let container = try makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)
        vm.refresh()
        #expect(vm.todayTotal == 0.0)
    }

    @Test func initialProgressIsZero() throws {
        let container = try makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)
        vm.refresh()
        #expect(vm.progress == 0.0)
    }

    // MARK: - Logging water

    @Test func logWaterIncreasesTodayTotal() throws {
        let container = try makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        vm.logWater()
        #expect(vm.todayTotal == 8.0) // default serving = 8 oz
    }

    @Test func logWaterMultipleTimes() throws {
        let container = try makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        vm.logWater()
        vm.logWater()
        vm.logWater()
        #expect(vm.todayTotal == 24.0)
    }

    @Test func logWaterCreatesEntry() throws {
        let container = try makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        vm.logWater()
        #expect(vm.todayEntries.count == 1)
        #expect(vm.todayEntries.first?.amount == 8.0)
    }

    // MARK: - Progress calculation

    @Test func progressCalculation() throws {
        let container = try makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        // Default goal is 64 oz, default serving is 8 oz
        vm.logWater() // 8 oz
        #expect(vm.progress == 8.0 / 64.0)
    }

    @Test func progressCapsAtOne() throws {
        let container = try makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        // Log more than the goal (64 oz)
        for _ in 0..<10 { vm.logWater() } // 80 oz
        #expect(vm.progress == 1.0)
    }

    // MARK: - Goal met

    @Test func goalMetWhenTotalReachesGoal() throws {
        let container = try makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        for _ in 0..<8 { vm.logWater() } // 64 oz = goal
        #expect(vm.goalMet == true)
    }

    @Test func goalNotMetWhenBelowGoal() throws {
        let container = try makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        vm.logWater() // 8 oz
        #expect(vm.goalMet == false)
    }

    // MARK: - Excludes yesterday's entries

    @Test func todayTotalExcludesYesterday() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Insert an entry from yesterday directly
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let oldEntry = WaterEntry(timestamp: yesterday, amount: 32.0)
        context.insert(oldEntry)
        try context.save()

        let vm = TodayViewModel(modelContext: context)
        vm.refresh()
        #expect(vm.todayTotal == 0.0)
        #expect(vm.todayEntries.isEmpty)
    }

    // MARK: - Custom serving size

    @Test func logWaterUsesServingSize() throws {
        let container = try makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        vm.servingSize = 12.0
        vm.logWater()
        #expect(vm.todayTotal == 12.0)
    }

    // MARK: - Custom daily goal

    @Test func progressUsesCustomGoal() throws {
        let container = try makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        vm.dailyGoal = 32.0
        vm.logWater() // 8 oz
        #expect(vm.progress == 8.0 / 32.0)
    }

    // MARK: - Display strings

    @Test func todayTotalDisplay() throws {
        let container = try makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        vm.logWater()
        vm.logWater()
        #expect(vm.todayTotalDisplay == "16")
    }

    @Test func dailyGoalDisplay() throws {
        let container = try makeContainer()
        let vm = TodayViewModel(modelContext: container.mainContext)

        #expect(vm.dailyGoalDisplay == "64")
    }
}
