import SwiftUI

struct SettingsView: View {
    @AppStorage(WaterSettings.dailyGoalKey) private var dailyGoal: Double = WaterSettings.defaultDailyGoal
    @AppStorage(WaterSettings.servingSizeKey) private var servingSize: Double = WaterSettings.defaultServingSize

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
                        dailyGoal = WaterSettings.defaultDailyGoal
                        servingSize = WaterSettings.defaultServingSize
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
