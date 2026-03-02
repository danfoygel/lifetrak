import Foundation
import SwiftData

/// Maps a date range to a Routine. This is how the system knows which routine
/// applies on which days. Conceptually every day has exactly one routine —
/// days without a schedule use the default Routine.
@Model
final class RoutineSchedule {
    var routine: Routine?
    var startDate: Date
    var endDate: Date

    init(routine: Routine, startDate: Date, endDate: Date) {
        self.routine = routine
        self.startDate = startDate
        self.endDate = endDate
    }
}
