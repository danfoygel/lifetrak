# iOS Testing Guide for LifeTrak

This document covers the full testing strategy for LifeTrak: what to test, how to set each layer up, how Claude Code can inspect results and fix failures, and how to run tests in the cloud.

---

## Testing Layers at a Glance

| Layer | Framework | What It Covers |
|-------|-----------|---------------|
| Unit | Swift Testing (`@Test`) | ViewModels, pure functions, model logic |
| Integration | Swift Testing + SwiftData in-memory | Persistence queries, ViewModel ↔ model contracts |
| Stateful UI | XCUITest + launch arguments | App behavior given pre-seeded persistent state |
| Visual / Snapshot | swift-snapshot-testing | SwiftUI view rendering, regression detection |
| Performance | XCTest metrics | Render times, memory, slow query detection |

---

## Layer 1: Unit Tests (Swift Testing)

LifeTrak already uses the **Swift Testing** framework (the `@Test` macro, not XCTest). This is the right choice: it runs faster, has better failure messages, and supports parameterized tests.

### What belongs here

- **ViewModel logic**: calculations, filtering, aggregation — `TodayViewModel` (progress, streak, weekly data, settings), `HistoryViewModel` (grouping, CRUD, sorting)
- **Pure functions**: `SleepAggregator.aggregate(_:)`, date math helpers, `TimeInterval.sleepFormatted`
- **Model computed properties**: `SleepNight.efficiency`, `SleepNight.timeInBed`, `Event.duration`
- **Edge cases**: no data, goal of zero, overnight date boundaries, missed-day streak breaks, exact-midnight entries

### What does NOT belong here

- Anything that touches the SwiftData `ModelContainer` backed by disk (use Layer 2 instead)
- Anything that touches HealthKit's real `HKHealthStore`
- Anything that touches UIKit/SwiftUI rendering

### Running unit tests

```bash
# All unit tests
xcodebuild -scheme lifetrak \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:lifetrakTests test

# Single test class
xcodebuild -scheme lifetrak \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:'lifetrakTests/TodayViewModelTests' test

# Single test method
xcodebuild -scheme lifetrak \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:'lifetrakTests/TodayViewModelTests/testGoalProgressAt50Percent' test
```

### Enabling testability in ViewModels

Inject dependencies through the initializer so tests can substitute fakes:

```swift
// Production
let vm = TodayViewModel(modelContext: container.mainContext)

// Test — inject an in-memory context
let vm = TodayViewModel(modelContext: inMemoryContext)
```

---

## Layer 2: Stateful Testing (SwiftData In-Memory)

This layer tests that the app correctly stores, queries, and displays **pre-existing data**. It simulates "the user already has 30 days of entries — does the app handle them correctly?"

### Why this matters

SwiftData writes to SQLite on disk by default. Tests that hit the disk are:
- Slow (I/O)
- Non-repeatable (data accumulates across runs)
- Isolated to your machine

The solution is an **in-memory `ModelContainer`**, which is discarded when the test process ends.

### Setting up an in-memory container

The helper lives in `lifetrakTests/TestHelpers.swift` and is already implemented:

```swift
import SwiftData
import Foundation

@MainActor
enum TestHelpers {
    /// Creates a unique in-memory ModelContainer with all app models.
    /// Each call returns an isolated container — no cross-test contamination.
    static func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            "test-\(UUID().uuidString)",
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: Activity.self, Event.self, Routine.self, Goal.self,
            RoutineSchedule.self, WaterEntry.self,
            configurations: config
        )
    }
}
```

The UUID in the configuration name guarantees each container is fully isolated even when multiple tests run in parallel. Do **not** pass a static name — parallel tests sharing a name will crash on iOS 26.

Usage in a Swift Testing test:

```swift
@Test func totalOzAccumulatesCorrectly() throws {
    let container = try TestHelpers.makeContainer()
    let context = container.mainContext

    let activity = TestHelpers.makeWaterActivity(context: context)
    TestHelpers.makeDefaultRoutine(context: context, waterActivity: activity)
    context.insert(Event(activity: activity, quantity: 16))
    context.insert(Event(activity: activity, quantity: 8))
    try context.save()

    let vm = TodayViewModel(modelContext: context)
    #expect(vm.todayTotal == 24)
}
```

### Testing a realistic pre-populated state

For tests that need a believable data set (e.g., "30 days of history"), use `TestHelpers` to build the required graph:

```swift
@Test func streakBreaksOnMissedDay() throws {
    let container = try TestHelpers.makeContainer()
    let context = container.mainContext

    let activity = TestHelpers.makeWaterActivity(context: context)
    TestHelpers.makeDefaultRoutine(context: context, waterActivity: activity)

    // Meet goal today and 2 days ago — skip yesterday
    context.insert(Event(activity: activity, quantity: 64.0))
    let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
    context.insert(Event(activity: activity, timestamp: twoDaysAgo, quantity: 64.0))
    try context.save()

    let vm = TodayViewModel(modelContext: context)
    #expect(vm.currentStreak == 1) // only today counts
}
```

`TestHelpers` also provides `makeWaterActivity(context:)` and `makeDefaultRoutine(context:waterActivity:dailyGoal:)` to avoid repeating setup boilerplate.

---

## Layer 3: Stateful UI Tests (XCUITest + Launch Arguments)

XCUITest runs in a **separate process** from your app — it cannot access ViewModels or SwiftData directly. Instead, use **launch arguments** to signal the app to configure itself for testing.

### Step 1 — Detect test mode in the app

In `lifetrakApp.swift` (inside `#if DEBUG`):

```swift
import SwiftUI
import SwiftData

@main
struct LifetrakApp: App {
    let container: ModelContainer

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            // Use an in-memory store so tests start with a clean slate.
            // Then check for --seed-* arguments to pre-populate data.
            container = try! ModelContainer(
                for: WaterEntry.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            seedUITestData(container: container)
        } else {
            container = try! ModelContainer(for: WaterEntry.self)
        }
        #else
        container = try! ModelContainer(for: WaterEntry.self)
        #endif
    }

    var body: some Scene {
        WindowGroup { ContentView() }
            .modelContainer(container)
    }
}
```

### Step 2 — Implement the seed function

```swift
#if DEBUG
func seedUITestData(container: ModelContainer) {
    let args = ProcessInfo.processInfo.arguments

    if args.contains("--seed-water-history") {
        let context = container.mainContext
        let calendar = Calendar.current
        for dayOffset in 0..<30 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now)!
            context.insert(WaterEntry(timestamp: date, amount: 64))
        }
        try? context.save()
    }

    if args.contains("--seed-partial-day") {
        let context = container.mainContext
        context.insert(WaterEntry(timestamp: .now, amount: 24))
        try? context.save()
    }
    // Add more seed scenarios as needed
}
#endif
```

### Step 3 — Launch with state in your UI tests

```swift
import XCTest

final class TodayViewUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testProgressRingShowsCorrectFillWhenGoalIsHalfComplete() {
        app.launchArguments = ["--uitesting", "--seed-partial-day"]
        app.launch()

        // 24 oz of a 64 oz goal = 37.5%
        let ring = app.otherElements["progressRing"]
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        // Assert label shows the right numbers
        XCTAssertTrue(app.staticTexts["24 / 64 oz"].exists)
    }

    func testStreakDisplayAfter30ConsecutiveDays() {
        app.launchArguments = ["--uitesting", "--seed-water-history"]
        app.launch()
        XCTAssertTrue(app.staticTexts["30"].waitForExistence(timeout: 5))
    }
}
```

### Adding accessibility identifiers to SwiftUI views

XCUITest finds elements by accessibility identifier. Add them to every meaningful UI element:

```swift
// In your SwiftUI view
ProgressRingView(progress: vm.goalProgress)
    .accessibilityIdentifier("progressRing")

Text("\(vm.totalOzFormatted) / \(vm.goalOzFormatted) oz")
    .accessibilityIdentifier("progressLabel")
```

Keep identifiers in one shared enum to avoid typos and make refactoring safe:

```swift
// Shared between app and test targets
enum AXID {
    enum Today {
        static let progressRing = "progressRing"
        static let progressLabel = "progressLabel"
        static let logButton = "logWaterButton"
    }
    enum History {
        static let entryList = "historyEntryList"
        static let sleepCard = "sleepCard"
    }
}
```

---

## Layer 4: Visual / Snapshot Testing

Snapshot testing captures a **pixel rendering of a SwiftUI view** and saves it to disk. Future test runs re-render the view and diff against the saved reference. Any unintended visual change fails the test.

This catches regressions that logic tests miss: wrong colors, layout shifts, truncated labels, missing elements.

### Library: swift-snapshot-testing (Point-Free)

This is the standard snapshot testing library for Swift. It supports SwiftUI views directly, integrates with Swift Testing (v1.17.0+), and works headlessly in CI.

**GitHub**: https://github.com/pointfreeco/swift-snapshot-testing

### Installation

Add to the test target in `lifetrak.xcodeproj` via Xcode's package manager:

1. File → Add Package Dependencies
2. URL: `https://github.com/pointfreeco/swift-snapshot-testing`
3. Version: `1.17.0` or higher (required for Swift Testing support)
4. Add `SnapshotTesting` to the **lifetrakTests** target only

### Writing a snapshot test

```swift
import SnapshotTesting
import SwiftUI
import Testing

@Suite("Today View Snapshots")
struct TodayViewSnapshotTests {

    @Test func rendersCorrectlyAtZeroProgress() {
        let view = TodayView(viewModel: makeFakeViewModel(oz: 0, goal: 64))
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    @Test func rendersCorrectlyAtFullProgress() {
        let view = TodayView(viewModel: makeFakeViewModel(oz: 64, goal: 64))
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    @Test func progressLabelFormatsOzCorrectly() {
        let view = TodayView(viewModel: makeFakeViewModel(oz: 24.5, goal: 64))
        // Text-only snapshot — much faster, no pixel comparison
        assertSnapshot(of: view, as: .accessibilityDescription)
    }
}
```

### Recording reference snapshots

The first time a snapshot test runs, it **records** the reference image and saves it to `__Snapshots__/` alongside the test file. Subsequent runs compare against it.

To re-record (e.g., after an intentional design change):

```swift
// Temporarily set record mode — remove before committing
isRecording = true

// Or per-test:
assertSnapshot(of: view, as: .image(...), record: true)
```

**Important**: Snapshot images must be recorded on the same simulator type used in CI, or the pixel comparison will always fail due to rendering differences between device families. Pick one device config (e.g., iPhone 16 @ standard scale) and stick to it.

### Commit snapshots to git

The `__Snapshots__/` directory should be committed. This is intentional — the reference images are the "expected" output. Snapshot diffs in PRs are meaningful visual review artifacts.

### Diffing failures

When a snapshot test fails, the library writes three files next to the reference:
- `testName.failure.png` — what the view actually looks like
- `testName.reference.png` — what it was expected to look like
- `testName.diff.png` — highlighted pixel differences

Claude Code can read these image files directly to understand what changed visually.

---

## How Claude Code Inspects Test Results

### Using XcodeBuildMCP

With `getsentry/XcodeBuildMCP` installed, Claude Code has direct access to:
- Build and run tests without the Xcode IDE open
- Launch and manage simulators
- Capture screenshots of the simulator at any point
- Read build and test output through MCP tools

**Known limitation**: XcodeBuildMCP sometimes truncates test output when test suites are large. As a workaround, run specific failing test classes rather than the full suite to get complete output.

### Using xcresulttool (the reliable fallback)

Every `xcodebuild test` run produces an `.xcresult` bundle in Derived Data. This bundle contains complete, structured test results even when MCP output is truncated. Claude Code can parse it directly:

```bash
# Find the most recent result bundle
RESULT=$(find ~/Library/Developer/Xcode/DerivedData -name "*.xcresult" \
  -newer /tmp/last_test_run 2>/dev/null | head -1)

# Get a test summary
xcrun xcresulttool get test-results summary --path "$RESULT" --compact

# List all tests and their pass/fail status
xcrun xcresulttool get test-results tests --path "$RESULT" --compact

# Get details for a specific failing test
xcrun xcresulttool get test-results test-details \
  --path "$RESULT" \
  --test-id 'TodayViewModelTests/testGoalProgressAt50Percent()' \
  --compact

# Export failure screenshots (from UI tests or snapshot tests)
xcrun xcresulttool export attachments \
  --path "$RESULT" \
  --output-path ./test-artifacts \
  --only-failures
```

The `--compact` flag produces JSON output that fits more cleanly in Claude's context window.

### Recommended workflow for Claude Code

1. **Run tests** via XcodeBuildMCP or `xcodebuild`
2. **If output is truncated**, run `xcresulttool get test-results summary` to get the full failure list
3. **For each failing test**, run `xcresulttool get test-results test-details` to get the exact assertion failure
4. **For snapshot failures**, run `xcresulttool export attachments --only-failures` and read the diff images
5. **Fix the code**, re-run only the failing test class to confirm
6. **Run the full suite** once all targeted failures are resolved

---

## What to Install

### Required (you already have these)
- **Xcode** — provides `xcodebuild`, `xcrun`, `xcresulttool`, simulators
- **getsentry/XcodeBuildMCP** — MCP server giving Claude Code access to Xcode toolchain

### Required for visual testing
- **swift-snapshot-testing** — add via Xcode's package manager (URL above)

### Optional but recommended

**xcresultparser** — converts `.xcresult` bundles to readable formats (HTML, JUnit XML, Markdown):
```bash
brew install a7ex/homebrew-formulae/xcresultparser
```

This is useful for generating human-readable CI reports from raw result bundles.

**xcparse** — extracts screenshots and attachments from `.xcresult` bundles:
```bash
brew install chargepoint/xcparse/xcparse
xcparse screenshots MyResults.xcresult ./screenshots
```

**Fastlane** — if you want to automate multi-step workflows (build → test → upload to TestFlight):
```bash
brew install fastlane
```
Fastlane is optional for a personal project but useful if you want scripted release automation.

---

## Cloud CI Options

### Option A: GitHub Actions with macOS Runners (Recommended)

Because this is a **public repository**, GitHub Actions macOS runners are **completely free with no minute cap**. The 2,000 min/month limit and the 10× minute multiplier only apply to private repos. This makes GitHub Actions the strongest option here — no cost, no account beyond what you already have, and straightforward YAML configuration.

**Key constraints**:
- New iOS SDK versions (like iOS 26) have a lag before appearing on GitHub-hosted runners
- You must pin the simulator name to what's actually available on the runner (check with `xcrun simctl list devices available`)
- Code signing must be disabled for tests (or configured via secrets)

The live workflow is `.github/workflows/test.yml`. Key points from the current implementation:

```yaml
name: Test
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  changes:        # skip CI when only docs change
    runs-on: ubuntu-latest
    outputs:
      src: ${{ steps.filter.outputs.src }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            src:
              - 'lifetrak/**'
              - 'lifetrakTests/**'
              - 'lifetrak.xcodeproj/**'
              - '.github/workflows/test.yml'

  test:
    needs: changes
    if: needs.changes.outputs.src == 'true'
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: |
          XCODE_PATH=$(ls -d /Applications/Xcode*.app | sort -V | tail -1)
          sudo xcode-select -s "$XCODE_PATH/Contents/Developer"
      - name: Cache SDK stat cache
        uses: actions/cache@v4
        with:
          path: ~/Library/Developer/Xcode/DerivedData/SDKStatCaches.noindex
          key: ${{ runner.os }}-sdkstatcache-...
      - name: Test
        run: |
          xcodebuild -scheme lifetrak \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
            -only-testing:lifetrakTests \
            -skip-testing:lifetrakUITests \
            SWIFT_ENABLE_CODE_COVERAGE=NO \
            COMPILER_INDEX_STORE_ENABLE=NO \
            CODE_SIGNING_ALLOWED=NO \
            test
      - name: Test summary     # always runs; xcresulttool JSON in the log
        if: always()
        run: |
          RESULT=$(find ~/Library/Developer/Xcode/DerivedData -name "*.xcresult" | sort -t/ -k1,1 | tail -1)
          [ -n "$RESULT" ] && xcrun xcresulttool get test-results summary --path "$RESULT" --compact
      - name: Upload test results
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-results-${{ github.run_id }}
          path: ~/Library/Developer/Xcode/DerivedData/**/Logs/Test/*.xcresult
          retention-days: 7
```

**Note on snapshot tests in CI**: Snapshot tests are pixel-exact. If your reference snapshots were recorded on a local Apple Silicon Mac and CI uses an Intel runner (or a different simulator scale), the tests will fail due to rendering differences. Solution: record reference snapshots on the CI machine by running with `isRecording = true` in a one-time job, then commit the results.

### Option B: Xcode Cloud

Apple's first-party CI service, integrated directly into Xcode and App Store Connect.

**Cost**: 25 compute hours/month included with an Apple Developer Program membership ($99/year). Since GitHub Actions is already free for this public repo, Xcode Cloud is only worth considering if you specifically want its Apple-native integrations.

**Advantages over GitHub Actions**:
- Zero code-signing setup — Apple handles certificates automatically
- Results appear directly inside Xcode
- TestFlight integration built in

**Disadvantages**:
- Costs $99/year (the Developer Program membership) to access
- Less flexible than YAML-based workflows
- New Xcode/SDK versions can lag on hosted runners just like GitHub Actions

**To set up**: In Xcode → Product → Xcode Cloud → Create Workflow.

### Option C: Self-Hosted Runner (Mac Mini)

If you have a spare Mac, you can register it as a GitHub Actions self-hosted runner. This gives you:
- The exact simulator versions you have locally
- Apple Silicon performance
- No code-signing complications

Since GitHub Actions is already free for this public repo, a self-hosted runner is only useful if the hosted runners don't yet support the iOS SDK version you need (e.g., iOS 26 before Apple updates the runner images).

### What cannot run in cloud CI

Some test types fundamentally require a physical device and cannot run in any cloud CI environment:

| Test type | Cloud CI? | Why not |
|-----------|-----------|---------|
| Unit tests | ✅ Yes | Simulator is sufficient |
| SwiftData in-memory tests | ✅ Yes | Simulator is sufficient |
| UI tests (launch arg seeding) | ✅ Yes | Simulator is sufficient |
| Snapshot tests | ✅ Yes (with care) | Must match simulator type |
| HealthKit with real data | ❌ No | Requires real device + Apple Watch |
| Push notification receipt | ❌ No | APNs does not target simulators |
| Watch app testing | ❌ No | Requires physical Watch |

For HealthKit-dependent flows, the testing strategy is: mock the `HealthKitServiceProtocol` in all automated tests, and validate real HealthKit queries manually on a device when the service implementation changes.

---

## Recommended Testing Setup for This Project

Given the current stack (SwiftUI + SwiftData, Swift Testing, XCUITest), here is the recommended priority order:

1. **Set up swift-snapshot-testing now** — before views grow complex. Snapshot tests are most valuable when added early; retrofitting them to a mature view requires recording many states at once.

2. **Use in-memory SwiftData containers in all integration tests** — never let unit or integration tests touch the disk store.

3. **Add `--uitesting` + `--seed-*` launch argument handling** as soon as the first real view lands — this is the infrastructure that lets all future UI tests be independent and repeatable.

4. **Use GitHub Actions for CI** — because the repo is public, macOS runners are free with no minute cap. Set up a workflow that runs `lifetrakTests` on every push to `main`. Xcode Cloud is not necessary here unless you specifically want its TestFlight or Xcode-native integrations.

5. **Exclude UI tests from CI by default** — UI tests are slow and fragile in CI environments. Run them locally before merging. If you later want CI UI tests, add them as a separate, less-frequent scheduled workflow.

6. **Use `xcresulttool` as the authoritative source of truth** for test results when working with Claude Code — it provides complete structured output regardless of MCP truncation issues.

All six recommendations are implemented. See the Implementation Plan below for details.

---

## Current Test Coverage (as of March 2026)

### Unit / Integration Tests (`lifetrakTests`)

All tests live in `AllTests.swift` as a single `@MainActor @Suite(.serialized)` struct. Serialization prevents concurrent `ModelContainer` creation, which crashes on iOS 26 beta.

| Area | Test count | Key scenarios |
|------|-----------|--------------|
| `Activity` model | 5 | Create, defaults, manual/HealthKit sources, duration tracking |
| `Event` model | 9 | Create, timestamp, delete, update, duration computed property, today-only filtering |
| `Routine` / `Goal` model | 4 | Create, goals relationship, frequency/duration goals, snapshot creation |
| `RoutineSchedule` model | 2 | Create, date-range resolution |
| `TodayViewModel` — basic | 12 | Initial state, auto-defaults, log water, progress, goal met, excludes yesterday, custom goal/serving size, display strings |
| `TodayViewModel` — weekly data | 4 | Always 7 entries, includes today, includes past days, excludes >7 days |
| `TodayViewModel` — streak | 5 | Zero, one day, consecutive, breaks on missed day, starts from yesterday |
| `TodayViewModel` — date edges | 2 | Exact midnight belongs to that day, one second before excluded |
| `TodayViewModel` — settings | 2 | Round-trip, fractional values |
| `HistoryViewModel` | 10 | Initially empty, groups by day, day total, newest-first sort, add/delete/update entry |
| `SleepNight` model | 3 | `timeInBed`, `efficiency`, zero-time-in-bed edge case |
| `TimeInterval.sleepFormatted` | 4 | h+m, minutes-only, zero, exact hours |
| `SleepAggregator` | 6+ | Empty input, single night, wake-up-day assignment, stage aggregation, multi-night, inBed detection |
| **Snapshot tests** | 4 | `TodayView`: empty state, partial progress, goal met, with streak |

### UI Tests (`lifetrakUITests`)

Three tests in `TodayViewUITests`. Run locally only (excluded from CI):

| Test | Seed arg |
|------|---------|
| `testLogButtonExistsOnLaunch` | (none) |
| `testProgressLabelShowsPartialProgress` | `--seed-partial-day` |
| `testStreakLabelShowsAfter30Days` | `--seed-water-history` |

### HealthKit mock

`MockHealthKitService` implements `HealthKitServiceProtocol` with configurable `mockSleepNights`, `shouldThrowOnAuth`, and `shouldThrowOnFetch` flags. It is available to any test that injects it but is not yet used in `AllTests`.

---

## Remaining Recommendations

The original six recommendations are all implemented. The areas below represent the next natural testing investments as the app grows.

### 1. Snapshot tests for `HistoryView` and `SleepCard`

`SnapshotTests.swift` currently covers only `TodayView`. As `HistoryView` and the sleep card are fleshed out, add snapshot tests for their key states:

- `HistoryView`: empty state, one-day summary, multi-day list
- `SleepCard`: standard night data, no-data / HealthKit unavailable

Follow the same `makeVM` helper pattern and `named: "1"` fix used in the existing snapshot suite.

### 2. `HistoryViewModel` tests using `MockHealthKitService`

The mock is built; it just needs wiring into tests. When `HistoryViewModel` (or a future `SleepViewModel`) gains a `HealthKitServiceProtocol` dependency, add tests covering:

- Successful sleep fetch populates the view model
- Authorization failure surfaces an error state
- Query failure surfaces an error state

Use constructor injection (`HistoryViewModel(modelContext:healthKitService:)`) to keep it testable without touching the real HealthKit store.

### 3. UI tests for `HistoryView`

The UI test infrastructure (`--uitesting`, `UITestSeeder`, `AXID`) is ready to extend. Useful next tests:

- Swipe-to-delete removes an entry
- Tap an entry to edit it; confirm the updated value appears
- History is empty when launched without seed data

Add the required `AXID.History.*` constants to `AccessibilityIdentifiers.swift` and the corresponding `.accessibilityIdentifier(...)` calls to `HistoryView` before writing these tests.

### 4. Parameterized streak tests

Swift Testing supports `@Test(arguments:)` for data-driven tests. The streak logic has several boundary cases that are currently written as individual tests. Consolidating them into a parameterized table would reduce boilerplate and make it easy to add new cases:

```swift
@Test(arguments: [
    (daysBack: [0, 1, 2], expectedStreak: 3),
    (daysBack: [0, 2],    expectedStreak: 1),   // gap on day 1
    (daysBack: [1, 2],    expectedStreak: 2),   // today not met
])
func todayVM_streakScenarios(daysBack: [Int], expectedStreak: Int) throws { … }
```

### 5. Performance baseline (optional)

If the entry list or weekly chart becomes noticeably slow with large datasets, add an `XCTest` performance test to catch regressions:

```swift
func testHistoryViewModelWith500Days() {
    measure {
        // seed 500 days, init HistoryViewModel, read daySummaries
    }
}
```

Performance tests require `XCTestCase` (not Swift Testing `@Test`). They can live in a separate `PerformanceTests.swift` file in `lifetrakTests` without affecting the Swift Testing suite.

---

## Implementation Plan

This section documents how the six recommendations above were implemented.

### Status of each recommendation

| # | Recommendation | Status |
|---|---------------|--------|
| 1 | swift-snapshot-testing | **Done** — `SnapshotTesting` 1.19.1 via SPM; `SnapshotTests.swift` with 4 tests; reference PNGs in `__Snapshots__/` |
| 2 | In-memory SwiftData containers in all integration tests | **Done** — `TestHelpers.makeContainer()` (UUID-named, all models) used in every test |
| 3 | `--uitesting` + `--seed-*` launch argument handling | **Done** — `UITestSeeder`, `AccessibilityIdentifiers`, 3 UI tests (PR #12) |
| 4 | GitHub Actions CI | **Done** — `macos-15` runner, auto-detect Xcode, `CODE_SIGNING_ALLOWED=NO`, artifact upload on failure |
| 5 | Exclude UI tests from CI by default | **Done** — workflow uses `-only-testing:lifetrakTests -skip-testing:lifetrakUITests` |
| 6 | `xcresulttool` as authoritative source of truth | **Done** — `Test summary` step (`if: always()`) prints compact JSON after every run |

---

### Step 1 — `--uitesting` + `--seed-*` launch argument handling (Rec 3) ✅ Done (PR #12)

#### `lifetrak/AccessibilityIdentifiers.swift` — create

A shared `AXID` enum compiled into both the app target and the test target. Defines a string constant for every meaningful interactive or data-display element in `TodayView`:

```swift
// Shared between app and test targets — add to both in target membership
enum AXID {
    enum Today {
        static let progressRing  = "progressRing"
        static let progressLabel = "progressLabel"
        static let logButton     = "logWaterButton"
        static let streakLabel   = "streakLabel"
        static let weeklyChart   = "weeklyChart"
        static let entryList     = "entryList"
    }
}
```

#### `lifetrak/UITestSeeder.swift` — create (`#if DEBUG` only)

A single `seed(container:)` function that reads `ProcessInfo.processInfo.arguments` and dispatches to scenario helpers:

```swift
#if DEBUG
enum UITestSeeder {
    static func seed(container: ModelContainer) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--seed-partial-day")    { seedPartialDay(container) }
        if args.contains("--seed-goal-met")        { seedGoalMet(container) }
        if args.contains("--seed-water-history")   { seedWaterHistory(container) }
    }

    // 3×8 oz today → 24 oz of 64 oz goal (37.5 %)
    private static func seedPartialDay(_ container: ModelContainer) { ... }

    // 8×8 oz today → exactly 64 oz, goal met
    private static func seedGoalMet(_ container: ModelContainer) { ... }

    // 64 oz/day for the past 30 days → 30-day streak
    private static func seedWaterHistory(_ container: ModelContainer) { ... }
}
#endif
```

Each helper must: insert a "Drink Water" `Activity` + default `Routine` + `Goal` (64 oz), then insert the appropriate `Event` records, then call `try? context.save()`.

#### `lifetrak/lifetrakApp.swift` — modify

Wrap the `ModelContainer` construction in a `#if DEBUG` check. When `--uitesting` is present, build the container with `isStoredInMemoryOnly: true` and call `UITestSeeder.seed(container:)` immediately after:

```swift
init() {
    let schema = Schema([Activity.self, Event.self, Routine.self,
                         Goal.self, RoutineSchedule.self, WaterEntry.self])
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("--uitesting") {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        sharedModelContainer = try! ModelContainer(for: schema, configurations: config)
        UITestSeeder.seed(container: sharedModelContainer)
        return
    }
    #endif
    // Production path — unchanged
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    sharedModelContainer = try! ModelContainer(for: schema, configurations: config)
}
```

#### `lifetrak/TodayView.swift` — modify

Two changes:

1. **Add accessibility identifiers** to every element named in `AXID.Today`:
   - Progress ring `ZStack` → `.accessibilityIdentifier(AXID.Today.progressRing)`
   - Progress/goal `Text` → `.accessibilityIdentifier(AXID.Today.progressLabel)`
   - Log `Button` → `.accessibilityIdentifier(AXID.Today.logButton)`
   - Streak `HStack` → `.accessibilityIdentifier(AXID.Today.streakLabel)`
   - Weekly chart `VStack` → `.accessibilityIdentifier(AXID.Today.weeklyChart)`
   - Entries `VStack` → `.accessibilityIdentifier(AXID.Today.entryList)`

2. **Add an optional injected `viewModel` parameter** to `TodayView.init` so snapshot tests can pass a pre-built VM directly (see Step 2):
   ```swift
   // Keep the existing @State var for production; allow override for tests
   init(viewModel: TodayViewModel? = nil) {
       _viewModel = State(initialValue: viewModel)
   }
   ```

#### `lifetrakUITests/lifetrakUITests.swift` — rewrite

Replace the empty stub with a base class + three concrete tests:

```swift
class LifetrakUITestCase: XCTestCase {
    var app: XCUIApplication!
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }
    func launch(args: [String] = []) {
        app.launchArguments = ["--uitesting"] + args
        app.launch()
    }
}

final class TodayViewUITests: LifetrakUITestCase {

    func testLogButtonExistsOnLaunch() {
        launch()
        XCTAssertTrue(app.buttons[AXID.Today.logButton].waitForExistence(timeout: 5))
    }

    func testProgressLabelShowsPartialProgress() {
        launch(args: ["--seed-partial-day"])
        // 24 oz of 64 oz goal
        XCTAssertTrue(app.staticTexts["24"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["of 64 oz"].exists)
    }

    func testStreakLabelShowsAfter30Days() {
        launch(args: ["--seed-water-history"])
        let streak = app.otherElements[AXID.Today.streakLabel]
        XCTAssertTrue(streak.waitForExistence(timeout: 5))
        XCTAssertTrue(streak.staticTexts["30-day streak"].exists)
    }
}
```

---

### Step 2 — swift-snapshot-testing (Rec 1) ✅ DONE

**Implementation notes:**
- `SnapshotTesting` 1.19.1 added via SPM by editing `project.pbxproj` directly (no manual Xcode step needed)
- `Package.resolved` generated via `xcodebuild -resolvePackageDependencies`
- Used `.iPhone13Pro` device config (1.19.1 does not include `.iPhone16Pro`; update when the library adds it)
- `precision: 0.99` used on all tests — absorbs sub-pixel anti-aliasing differences between iOS 26.2 (CI, macos-15 runner) and iOS 26.3.x (local). Without this, the partial-arc in the progress ring causes ~0.3% pixel difference that would fail a strict comparison.
- Reference snapshots recorded with `-parallel-testing-enabled NO` to prevent race conditions during initial recording; subsequent runs work normally
- 4 reference PNGs committed in `lifetrakTests/__Snapshots__/SnapshotTests/` — one per test, using the `named: "1"` fix (see "Dual runner" note below)

**Dual runner (resolved — why snapshots use `named: "1"`):**
xcodebuild runs Swift Testing suites through two runners simultaneously: the native Swift Testing runner and an XCTest bridge. Each runner independently calls `assertSnapshot`, which previously caused each `@Test` function to record two reference files (`.1.png` and `.2.png`) because `assertSnapshot` auto-increments a counter per test name. The fix is to pass `named: "1"` explicitly to `assertSnapshot`. The `named:` parameter replaces the auto-increment counter, so both runners write to / compare against the same file (e.g. `rendersEmptyState.1.png`). Only 4 reference PNGs are needed — one per test.

#### `lifetrakTests/SnapshotTests.swift` — created

A `@MainActor @Suite(.serialized)` struct with four tests. Each test builds a `TodayViewModel` from an in-memory container pre-seeded to a specific state, constructs a `TodayView(viewModel: vm)` using the injected-VM init added in Step 1, and calls `assertSnapshot`:

```swift
import SnapshotTesting
import SwiftUI
import SwiftData
import Testing
@testable import lifetrak

@MainActor
@Suite("TodayView Snapshots", .serialized)
struct SnapshotTests {

    @Test func rendersEmptyState() throws {
        let (vm, container) = try makeVM(oz: 0)
        assertSnapshot(
            of: TodayView(viewModel: vm).modelContainer(container),
            as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro)),
            named: "1"
        )
    }

    // ... rendersPartialProgress, rendersGoalMet, rendersWithStreak
}
```

A private `makeVM(oz:priorDaysMeetingGoal:)` helper creates the in-memory container, inserts the water Activity + Routine + Goal, inserts the appropriate Event records, saves, and returns `(TodayViewModel, ModelContainer)`. The `ModelContainer` is passed to `.modelContainer()` on the view because `TodayView` uses `@Query` internally which requires a container in the environment.

**First run records reference images** into `lifetrakTests/__Snapshots__/SnapshotTests/`. Commit this directory (one `.1.png` per test, 4 files total). All subsequent runs diff against those images.

**Important**: reference snapshots must be recorded on the same simulator model used in CI (iPhone 16 Pro, as configured in the workflow). If you record locally on a different device, snapshot tests will fail in CI.

---

### Step 3 — GitHub Actions improvements (Recs 4 & 6) ✅ Done

**Implementation notes:**
- `CODE_SIGNING_ALLOWED=NO` added to the `Test` step — required on GitHub-hosted runners which have no signing certificates; without it the build fails at the sign phase
- `Test summary` step added with `if: always()` — runs `xcrun xcresulttool get test-results summary --compact` after every run (pass or fail) and prints structured JSON to the workflow log; this is the authoritative source of truth for test results regardless of MCP truncation
- `Upload test results` artifact step added with `if: failure()` — uploads the `.xcresult` bundle with a 7-day retention window so failures are fully debuggable from the Actions UI without needing a local re-run
- Comment block added above the `Test` step explaining that UI tests are excluded and how to run them locally

#### `.github/workflows/test.yml` — modify

Four changes to the existing file:

**1. Add `CODE_SIGNING_ALLOWED=NO`** to both the Build and Test steps. Without this, the build fails on GitHub-hosted runners which have no signing certificates:
```yaml
- name: Build
  run: |
    xcodebuild -scheme lifetrak \
      -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
      CODE_SIGNING_ALLOWED=NO \
      build

- name: Test
  run: |
    xcodebuild -scheme lifetrak \
      -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
      -only-testing:lifetrakTests \
      CODE_SIGNING_ALLOWED=NO \
      test
```

**2. Add a xcresulttool summary step** that runs unconditionally after tests (pass or fail), printing a compact JSON summary to the workflow log:
```yaml
- name: Test summary
  if: always()
  run: |
    RESULT=$(find ~/Library/Developer/Xcode/DerivedData \
      -name "*.xcresult" | sort -t/ -k1,1 | tail -1)
    if [ -n "$RESULT" ]; then
      xcrun xcresulttool get test-results summary \
        --path "$RESULT" --compact
    fi
```

**3. Add artifact upload on failure** so the full `.xcresult` bundle is downloadable from the Actions UI:
```yaml
- name: Upload test results
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: test-results-${{ github.run_id }}
    path: ~/Library/Developer/Xcode/DerivedData/**/Logs/Test/*.xcresult
    retention-days: 7
```

**4. Add a comment block** at the top of the file explaining why UI tests are excluded and how to run them locally:
```yaml
# UI tests (lifetrakUITests) are intentionally excluded from this workflow.
# They are slow, require a booted simulator, and are fragile in CI.
# Run them locally before merging:
#   xcodebuild -scheme lifetrak \
#     -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
#     -only-testing:lifetrakUITests test
```

---

### File change summary

| File | Action | Rec |
|------|--------|-----|
| `lifetrak/AccessibilityIdentifiers.swift` | Create | 3 |
| `lifetrak/UITestSeeder.swift` | Create | 3 |
| `lifetrak/lifetrakApp.swift` | Modify — add `--uitesting` branch | 3 |
| `lifetrak/TodayView.swift` | Modify — add AXID modifiers + injected-VM init | 3, 1 |
| `lifetrakUITests/lifetrakUITests.swift` | Rewrite | 3 |
| `lifetrakTests/SnapshotTests.swift` | Create (after manual SPM step) | 1 |
| `.github/workflows/test.yml` | Modify — signing flag, xcresulttool, artifact upload | 4, 6 |

The only step requiring Xcode GUI is adding the `swift-snapshot-testing` SPM package. Every other change is a pure Swift or YAML edit.

---

### Dual runner — duplicate reference files (resolved)

**Status: fixed** — each test now produces exactly one reference PNG.

#### What happened

Each `@Test` function in `SnapshotTests` previously produced two identical reference PNG files — e.g. `rendersGoalMet.1.png` and `rendersGoalMet.2.png`. Both had to be committed or CI would fail.

#### Why it happened

When `xcodebuild test` runs a target containing Swift Testing `@Test` functions, it launches two runners in the same process:

1. **Native Swift Testing runner** — the real runner, designed for `@Test` functions
2. **XCTest bridge** — a compatibility shim that re-exposes every `@Test` function as an `XCTestCase` method so xcodebuild's reporting pipeline can discover and track results

Both runners execute the test body. `assertSnapshot` auto-increments a counter per test name to pick a filename. First call → `.1.png`, second call → `.2.png`.

#### Fix: pass `named: "1"` explicitly

Passing `named: "1"` to `assertSnapshot` replaces the auto-increment counter with an explicit identifier. Both runners resolve to the same filename (e.g. `rendersEmptyState.1.png`), so only one reference file per test is needed. The `.2.png` files were deleted.

```swift
assertSnapshot(
    of: TodayView(viewModel: vm).modelContainer(container),
    as: .image(precision: 0.99, layout: .device(config: .iPhone13Pro)),
    named: "1"
)
```

#### What was tried and didn't work (historical)

Converting `SnapshotTests` from Swift Testing (`@Suite`/`@Test`) to `XCTestCase` eliminates the bridge runner, giving only one invocation per test. However, `XCTestCase` + `@MainActor` renders SwiftUI views differently from Swift Testing + `@MainActor` — approximately 4–5% pixel difference across all four tests. Because `@MainActor` cannot be removed (SwiftData `ModelContext` requires main-actor isolation), this approach produced four new failures and was reverted.

---

## References

- [pointfreeco/swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
- [Swift Testing support for SnapshotTesting (Point-Free blog)](https://www.pointfree.co/blog/posts/146-swift-testing-support-for-snapshottesting)
- [HackingWithSwift — Unit Tests for SwiftData](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-write-unit-tests-for-your-swiftdata-code)
- [HackingWithSwift — UI Tests for SwiftData](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-write-ui-tests-for-your-swiftdata-code)
- [Delasign — UITest with In-Memory SwiftData](https://www.delasign.com/blog/how-to-create-a-uitest-that-uses-swiftdata-thats-only-stored-in-memory/)
- [getsentry/XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP)
- [xcresulttool man page](https://keith.github.io/xcode-man-pages/xcresulttool.1.html)
- [a7ex/xcresultparser](https://github.com/a7ex/xcresultparser)
- [Xcode Cloud — Apple Developer](https://developer.apple.com/xcode-cloud/)
- [GitHub Actions iOS Testing Guide (Bright Inventions)](https://brightinventions.pl/blog/ios-build-run-tests-github-actions/)
- [XCUITest SwiftUI best practices (swiftyplace)](https://www.swiftyplace.com/blog/xcuitest-ui-testing-swiftui)
