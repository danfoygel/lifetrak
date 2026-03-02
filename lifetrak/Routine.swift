import Foundation
import SwiftData

/// A named set of goals that defines what a user aims to accomplish.
/// Routines are editable templates that can be assigned to date ranges.
/// Copy-on-write protects history: editing a routine with past schedules
/// auto-clones the old version as a hidden snapshot.
@Model
final class Routine {
    var name: String
    var isDefault: Bool
    /// True for historical clones created by copy-on-write. Hidden from the routine picker.
    var isSnapshot: Bool

    @Relationship(deleteRule: .cascade, inverse: \Goal.routine)
    var goals: [Goal] = []

    @Relationship(deleteRule: .nullify, inverse: \RoutineSchedule.routine)
    var schedules: [RoutineSchedule] = []

    init(name: String, isDefault: Bool = false, isSnapshot: Bool = false) {
        self.name = name
        self.isDefault = isDefault
        self.isSnapshot = isSnapshot
    }

    // MARK: - Copy-on-Write

    /// Creates a snapshot clone of this routine with copies of all its goals.
    /// The clone is marked `isSnapshot = true` and `isDefault = false`.
    /// Goal copies reference the same Activities but belong to the new snapshot.
    func createSnapshot() -> Routine {
        let snapshot = Routine(name: name, isDefault: false, isSnapshot: true)
        for goal in goals {
            let copy = Goal(
                routine: snapshot,
                activity: goal.activity!,
                period: goal.period,
                targetQuantity: goal.targetQuantity,
                targetDuration: goal.targetDuration,
                targetFrequency: goal.targetFrequency
            )
            snapshot.goals.append(copy)
        }
        return snapshot
    }
}
