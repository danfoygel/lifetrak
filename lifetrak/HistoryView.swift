import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryViewModel?
    @State private var showingAddSheet = false
    @State private var editingEntry: Event?

    init(viewModel: HistoryViewModel? = nil) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    historyContent(vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier(AXID.History.addButton)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                if let vm = viewModel {
                    AddEntrySheet(viewModel: vm)
                }
            }
            .sheet(item: $editingEntry) { entry in
                if let vm = viewModel {
                    EditEntrySheet(viewModel: vm, entry: entry)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = HistoryViewModel(modelContext: modelContext, healthService: HealthKitService())
            } else {
                viewModel?.refresh()
            }
        }
    }

    @ViewBuilder
    private func historyContent(_ vm: HistoryViewModel) -> some View {
        if vm.daySummaries.isEmpty {
            ContentUnavailableView(
                "No Entries Yet",
                systemImage: "drop.degreesign",
                description: Text("Start logging water on the Today tab, or tap + to add an entry.")
            )
        } else {
            List {
                ForEach(vm.daySummaries) { summary in
                    Section {
                        if let sleepNight = summary.sleepNight {
                            SleepCard(sleepNight: sleepNight)
                        }
                        ForEach(summary.entries) { entry in
                            entryRow(entry)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingEntry = entry
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        vm.deleteEntry(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        daySectionHeader(summary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .accessibilityIdentifier(AXID.History.entryList)
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: Event) -> some View {
        HStack {
            Image(systemName: "drop.fill")
                .foregroundStyle(.blue)
            Text("\(formatAmount(entry.quantity ?? 0)) oz")
                .font(.body)
            Spacer()
            Text(entry.timestamp, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier(AXID.History.entryRow)
    }

    @ViewBuilder
    private func daySectionHeader(_ summary: DaySummary) -> some View {
        HStack {
            Text(summary.date, format: .dateTime.weekday(.wide).month().day())
            Spacer()
            if !summary.entries.isEmpty {
                Text("\(formatAmount(summary.total)) oz")
                    .fontWeight(.semibold)
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

// MARK: - Add Entry Sheet

struct AddEntrySheet: View {
    let viewModel: HistoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double = 8.0
    @State private var timestamp: Date = .now

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        TextField("oz", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                        Text("oz")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Date & Time") {
                    DatePicker("When", selection: $timestamp)
                }
            }
            .navigationTitle("Add Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addEntry(amount: amount, timestamp: timestamp)
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
        }
    }
}

// MARK: - Edit Entry Sheet

struct EditEntrySheet: View {
    let viewModel: HistoryViewModel
    let entry: Event
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double
    @State private var timestamp: Date

    init(viewModel: HistoryViewModel, entry: Event) {
        self.viewModel = viewModel
        self.entry = entry
        self._amount = State(initialValue: entry.quantity ?? 0)
        self._timestamp = State(initialValue: entry.timestamp)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        TextField("oz", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                        Text("oz")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Date & Time") {
                    DatePicker("When", selection: $timestamp)
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.updateEntry(entry, amount: amount, timestamp: timestamp)
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Activity.self, Event.self, Routine.self, Goal.self, RoutineSchedule.self, WaterEntry.self], inMemory: true)
}
