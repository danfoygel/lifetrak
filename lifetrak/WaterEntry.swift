import Foundation
import SwiftData

@Model
final class WaterEntry {
    var timestamp: Date
    var amount: Double // in ounces

    init(timestamp: Date = .now, amount: Double) {
        self.timestamp = timestamp
        self.amount = amount
    }
}
