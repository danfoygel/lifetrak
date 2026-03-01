import Foundation

/// Pure function: aggregates raw sleep samples into sleep nights.
/// No HealthKit dependency — fully testable.
enum SleepAggregator {

    /// Maximum gap (in seconds) between samples to consider them part of the same session.
    private static let sessionGapThreshold: TimeInterval = 30 * 60 // 30 minutes

    /// Minimum session duration (in seconds) to qualify as primary sleep (not a nap).
    private static let minimumPrimarySleepDuration: TimeInterval = 3 * 3600 // 3 hours

    /// Aggregate raw sleep samples into sleep nights.
    /// Filters to primary sleep only (sessions > 3 hours).
    /// Assigns each night to the wake-up calendar date.
    static func aggregate(_ samples: [RawSleepSample]) -> [SleepNight] {
        guard !samples.isEmpty else { return [] }

        let sorted = samples.sorted { $0.startDate < $1.startDate }
        let sessions = groupIntoSessions(sorted)

        return sessions
            .filter(isPrimarySleep)
            .compactMap(buildSleepNight)
            .sorted { $0.date > $1.date }
    }

    // MARK: - Session Grouping

    private static func groupIntoSessions(_ samples: [RawSleepSample]) -> [[RawSleepSample]] {
        var sessions: [[RawSleepSample]] = []
        var currentSession: [RawSleepSample] = []

        for sample in samples {
            if let last = currentSession.last {
                let gap = sample.startDate.timeIntervalSince(last.endDate)
                if gap > sessionGapThreshold {
                    sessions.append(currentSession)
                    currentSession = [sample]
                } else {
                    currentSession.append(sample)
                }
            } else {
                currentSession = [sample]
            }
        }

        if !currentSession.isEmpty {
            sessions.append(currentSession)
        }

        return sessions
    }

    // MARK: - Filtering

    private static func isPrimarySleep(_ session: [RawSleepSample]) -> Bool {
        guard let first = session.first, let last = session.last else { return false }
        let totalSpan = last.endDate.timeIntervalSince(first.startDate)
        return totalSpan >= minimumPrimarySleepDuration
    }

    // MARK: - Building SleepNight

    private static func buildSleepNight(from samples: [RawSleepSample]) -> SleepNight? {
        guard let earliestStart = samples.min(by: { $0.startDate < $1.startDate })?.startDate,
              let latestEnd = samples.max(by: { $0.endDate < $1.endDate })?.endDate else {
            return nil
        }

        let inBedInterval = DateInterval(start: earliestStart, end: latestEnd)
        let wakeUpDate = Calendar.current.startOfDay(for: latestEnd)

        var coreDuration: TimeInterval = 0
        var deepDuration: TimeInterval = 0
        var remDuration: TimeInterval = 0
        var awakeDuration: TimeInterval = 0
        var unspecifiedDuration: TimeInterval = 0

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            switch sample.category {
            case .asleepCore: coreDuration += duration
            case .asleepDeep: deepDuration += duration
            case .asleepREM: remDuration += duration
            case .awake: awakeDuration += duration
            case .asleepUnspecified: unspecifiedDuration += duration
            case .inBed: break // doesn't count toward sleep time
            }
        }

        let totalSleep = coreDuration + deepDuration + remDuration + unspecifiedDuration

        // Only include stages if we have actual stage data (not just unspecified)
        let hasStageData = coreDuration > 0 || deepDuration > 0 || remDuration > 0
        let stages: SleepStages? = hasStageData ? SleepStages(
            core: coreDuration,
            deep: deepDuration,
            rem: remDuration,
            awake: awakeDuration
        ) : nil

        return SleepNight(
            date: wakeUpDate,
            inBedInterval: inBedInterval,
            totalSleepDuration: totalSleep,
            stages: stages
        )
    }
}
