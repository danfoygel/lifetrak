# Kickoff

I'm starting a new project.  This will be an iphone app, purely for my own personal use (at least for now).  I am an experienced developer, but have never built a mobile app or used XCode before.  

The purpose of the app is to make it easy/convenient to track various actions I'm supposed to do throughout the day, such as:

- Taking medicine
- Drinking water
- Exercise
- Journaling
- etc.

Some of this information will come from data entry within the app.  Other information will come from Apple Health - heart rate, sleep, etc.

The main features of the app will be:

- Convenient data entry - one-click ways of recording that I just drank some water, or meditated, etc.
- Gamified motivation - similar to the apple "rings", a compelling UI that encourages me to complete my daily goals
- Manual data history - show a record of everything that was captured in data entry, and allow full control to create/edit/delete in order to fix inaccuracies
- Analysis - different visualizations showing trends in the data, correlations, streaks, etc.
- Settings - make it easy to configure the data entry capabilities.  For example, I would put in my current prescriptions in the settings - and then in the data entry screens, I could just one-click record that I took those specific medications.

That's all the info I have for now.  I will obviously further refine the feature set as we explore this and start developing the app.

Write a plan (in this file) for how we're going to build this.  Do whatever research/analysis you need to do to identify the best technical approach.  I want to follow best practices - TDD, CI, etc.  I'm sure you will have questions/clarification requests - put those in PLAN.md as well, and I will review and respond.

---

# Plan — Tracer Round: Water Tracking

## Strategy

Instead of building horizontally across many tracker types, we're doing a **tracer round** — one data element (water intake) built end-to-end with full functionality. This validates the entire stack (models, persistence, UI, progress visualization, history, settings) before generalizing to other trackers.

Once the water tracer round is complete and feels good, we'll generalize the architecture to support additional tracker types.

## Current State

Xcode has generated a working SwiftUI + SwiftData scaffold with a placeholder `Item` model, a "Hello World" content view, and empty test targets. CloudKit entitlements and push notifications are configured but not yet wired up.

## Technical Stack

| Layer | Choice | Why |
|-------|--------|-----|
| UI | **SwiftUI** | Already set up; declarative, modern, good for rapid iteration |
| Persistence | **SwiftData** | Already set up; Apple's modern ORM, works naturally with SwiftUI |
| Architecture | **MVVM** | Natural fit for SwiftUI's data binding; keeps views thin and logic testable |
| Charts | **Swift Charts** | Apple's native charting framework; works naturally with SwiftUI |
| Unit Tests | **Swift Testing** | Already scaffolded; modern, expressive test framework |
| UI Tests | **XCTest** | Already scaffolded; standard for UI automation |
| CI | **GitHub Actions** | Free for personal repos; `xcodebuild test` in a macOS runner |

## Architecture

```
┌─────────────────────────────────────────────┐
│                   Views                      │
│  (SwiftUI screens - thin, declarative)       │
├─────────────────────────────────────────────┤
│                ViewModels                    │
│  (@Observable classes - business logic)      │
├─────────────────────────────────────────────┤
│                  Models                      │
│  SwiftData @Model classes                    │
├─────────────────────────────────────────────┤
│              SwiftData                       │
│  (Persistence framework)                     │
└─────────────────────────────────────────────┘
```

**Key decisions:**
- **@Observable** (not ObservableObject) — modern Swift observation, less boilerplate
- **ViewModels are unit-testable** — business logic lives here, not in views
- **Models are the source of truth** — SwiftData models hold all persisted state
- **No services layer yet** — we'll add it when we need HealthKit/notifications; no premature abstraction

## Data Model

For the water tracer round, we only need one model:

```swift
@Model
class WaterEntry {
    var timestamp: Date
    var amount: Double       // in ounces

    init(timestamp: Date = .now, amount: Double) {
        self.timestamp = timestamp
        self.amount = amount
    }
}
```

Water settings (daily goal, default serving size) will be stored in `@AppStorage` / `UserDefaults` since they're simple key-value preferences, not relational data.

When we generalize later, this will evolve into a more generic `TrackerEntry` model with a relationship to a `TrackerDefinition`.

## Feature Build Order

Each step delivers working, tested functionality.

### Step 1: Model & Persistence
**Goal:** Replace the placeholder `Item` with `WaterEntry` and verify persistence works.

- Define `WaterEntry` SwiftData model
- Write unit tests: create, read, delete entries; query today's entries; sum today's total
- Register model in the app's `ModelContainer`
- Remove placeholder `Item` model
- Set up CI (GitHub Actions running tests on push)

### Step 2: Today Screen — Quick Logging
**Goal:** The main screen where you tap to log water.

- Build the Today view showing today's water progress
- Large tap target button to log a serving (default 8 oz)
- Display current total vs. daily goal (e.g., "32 / 64 oz")
- Progress ring or bar showing percentage toward goal
- List of today's individual entries below the progress display
- Haptic feedback on log

### Step 3: Settings
**Goal:** Configure water tracking preferences.

- Settings screen accessible from Today view (gear icon or tab)
- Configure daily goal (oz)
- Configure default serving size (oz)
- Simple form-based UI

### Step 4: History & Editing
**Goal:** Browse and correct past entries.

- History view showing entries grouped by day
- Tap an entry to edit amount or timestamp
- Swipe to delete an entry
- Add an entry manually (backfill a missed log)
- Day summary showing total for each day

### Step 5: Progress Visualization
**Goal:** Motivating visuals and trend data.

- Progress ring component on the Today screen (animated, fills as you drink)
- Celebration animation when daily goal is reached
- Weekly bar chart (Swift Charts) showing daily totals for the past 7 days
- Current streak display (consecutive days meeting goal)

### Step 6: Polish
**Goal:** Make it feel like a finished, single-purpose app.

- Tab bar navigation (Today / History / Settings)
- App icon refresh (water-themed)
- Empty states (first launch, no entries yet)
- Proper date formatting and localization of units
- Smooth animations and transitions

## TDD Approach

For each step:
1. **Write model/logic tests first** — verify calculations, queries, edge cases
2. **Implement the minimum code** to make tests pass
3. **Build the view** — use SwiftUI previews for rapid visual iteration
4. **Add UI tests** for critical user flows

Focus test coverage on ViewModels (where logic lives). Views stay thin.

## CI Pipeline (GitHub Actions)

```yaml
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - checkout
      - xcodebuild test (iPhone simulator)
      - report results
```

## File/Folder Structure (Target for Tracer Round)

```
lifetrak/
├── lifetrakApp.swift
├── Models/
│   └── WaterEntry.swift
├── ViewModels/
│   ├── TodayViewModel.swift
│   ├── HistoryViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── TodayView.swift
│   ├── HistoryView.swift
│   ├── SettingsView.swift
│   └── Components/
│       ├── ProgressRing.swift
│       └── WaterEntryRow.swift
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

Intentionally flat and simple. We'll add structure as the app grows.

## What Comes After the Tracer Round

Once water tracking is solid:
1. ~~Generalize `WaterEntry` → generic `TrackerEntry` + `TrackerDefinition`~~ → **Replaced by generalized data model (see below)**
2. Add more tracker types (medications, exercise, etc.)
3. ~~Apple Health integration~~ → **Next tracer round (see below)**
4. Cross-tracker analysis and correlations
5. Notifications/reminders
6. Widgets

---

# Plan — Tracer Round 2: Apple Health (Sleep)

## Strategy

Same tracer round approach: pick **one** HealthKit data type (sleep) and build it end-to-end before generalizing. Sleep is a good choice because:

- It's **read-only** from HealthKit (no write needed), which simplifies the first integration
- It's visually distinct from water tracking — validates that the History tab can show heterogeneous data
- Sleep data has interesting structure (stages, durations, overnight spans) that will stress-test the architecture
- It's personally useful — seeing sleep alongside hydration patterns

Once sleep works, the same HealthKit service pattern generalizes to heart rate, steps, workouts, etc.

## HealthKit Background

### Sleep Data Structure

HealthKit stores sleep as `HKCategorySample` objects with type `HKCategoryType(.sleepAnalysis)`. Each sample has:

- **startDate / endDate** — the time range for that sample
- **value** — an `HKCategoryValueSleepAnalysis` enum:
  - `.inBed` — user is in bed (not necessarily asleep)
  - `.asleepUnspecified` — asleep, no stage data
  - `.asleepCore` — light/core sleep
  - `.asleepDeep` — deep sleep
  - `.asleepREM` — REM sleep
  - `.awake` — awake period during a sleep session
- **sourceRevision** — which device recorded it (Apple Watch, iPhone, third-party app)

### Key Complexities

1. **Overnight spans**: A sleep session starting at 11pm and ending at 7am crosses a calendar day boundary. We need to decide which "day" it belongs to.
2. **Multiple sources**: Apple Watch and iPhone may both record sleep data, creating overlapping samples. Need to handle deduplication or source prioritization.
3. **Fragmented samples**: A single night's sleep is represented as many samples (one per stage transition). These need to be aggregated into a coherent "sleep night."
4. **Naps**: Daytime sleep sessions are structurally identical to nighttime sleep. We may want to distinguish them.
5. **Missing data**: User may not wear their Apple Watch to bed, or may not have a device that tracks sleep stages.

### Simplifications for Tracer Round

- **Assign sleep to the wake-up day** — if you go to bed Sunday night and wake up Monday morning, that's Monday's sleep. This is the most intuitive mapping (how people talk about sleep: "I got 7 hours of sleep last night").
- **Use Apple's `HKSleepAnalysis` predicate for sleep sessions** — iOS 16+ provides `predicateForSamples(withStart:end:options:)` and we can filter to primary sleep sessions.
- **Show aggregate durations only** — total asleep time, time in bed, plus stage breakdown if available. Don't try to render a detailed hypnogram timeline (yet).
- **Read-only** — no editing of HealthKit data from within the app.
- **Single source handling** — if multiple sources overlap, trust HealthKit's built-in sample merging or pick the source with the most stage detail (Apple Watch over iPhone).

## Project Setup

### 1. HealthKit Capability

In Xcode: Target → Signing & Capabilities → + Capability → HealthKit.

This adds:
- `HealthKit.framework` linked to the target
- `com.apple.developer.healthkit` entitlement in the `.entitlements` file

### 2. Info.plist

Add usage description string (required — app will crash without it):

```xml
<key>NSHealthShareUsageDescription</key>
<string>LifeTrak reads your sleep data from Apple Health to show sleep history alongside your daily habits.</string>
```

We only need **read** permission (`NSHealthShareUsageDescription`). We do NOT need write permission (`NSHealthUpdateUsageDescription`) for this tracer round.

### 3. Simulator Limitations

HealthKit is available in the iOS Simulator but with no real data. For development:
- Unit tests use a **mock** HealthKit service (protocol-based)
- Manual testing on a **real device** with Apple Watch sleep data
- Can seed the simulator's Health app with sample data via the Health app's developer menu (Browse → Sleep → Add Data)

## Architecture

This tracer round introduces a **services layer** — previously noted in the plan as "we'll add it when we need HealthKit." Now we need it.

```
┌─────────────────────────────────────────────┐
│                   Views                      │
│  (SwiftUI screens — thin, declarative)       │
├─────────────────────────────────────────────┤
│                ViewModels                    │
│  (@Observable classes — business logic)      │
├─────────────────────────────────────────────┤
│                 Services                     │
│  (HealthKit access, protocol-based)          │
├──────────────────────┬──────────────────────┤
│      Models          │      HealthKit        │
│  SwiftData @Model    │  (Apple framework)    │
└──────────────────────┴──────────────────────┘
```

### HealthKit Service Protocol

Protocol-based design enables testing without a real HealthKit store:

```swift
protocol HealthKitServiceProtocol {
    /// Whether HealthKit is available on this device.
    var isAvailable: Bool { get }

    /// Request read authorization for sleep data.
    func requestSleepAuthorization() async throws

    /// Fetch aggregated sleep nights for a date range.
    /// Returns one SleepNight per night, sorted newest first.
    func fetchSleepNights(from startDate: Date, to endDate: Date) async throws -> [SleepNight]
}
```

### Production Implementation

```swift
final class HealthKitService: HealthKitServiceProtocol {
    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestSleepAuthorization() async throws {
        let sleepType = HKCategoryType(.sleepAnalysis)
        try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
    }

    func fetchSleepNights(from startDate: Date, to endDate: Date) async throws -> [SleepNight] {
        // Query HKCategorySamples, aggregate into SleepNight structs
        // (implementation details in build steps below)
    }
}
```

### Mock for Tests

```swift
final class MockHealthKitService: HealthKitServiceProtocol {
    var isAvailable = true
    var mockSleepNights: [SleepNight] = []
    var shouldThrow = false

    func requestSleepAuthorization() async throws {
        if shouldThrow { throw HealthKitError.authorizationDenied }
    }

    func fetchSleepNights(from: Date, to: Date) async throws -> [SleepNight] {
        if shouldThrow { throw HealthKitError.queryFailed }
        return mockSleepNights.filter { $0.date >= from && $0.date <= to }
    }
}
```

## Data Model

Sleep data is **read-only from HealthKit**, not stored in SwiftData. Plain structs are sufficient:

```swift
/// A single night's sleep, aggregated from HealthKit samples.
struct SleepNight: Identifiable {
    let id: UUID
    let date: Date                      // morning date (the day you woke up)
    let inBedInterval: DateInterval     // earliest inBed start → latest end
    let totalSleepDuration: TimeInterval // sum of all asleep stages
    let stages: SleepStages?            // nil if device doesn't track stages

    /// Time in bed (may be longer than total sleep due to awake time, falling asleep, etc.)
    var timeInBed: TimeInterval { inBedInterval.duration }

    /// Sleep efficiency: time asleep / time in bed
    var efficiency: Double {
        guard timeInBed > 0 else { return 0 }
        return totalSleepDuration / timeInBed
    }
}

struct SleepStages {
    let core: TimeInterval      // light/core sleep
    let deep: TimeInterval      // deep sleep
    let rem: TimeInterval       // REM sleep
    let awake: TimeInterval     // awake periods during sleep
}
```

### Formatting Helpers

```swift
extension TimeInterval {
    /// Format as "7h 32m"
    var sleepFormatted: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
```

## History Tab Integration

### Design: Mixed-Content Day Sections

The History tab currently shows water entries grouped by day. We'll add sleep data as a **card at the top of each day's section**, above the water entries:

```
┌─────────────────────────────────────────┐
│ Monday, March 2                  48 oz  │  ← existing day header
├─────────────────────────────────────────┤
│ ┌─────────────────────────────────────┐ │
│ │ 🛏️  Sleep              7h 32m      │ │  ← NEW: sleep card
│ │ In bed 11:14 PM – 6:46 AM          │ │
│ │ Core 3h 51m · Deep 1h 22m          │ │
│ │ REM 1h 48m · Awake 31m             │ │
│ └─────────────────────────────────────┘ │
│ 💧 16 oz                     12:30 PM  │  ← existing water rows
│ 💧 12 oz                     10:15 AM  │
│ 💧 20 oz                      7:00 AM  │
└─────────────────────────────────────────┘
```

If no sleep data exists for a day, the sleep card simply doesn't appear. No empty state needed — it's additive.

If stage data is unavailable (no Apple Watch), show a simpler card:

```
│ 🛏️  Sleep              7h 32m      │
│ In bed 11:14 PM – 6:46 AM          │
```

### ViewModel Changes

The `HistoryViewModel` needs to combine two data sources:

```swift
@MainActor
@Observable
final class HistoryViewModel {
    private let modelContext: ModelContext
    private let healthService: HealthKitServiceProtocol

    var daySummaries: [DaySummary] = []

    init(modelContext: ModelContext, healthService: HealthKitServiceProtocol = HealthKitService()) {
        self.modelContext = modelContext
        self.healthService = healthService
        // ...
    }
}
```

`DaySummary` gets an optional sleep field:

```swift
struct DaySummary: Identifiable {
    let date: Date
    let entries: [WaterEntry]
    let sleepNight: SleepNight?     // NEW — nil if no sleep data for this day

    var id: Date { date }
    var total: Double { entries.reduce(0.0) { $0 + $1.amount } }
}
```

The `refresh()` method fetches both water entries (from SwiftData) and sleep nights (from HealthKit), then merges them by date. Days with only sleep data (no water entries) also appear. Days with only water entries also appear (sleep card omitted).

### Authorization Flow

HealthKit authorization is requested lazily — the first time the History tab loads:

1. Check `healthService.isAvailable`
2. If available, call `requestSleepAuthorization()`
3. HealthKit shows the system permission dialog (first time only)
4. Regardless of user's choice, proceed — HealthKit returns empty results if denied (it doesn't tell you whether the user denied; it just returns no data)
5. Fetch sleep data and merge into day summaries

Add an observable authorization state to the ViewModel:

```swift
enum HealthAuthStatus {
    case notRequested
    case requested   // authorization has been requested (may or may not be granted)
    case unavailable // device doesn't support HealthKit
}

var healthAuthStatus: HealthAuthStatus = .notRequested
```

**Important HealthKit quirk**: `HKHealthStore.authorizationStatus(for:)` only distinguishes between `.notDetermined` and `.sharingDenied`/`.sharingAuthorized` for *write* types. For read-only types, it always returns `.notDetermined` — Apple intentionally hides whether the user granted or denied read access. This means we can't show a "go to Settings to enable" message. We just get empty data.

## Testing Strategy

### What's Testable

| Component | Test Approach |
|-----------|---------------|
| `SleepNight` model | Direct unit tests — struct with computed properties |
| `HealthKitService` aggregation logic | Extract the sample-aggregation logic into a pure function that takes `[HKCategorySample]` and returns `[SleepNight]`. Test that directly. |
| `HistoryViewModel` with sleep | Inject `MockHealthKitService`, verify day summaries contain correct sleep data |
| Authorization flow | Mock service returns different states, verify ViewModel handles each |
| Date assignment (overnight) | Test that a 11pm–7am session is assigned to the morning's date |
| Edge cases | No sleep data, stages unavailable, very short sleep, naps |

### What's NOT Testable in Unit Tests

- Actual HealthKit queries against the real HKHealthStore (requires device + user-granted permissions)
- The system authorization dialog UI
- Real Apple Watch sleep data

These are validated through manual testing on a real device.

### Sample Test Cases

```swift
@Test func sleepNightAssignedToWakeUpDay() {
    // Sleep from Sunday 11pm to Monday 7am → belongs to Monday
}

@Test func sleepEfficiencyCalculation() {
    // 7h asleep in 8h in bed → 87.5% efficiency
}

@Test func daySummaryMergesSleepAndWater() {
    // Mock returns sleep for Monday, SwiftData has water for Monday
    // → DaySummary for Monday has both
}

@Test func dayWithSleepButNoWater() {
    // Mock returns sleep for Tuesday, no water entries
    // → DaySummary for Tuesday still appears with sleep card
}

@Test func dayWithWaterButNoSleep() {
    // No sleep data, water entries exist
    // → DaySummary has nil sleepNight, water entries present
}

@Test func noSleepStages() {
    // SleepNight with stages = nil
    // → still shows total duration and in-bed times
}

@Test func healthKitUnavailable() {
    // Mock isAvailable = false
    // → ViewModel skips authorization, shows water-only history
}
```

## Feature Build Order

### Step 1: HealthKit Service & Sleep Model

**Goal:** Establish the HealthKit service layer and sleep data model with tests.

- Define `SleepNight` and `SleepStages` structs
- Define `HealthKitServiceProtocol`
- Implement `HealthKitService` (production) with real HealthKit queries
- Implement `MockHealthKitService` for tests
- Write the **sample aggregation logic** as a testable pure function:
  - Input: `[HKCategorySample]` (raw HealthKit samples for a date range)
  - Output: `[SleepNight]` (aggregated per night)
  - Handles overnight boundary, stage aggregation, sorting
- Unit tests for aggregation, model computed properties, edge cases
- Add HealthKit capability + Info.plist usage description in Xcode

### Step 2: HistoryViewModel Integration

**Goal:** HistoryViewModel fetches and merges sleep data with water entries.

- Add `HealthKitServiceProtocol` dependency to `HistoryViewModel`
- Extend `DaySummary` with optional `SleepNight`
- Update `refresh()` to fetch sleep data and merge by date
- Handle authorization flow (request on first load, graceful fallback)
- Handle `isAvailable == false` (skip HealthKit entirely)
- Unit tests using `MockHealthKitService`:
  - Merge logic (sleep + water on same day, sleep-only days, water-only days)
  - Authorization states
  - Error handling (HealthKit query failure → still shows water data)

### Step 3: History View — Sleep Card UI

**Goal:** Display sleep data in the History tab.

- Build `SleepCard` view component
- Integrate into `HistoryView` — appears at top of each day section when sleep data exists
- Two layouts: full (with stages) and simple (duration + in-bed time only)
- Formatting: "7h 32m" durations, "11:14 PM – 6:46 AM" time ranges
- Consistent visual style with existing water entries (but visually distinct — bed icon, different color accent)

### Step 4: Polish & Edge Cases

**Goal:** Handle real-world edge cases and make it feel solid.

- Test on real device with actual Apple Watch sleep data
- Handle naps (short daytime sleep) — show or filter?
- Handle missing/partial data gracefully
- Ensure existing water-only tests still pass
- Performance: only fetch sleep data for the date range visible in history (not all-time)

## File Structure (After This Tracer Round)

```
lifetrak/
├── lifetrakApp.swift
├── ContentView.swift
├── WaterEntry.swift
├── TodayView.swift
├── TodayViewModel.swift
├── HistoryView.swift
├── HistoryViewModel.swift
├── SettingsView.swift
├── Services/
│   ├── HealthKitServiceProtocol.swift
│   ├── HealthKitService.swift
│   └── SleepAggregator.swift       // pure function: samples → SleepNight[]
├── Models/
│   └── SleepNight.swift             // SleepNight + SleepStages structs
└── Views/
    └── SleepCard.swift              // sleep card component
```

Tests:
```
lifetrakTests/
├── AllTests.swift                   // existing water tracking tests
├── TestHelpers.swift                // existing helpers
├── SleepNightTests.swift            // model tests
├── SleepAggregatorTests.swift       // aggregation logic tests
├── MockHealthKitService.swift       // test double
└── HistoryViewModelSleepTests.swift // integration tests
```

## Open Questions

1. **Naps**: Should daytime sleep sessions (e.g., 2pm–3pm nap) appear in the History tab? Options:
   - **Show all sleep** — simple, transparent
   - **Filter to primary sleep only** — cleaner, but risks hiding valid data
   - **Separate naps visually** — show them but styled differently

Answer: primary sleep only

2. **Date range**: How far back should we fetch sleep history? Options:
   - **Match water entry range** — fetch sleep for all dates that have water entries
   - **Fixed window** (e.g., last 90 days) — simpler, bounded
   - **Paginated/lazy** — fetch as user scrolls

Answer: let's keep it simple, last 30 days

3. **Future generalization**: When we add more HealthKit types (heart rate, steps, workouts), should each get its own card in the day section? Or should we build a more flexible "day dashboard" layout? (Don't need to decide now — just flagging it.)

Answer: Not sure yet.

---

# Generalized Data Model

## Overview

After the tracer rounds validated the full stack (SwiftData persistence, HealthKit integration, MVVM architecture, mixed-content history), we generalize from water-specific and sleep-specific models to a unified data model built around five core entities: **Activity**, **Event**, **Routine**, **Goal**, and **RoutineSchedule**.

This replaces the earlier plan to generalize `WaterEntry` → `TrackerEntry` + `TrackerDefinition`.

### Naming — HealthKit Conflict Check

| Name | HealthKit overlap | Verdict |
|------|-------------------|---------|
| Activity | `HKActivitySummary`, `HKWorkoutActivityType` exist but are `HK`-prefixed. `ActivityKit.Activity` also exists in a separate module. No compile-time clash. | **Safe** — module namespacing prevents conflicts |
| Event | `HKWorkoutEvent` exists, scoped under "Workout". `UIEvent` in UIKit is a different module. | **Safe** |
| Routine | No HealthKit types use this term at all. | **Safe** |
| Goal | No HealthKit types use this term. | **Safe** |
| RoutineSchedule | No HealthKit types use this term. | **Safe** |

## Core Entities

### Activity

An **Activity** is a defined action that a user tracks. It describes *what* can be tracked, not an individual occurrence.

```swift
@Model
class Activity {
    var name: String                    // "Drink Water", "Pushups", "Bright Light Therapy"
    var emoji: String                   // "💧", "💪", "☀️"
    var quantityUnit: String?           // "oz", "count", "mg" — nil if no quantity
    var tracksDuration: Bool            // true if events have start + end time
    var defaultQuantity: Double?        // quick-log default (e.g., 8 oz)
    var source: DataSource              // .manual or .healthKit(.sleepAnalysis)
    var sortOrder: Int                  // display ordering within the app

    @Relationship(deleteRule: .cascade)
    var events: [Event] = []

    @Relationship(deleteRule: .nullify, inverse: \Goal.activity)
    var goals: [Goal] = []
}

enum DataSource: Codable {
    case manual                          // user logs via the app
    case healthKit(String)               // auto-populated from HealthKit (type identifier)
}
```

**Key properties:**
- `quantityUnit` — if nil, the activity is occurrence-only (e.g., "took medication" — just log that it happened)
- `tracksDuration` — if true, events have both start and end timestamps (e.g., meditation, bright light therapy)
- `defaultQuantity` — enables quick-log (tap once to log the default amount)
- `source` — distinguishes manually logged activities from HealthKit-sourced ones. HealthKit activities have their events auto-populated.

**Examples:**

| Activity | quantityUnit | tracksDuration | defaultQuantity | source |
|----------|-------------|----------------|-----------------|--------|
| Drink Water | "oz" | false | 8.0 | .manual |
| Pushups | "count" | false | nil | .manual |
| Bright Light Therapy | nil | true | nil | .manual |
| Take Medication | nil | false | nil | .manual |
| Sleep | nil | true | nil | .healthKit("sleepAnalysis") |
| Run | "miles" | true | nil | .manual |

### Event

An **Event** is a single instance of an activity performed at a specific time. This is the core data capture entity.

```swift
@Model
class Event {
    var activity: Activity
    var timestamp: Date                 // when it happened (or start time if duration)
    var endTimestamp: Date?             // nil if activity doesn't track duration
    var quantity: Double?               // nil if activity doesn't track quantity

    /// Duration in seconds, computed from timestamps
    var duration: TimeInterval? {
        guard let end = endTimestamp else { return nil }
        return end.timeIntervalSince(timestamp)
    }
}
```

**Relationship to current models:**
- `WaterEntry` becomes an Event where `activity.name == "Drink Water"`, `quantity == amount`, `timestamp == timestamp`
- `SleepNight` becomes one or more Events where `activity.source == .healthKit("sleepAnalysis")`, with `timestamp`/`endTimestamp` for the sleep session

**Quick-log flow:** User taps "Drink Water" → creates an Event with `timestamp = .now`, `quantity = activity.defaultQuantity`, no duration.

**Duration-based flow:** User starts "Bright Light Therapy" → creates an Event with `timestamp = .now`. When they stop, `endTimestamp` is set.

### Routine

A **Routine** is a named set of goals. Routines are editable templates that can be assigned to date ranges. One routine is marked as the default.

When a routine is edited and past days reference it, the system automatically clones the old version (copy-on-write) so that past days are unaffected. These historical clones are hidden from the user.

```swift
@Model
class Routine {
    var name: String                    // "Standard", "Recovery Week", "Travel"
    var isDefault: Bool                 // exactly one non-snapshot routine is the default
    var isSnapshot: Bool                // true = historical clone, hidden from routine picker

    @Relationship(deleteRule: .cascade)
    var goals: [Goal] = []

    @Relationship(deleteRule: .nullify, inverse: \RoutineSchedule.routine)
    var schedules: [RoutineSchedule] = []
}
```

**Rules:**
- Exactly one non-snapshot Routine is marked `isDefault = true` at any time
- Routines are freely editable — copy-on-write protects history automatically
- Snapshot routines are internal implementation details, hidden from the UI
- A routine with no goals is valid (user is just logging without targets)
- Routines persist when not active — you can switch back to "Travel" without recreating it

### RoutineSchedule

A **RoutineSchedule** maps a date range to a Routine. This is how the system knows which routine applies on which days. Conceptually every day has exactly one routine — there is no distinction between "default days" and "override days."

```swift
@Model
class RoutineSchedule {
    var routine: Routine
    var startDate: Date                 // first day (inclusive)
    var endDate: Date                   // last day (inclusive)
}
```

**Resolution logic** — which routine applies on a given day:
1. Find any `RoutineSchedule` where `startDate <= day <= endDate`
2. If found, use that schedule's routine
3. If not found, use the default Routine

**Rules:**
- Schedules must not overlap (enforced in business logic)
- Schedules can cover past or future dates
- Deleting a schedule reverts those days to the default routine
- The default routine is just the auto-fill for days without an explicit schedule — no special behavior beyond that

### Copy-on-Write Behavior

Copy-on-write is triggered **at edit time**, not at assignment time. The user never manages snapshots — it just works.

**Example:**

1. "Travel" routine has goals: water 48 oz/day, medication 3x/day
2. User assigns Travel to May 1–5 (a `RoutineSchedule` is created pointing to Travel)
3. May 1–5 passes. Those days now reference the Travel routine.
4. User edits Travel, changing water goal from 48 oz to 32 oz
5. System detects past RoutineSchedules pointing to Travel → **clones** Travel (with its old goals) as a snapshot → repoints past schedules to the snapshot → applies the edit to Travel
6. Result: May 1–5 still shows 48 oz (via the hidden snapshot). Future uses of Travel show 32 oz.

**Implementation:**
- Before saving edits to a Routine, query for any `RoutineSchedule` entries that reference it and have `endDate < today`
- If any exist: clone the Routine with `isSnapshot = true`, clone its Goals, repoint those past schedules to the clone
- Then apply the edits to the original Routine
- Snapshot routines are never shown in the routine picker or settings

### Goal

A **Goal** connects a Routine to an Activity with a specific target. It defines "how much" or "how often" an activity should be performed.

```swift
@Model
class Goal {
    var routine: Routine
    var activity: Activity
    var period: GoalPeriod              // .daily or .weekly

    // Target definition — at least one should be set
    var targetQuantity: Double?         // cumulative target in period (e.g., 64 oz/day)
    var targetDuration: TimeInterval?   // per-occurrence duration target (e.g., 20 min)
    var targetFrequency: Int?           // number of occurrences in period (e.g., 5x/week)
}

enum GoalPeriod: String, Codable {
    case daily
    case weekly
}
```

**Two target patterns:**

1. **Cumulative** — "drink 64 oz of water per day"
   - `targetQuantity = 64`, `period = .daily`
   - Progress = sum of all event quantities in the period / targetQuantity

2. **Frequency + per-occurrence** — "bright light therapy for 20 minutes, 5 times per week"
   - `targetDuration = 1200` (20 min), `targetFrequency = 5`, `period = .weekly`
   - Progress = count of qualifying events (duration >= targetDuration) / targetFrequency

**Examples:**

| Goal | targetQuantity | targetDuration | targetFrequency | period |
|------|---------------|----------------|-----------------|--------|
| Drink 64 oz water/day | 64 | nil | nil | daily |
| 5x bright light, 20 min each/week | nil | 1200 | 5 | weekly |
| Take medication 3x/day | nil | nil | 3 | daily |
| Run 15 miles/week | 15 | nil | nil | weekly |
| Do 100 pushups/day | 100 | nil | nil | daily |

## Entity Relationships

```
RoutineSchedule ──N:1──▶ Routine ──1:N──▶ Goal ──N:1──▶ Activity ──1:N──▶ Event
(date range)                │                     │
                            │                     │  "what actually
                            ├── isDefault          │   happened"
                            └── isSnapshot         │
                                (hidden clone)     └── source (.manual / .healthKit)
```

- A **Routine** has many **Goals**. One non-snapshot routine is the default.
- A **RoutineSchedule** maps a date range to a Routine.
- A **Goal** belongs to one Routine, references one Activity.
- An **Activity** has many **Events** (the actual logged data).
- On any given day: find a RoutineSchedule covering that day; if none, use the default Routine.
- Snapshot routines are auto-created by copy-on-write when editing a routine with past schedules.

## HealthKit Integration

HealthKit-sourced activities (sleep, heart rate, steps, workouts) are unified into the same model:

- An **Activity** with `source = .healthKit("sleepAnalysis")` is auto-populated — its Events are created/refreshed by the HealthKit service, not manually logged
- HealthKit Events are **read-only** in the UI (no edit/delete)
- The existing `HealthKitServiceProtocol` and `SleepAggregator` continue to work — they just write into the Event model instead of the standalone `SleepNight` struct
- Future HealthKit types (heart rate, steps, workouts) follow the same pattern: define an Activity with `source = .healthKit(typeIdentifier)`, implement a fetcher, auto-populate Events

## Migration Path

### From Current Code

| Current | Becomes |
|---------|---------|
| `WaterEntry` (@Model) | `Event` where activity = "Drink Water" |
| `SleepNight` (struct) | `Event`(s) where activity.source = .healthKit("sleepAnalysis") |
| `WaterSettings.dailyGoal` | `Goal` on the default `Routine` |
| `WaterSettings.servingSize` | `Activity.defaultQuantity` |
| `DaySummary` | Computed from Events grouped by date + Goals from active Routine |

### Migration strategy

1. Create the new models (Activity, Event, Routine, Goal, RoutineSchedule) alongside existing ones
2. Write a one-time migration that converts existing WaterEntry records to Events
3. Create a default "Drink Water" Activity and a default Routine with the existing goal
4. Update ViewModels to use the new models
5. Remove `WaterEntry` once migration is verified
6. Update `SleepNight` aggregation to write into Events instead of standalone structs

## Open Questions

1. **Activity archiving**: When a user stops tracking an activity, should it be deleted (with events) or archived/hidden? Archiving preserves history.

Answer: No need to implement archiving for now.

2. **Routine management UI**: What's the flow for creating/editing routines and schedules? Options:
   - Settings screen lists saved routines; tap to edit goals; a "Schedule" section shows upcoming schedules
   - Today screen shows the active routine name with an option to assign a different routine to a date range
   - Both?

Answer: Both.

3. **HealthKit write-back**: Some HealthKit data types support writing (e.g., water intake can be written to HealthKit). Should manually logged events be written back? This would let Apple Health aggregate data from multiple apps.

Answer: No write-back for now.

4. **Goal progress visualization**: The "rings" concept from the kickoff — should each goal get its own ring? Or group by activity type? This is the gamification/motivation design question.

Answer: We'll work on that in a future session - make a note of it, but we don't need to design it now.

5. **Compound activities**: Some activities combine quantity AND duration (e.g., "run 3 miles in 30 minutes"). The current model supports this (an Event can have both `quantity` and `endTimestamp`), but goals would need to target either the quantity or the duration, not both. Is that sufficient?

Answer: Don't need to support compound activities for now.
