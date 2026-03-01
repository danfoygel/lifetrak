import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TodayViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    todayContent(vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Today")
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TodayViewModel(modelContext: modelContext)
            }
        }
    }

    @ViewBuilder
    private func todayContent(_ vm: TodayViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                progressSection(vm)
                logButton(vm)
                entriesList(vm)
            }
            .padding()
        }
    }

    // MARK: - Progress Section

    @ViewBuilder
    private func progressSection(_ vm: TodayViewModel) -> some View {
        VStack(spacing: 12) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: vm.progress)
                    .stroke(
                        vm.goalMet ? Color.green : Color.blue,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: vm.progress)

                VStack(spacing: 4) {
                    Text("\(vm.todayTotalDisplay)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("of \(vm.dailyGoalDisplay) oz")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 200, height: 200)
            .padding(.top, 8)

            if vm.goalMet {
                Label("Goal reached!", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Log Button

    @ViewBuilder
    private func logButton(_ vm: TodayViewModel) -> some View {
        Button {
            vm.logWater()
        } label: {
            Label("Log \(vm.formatServingSize()) oz", systemImage: "plus.circle.fill")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .sensoryFeedback(.impact(weight: .medium), trigger: vm.todayEntries.count)
    }

    // MARK: - Entries List

    @ViewBuilder
    private func entriesList(_ vm: TodayViewModel) -> some View {
        if !vm.todayEntries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Entries")
                    .font(.headline)
                    .padding(.top, 8)

                ForEach(vm.todayEntries) { entry in
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(.blue)
                        Text("\(formatAmount(entry.amount)) oz")
                            .font(.body)
                        Spacer()
                        Text(entry.timestamp, format: .dateTime.hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func formatAmount(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

// Expose serving size formatting for the view
extension TodayViewModel {
    func formatServingSize() -> String {
        if servingSize == servingSize.rounded() {
            return String(Int(servingSize))
        }
        return String(format: "%.1f", servingSize)
    }
}

#Preview {
    TodayView()
        .modelContainer(for: WaterEntry.self, inMemory: true)
}
