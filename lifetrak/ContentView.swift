import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "drop.fill") {
                TodayView()
            }

            Tab("History", systemImage: "calendar") {
                HistoryView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Activity.self, Event.self, Routine.self, Goal.self, RoutineSchedule.self, WaterEntry.self], inMemory: true)
}
