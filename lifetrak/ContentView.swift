import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TodayView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WaterEntry.self, inMemory: true)
}
