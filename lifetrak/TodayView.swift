import SwiftUI
import SwiftData
import Charts

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TodayViewModel?
    @State private var showCelebration = false

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
                streakSection(vm)
                weeklyChart(vm)
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
            .overlay {
                if showCelebration {
                    CelebrationOverlay()
                        .allowsHitTesting(false)
                }
            }

            if vm.goalMet {
                Label("Goal reached!", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Log Button

    @ViewBuilder
    private func logButton(_ vm: TodayViewModel) -> some View {
        Button {
            let wasMetBefore = vm.goalMet
            vm.logWater()
            if !wasMetBefore && vm.goalMet {
                triggerCelebration()
            }
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

    // MARK: - Streak Section

    @ViewBuilder
    private func streakSection(_ vm: TodayViewModel) -> some View {
        if vm.currentStreak > 0 {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)
                Text("\(vm.currentStreak)-day streak")
                    .font(.headline)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Weekly Chart

    @ViewBuilder
    private func weeklyChart(_ vm: TodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Week")
                .font(.headline)

            Chart(vm.weeklyData) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Ounces", day.total)
                )
                .foregroundStyle(
                    day.total >= vm.dailyGoal ? Color.green : Color.blue
                )
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYScale(domain: 0...(max(vm.dailyGoal, vm.weeklyData.map(\.total).max() ?? 0) * 1.1))
            .chartOverlay { proxy in
                // Goal line
                GeometryReader { geo in
                    if let yPos = proxy.position(forY: vm.dailyGoal) {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yPos))
                            path.addLine(to: CGPoint(x: geo.size.width, y: yPos))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 160)
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
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

    // MARK: - Helpers

    private func formatAmount(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private func triggerCelebration() {
        withAnimation(.spring(duration: 0.5)) {
            showCelebration = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showCelebration = false
            }
        }
    }
}

// MARK: - Celebration Overlay

struct CelebrationOverlay: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, scale: CGFloat, opacity: Double)] = []

    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Image(systemName: "drop.fill")
                    .foregroundStyle(Color.blue.opacity(particle.opacity))
                    .scaleEffect(particle.scale)
                    .offset(x: particle.x, y: particle.y)
            }
        }
        .onAppear {
            for i in 0..<12 {
                let angle = Double(i) * (360.0 / 12.0) * .pi / 180.0
                let distance: CGFloat = CGFloat.random(in: 80...140)
                let particle = (
                    id: i,
                    x: cos(angle) * distance,
                    y: sin(angle) * distance,
                    scale: CGFloat.random(in: 0.4...1.0),
                    opacity: 0.8
                )
                withAnimation(.easeOut(duration: 1.5).delay(Double(i) * 0.05)) {
                    particles.append(particle)
                }
            }
        }
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
