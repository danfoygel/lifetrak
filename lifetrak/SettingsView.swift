import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var dailyGoal: Double = 64.0
    @State private var servingSize: Double = 8.0
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("Daily Goal", systemImage: "target")
                        Spacer()
                        TextField("oz", value: $dailyGoal, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: dailyGoal) { _, newValue in
                                updateGoal(newValue)
                            }
                        Text("oz")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Serving Size", systemImage: "drop.fill")
                        Spacer()
                        TextField("oz", value: $servingSize, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: servingSize) { _, newValue in
                                updateServingSize(newValue)
                            }
                        Text("oz")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Water Tracking")
                } footer: {
                    Text("The serving size is how much water is logged each time you tap the button.")
                }

                Section {
                    Button("Reset to Defaults") {
                        dailyGoal = 64.0
                        servingSize = 8.0
                        updateGoal(64.0)
                        updateServingSize(8.0)
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                if !loaded {
                    loadSettings()
                    loaded = true
                }
            }
        }
    }

    // MARK: - Data Access

    private func loadSettings() {
        // Load current daily goal from default routine
        if let routine = fetchDefaultRoutine(),
           let water = fetchWaterActivity() {
            let waterID = water.persistentModelID
            if let goal = routine.goals.first(where: { $0.activity?.persistentModelID == waterID }) {
                dailyGoal = goal.targetQuantity ?? 64.0
            }
        }

        // Load serving size from water activity
        if let water = fetchWaterActivity() {
            servingSize = water.defaultQuantity ?? 8.0
        }
    }

    private func updateGoal(_ newGoal: Double) {
        guard let routine = fetchDefaultRoutine(),
              let water = fetchWaterActivity() else { return }
        let waterID = water.persistentModelID
        if let goal = routine.goals.first(where: { $0.activity?.persistentModelID == waterID }) {
            goal.targetQuantity = newGoal
        }
        try? modelContext.save()
    }

    private func updateServingSize(_ newSize: Double) {
        guard let water = fetchWaterActivity() else { return }
        water.defaultQuantity = newSize
        try? modelContext.save()
    }

    private func fetchDefaultRoutine() -> Routine? {
        let descriptor = FetchDescriptor<Routine>(
            predicate: #Predicate<Routine> { $0.isDefault == true && $0.isSnapshot == false }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchWaterActivity() -> Activity? {
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate<Activity> { $0.name == "Drink Water" }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Activity.self, Event.self, Routine.self, Goal.self, RoutineSchedule.self, WaterEntry.self], inMemory: true)
}
