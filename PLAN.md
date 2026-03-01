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
1. Generalize `WaterEntry` → generic `TrackerEntry` + `TrackerDefinition`
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

	