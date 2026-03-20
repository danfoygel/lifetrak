import Foundation
import SwiftData

/// How an activity's events are populated.
enum DataSource: Codable, Equatable {
    /// User logs events manually via the app.
    case manual
    /// Events are auto-populated from HealthKit (associated value is the HK type identifier).
    case healthKit(String)

    // Explicit nonisolated Codable implementation to satisfy Swift 6 strict concurrency.
    // Format matches Swift's synthesized encoding: case name as key, associated values
    // in a nested unkeyed container (e.g. {"manual":{}} or {"healthKit":["id"]}).
    private enum CodingKeys: String, CodingKey { case manual, healthKit }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .manual:
            _ = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .manual)
        case .healthKit(let identifier):
            var nested = container.nestedUnkeyedContainer(forKey: .healthKit)
            try nested.encode(identifier)
        }
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var allKeys = ArraySlice(container.allKeys)
        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
            throw DecodingError.typeMismatch(
                DataSource.self,
                .init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.")
            )
        }
        switch onlyKey {
        case .manual:
            self = .manual
        case .healthKit:
            var nested = try container.nestedUnkeyedContainer(forKey: .healthKit)
            self = .healthKit(try nested.decode(String.self))
        }
    }
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
