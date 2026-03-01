import Foundation

/// A single night's sleep, aggregated from HealthKit samples.
struct SleepNight: Identifiable {
    let date: Date                      // morning date (the day you woke up)
    let inBedInterval: DateInterval     // earliest inBed start -> latest end
    let totalSleepDuration: TimeInterval // sum of all asleep stages
    let stages: SleepStages?            // nil if device doesn't track stages

    var id: Date { date }

    /// Time in bed (may be longer than total sleep due to awake time, falling asleep, etc.)
    var timeInBed: TimeInterval { inBedInterval.duration }

    /// Sleep efficiency: time asleep / time in bed
    var efficiency: Double {
        guard timeInBed > 0 else { return 0 }
        return totalSleepDuration / timeInBed
    }
}

struct SleepStages {
    let core: TimeInterval      // light/core sleep
    let deep: TimeInterval      // deep sleep
    let rem: TimeInterval       // REM sleep
    let awake: TimeInterval     // awake periods during sleep
}

extension TimeInterval {
    /// Format as "7h 32m"
    var sleepFormatted: String {
        let totalMinutes = Int(self) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
