import SwiftUI

/// Displays a single night's sleep data as a card in the History tab.
struct SleepCard: View {
    let sleepNight: SleepNight

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: icon + "Sleep" + total duration
            HStack {
                Image(systemName: "bed.double.fill")
                    .foregroundStyle(.indigo)
                Text("Sleep")
                    .font(.body)
                Spacer()
                Text(sleepNight.totalSleepDuration.sleepFormatted)
                    .font(.body)
                    .fontWeight(.semibold)
            }

            // In-bed time range
            Text("In bed \(formatTime(sleepNight.inBedInterval.start)) – \(formatTime(sleepNight.inBedInterval.end))")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Stage breakdown (if available)
            if let stages = sleepNight.stages {
                HStack(spacing: 4) {
                    Text("Core \(stages.core.sleepFormatted)")
                    Text("\u{00B7}")
                    Text("Deep \(stages.deep.sleepFormatted)")
                    Text("\u{00B7}")
                    Text("REM \(stages.rem.sleepFormatted)")
                    Text("\u{00B7}")
                    Text("Awake \(stages.awake.sleepFormatted)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}

#Preview("With stages") {
    List {
        SleepCard(sleepNight: SleepNight(
            date: .now,
            inBedInterval: DateInterval(
                start: Calendar.current.date(byAdding: .hour, value: -8, to: .now)!,
                end: .now
            ),
            totalSleepDuration: 7 * 3600 + 32 * 60,
            stages: SleepStages(
                core: 3 * 3600 + 51 * 60,
                deep: 1 * 3600 + 22 * 60,
                rem: 1 * 3600 + 48 * 60,
                awake: 31 * 60
            )
        ))
    }
}

#Preview("Without stages") {
    List {
        SleepCard(sleepNight: SleepNight(
            date: .now,
            inBedInterval: DateInterval(
                start: Calendar.current.date(byAdding: .hour, value: -8, to: .now)!,
                end: .now
            ),
            totalSleepDuration: 7 * 3600 + 32 * 60,
            stages: nil
        ))
    }
}
