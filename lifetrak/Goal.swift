import Foundation
import SwiftData

/// The time period over which a goal is measured.
enum GoalPeriod: String, Codable {
    case daily
    case weekly
}

/// Connects a Routine to an Activity with a specific target.
/// Defines "how much" or "how often" an activity should be performed.
///
/// Two target patterns:
/// 1. **Cumulative** — e.g., "drink 64 oz of water per day"
///    (`targetQuantity = 64`, `period = .daily`)
/// 2. **Frequency + per-occurrence** — e.g., "bright light therapy for 20 min, 5x/week"
///    (`targetDuration = 1200`, `targetFrequency = 5`, `period = .weekly`)
@Model
final class Goal {
    var routine: Routine?
    var activity: Activity?
    var period: GoalPeriod

    /// Cumulative target in the period (e.g., 64 oz/day).
    var targetQuantity: Double?
    /// Per-occurrence duration target in seconds (e.g., 1200 for 20 min).
    var targetDuration: TimeInterval?
    /// Number of occurrences in the period (e.g., 5x/week).
    var targetFrequency: Int?

    init(
        routine: Routine,
        activity: Activity,
        period: GoalPeriod = .daily,
        targetQuantity: Double? = nil,
        targetDuration: TimeInterval? = nil,
        targetFrequency: Int? = nil
    ) {
        self.routine = routine
        self.activity = activity
        self.period = period
        self.targetQuantity = targetQuantity
        self.targetDuration = targetDuration
        self.targetFrequency = targetFrequency
    }
}
