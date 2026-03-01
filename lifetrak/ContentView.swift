import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<WaterEntry> { _ in true },
        sort: \WaterEntry.timestamp,
        order: .reverse
    ) private var entries: [WaterEntry]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                Text("LifeTrak")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Water tracking coming soon")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Today")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WaterEntry.self, inMemory: true)
}
