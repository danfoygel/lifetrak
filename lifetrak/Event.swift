import Foundation
import SwiftData

/// A single instance of an activity performed at a specific time.
/// This is the core data capture entity — the generalized replacement for WaterEntry.
@Model
final class Event {
    var activity: Activity?
    var timestamp: Date
    var endTimestamp: Date?
    var quantity: Double?

    /// Duration in seconds, computed from timestamps. Nil if the activity doesn't track duration.
    var duration: TimeInterval? {
        guard let end = endTimestamp else { return nil }
        return end.timeIntervalSince(timestamp)
    }

    init(
        activity: Activity,
        timestamp: Date = .now,
        endTimestamp: Date? = nil,
        quantity: Double? = nil
    ) {
        self.activity = activity
        self.timestamp = timestamp
        self.endTimestamp = endTimestamp
        self.quantity = quantity
    }
}
