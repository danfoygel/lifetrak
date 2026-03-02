import Foundation
import SwiftData

/// How an activity's events are populated.
enum DataSource: Codable, Equatable {
    /// User logs events manually via the app.
    case manual
    /// Events are auto-populated from HealthKit (associated value is the HK type identifier).
    case healthKit(String)
}

/// A defined action that a user tracks (e.g., "Drink Water", "Pushups", "Bright Light Therapy").
/// Describes *what* can be tracked, not an individual occurrence.
@Model
final class Activity {
    var name: String
    var emoji: String
    var quantityUnit: String?
    var tracksDuration: Bool
    var defaultQuantity: Double?
    var source: DataSource
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \Event.activity)
    var events: [Event] = []

    @Relationship(deleteRule: .nullify, inverse: \Goal.activity)
    var goals: [Goal] = []

    init(
        name: String,
        emoji: String,
        quantityUnit: String? = nil,
        tracksDuration: Bool = false,
        defaultQuantity: Double? = nil,
        source: DataSource = .manual,
        sortOrder: Int = 0
    ) {
        self.name = name
        self.emoji = emoji
        self.quantityUnit = quantityUnit
        self.tracksDuration = tracksDuration
        self.defaultQuantity = defaultQuantity
        self.source = source
        self.sortOrder = sortOrder
    }
}
