# LifeTrak Testing Guide

## Test layers

| Layer | Framework | What it covers |
|-------|-----------|---------------|
| Unit / Integration | Swift Testing (`@Test`) | ViewModels, model logic, SwiftData in-memory |
| Stateful UI | XCUITest + launch args | App behavior with pre-seeded state |
| Snapshot | swift-snapshot-testing | SwiftUI view rendering regression |
| Performance | XCTest metrics | Not yet implemented |

## Running tests

```bash
# All unit/integration tests (what CI runs)
xcodebuild -scheme lifetrak \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:lifetrakTests test

# Single test
xcodebuild -scheme lifetrak \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:'lifetrakTests/AllTests/todayVM_streak' test

# UI tests (run locally only — excluded from CI)
xcodebuild -scheme lifetrak \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:lifetrakUITests test
```

## Key patterns

### In-memory SwiftData containers

All tests use `TestHelpers.makeContainer()` — never let tests touch the disk store.

```swift
@Test func example() throws {
    let container = try TestHelpers.makeContainer()
    let context = container.mainContext

    let activity = TestHelpers.makeWaterActivity(context: context)
    TestHelpers.makeDefaultRoutine(context: context, waterActivity: activity)
    context.insert(Event(activity: activity, quantity: 8.0))
    try context.save()

    let vm = TodayViewModel(modelContext: context)
    #expect(vm.todayTotal == 8.0)
}
```

`TestHelpers` also provides `makeWaterActivity(context:)` and `makeDefaultRoutine(context:waterActivity:dailyGoal:)`.

**Important**: Each container gets a UUID name (`"test-\(UUID().uuidString)"`). Never use a static name — parallel tests sharing one crash on iOS 26.

All tests live in `AllTests.swift` as a single `@MainActor @Suite(.serialized)` struct. Serialization prevents concurrent container creation, which also crashes on iOS 26 beta.

### UI test seeding

The app checks `--uitesting` at launch and switches to an in-memory store. Seed args pre-populate it:

```swift
app.launchArguments = ["--uitesting", "--seed-partial-day"]
app.launch()
```

Available seeds (implemented in `UITestSeeder.swift`):
- `--seed-partial-day` — 3×8 oz today (24/64 oz, 37.5%)
- `--seed-goal-met` — 8×8 oz today (64/64 oz)
- `--seed-water-history` — 64 oz/day for 30 days (30-day streak)

Accessibility identifiers are defined in `AccessibilityIdentifiers.swift`. Namespaces:
- `AXID.Today.*` — progress ring, log button, streak label, weekly chart, entry list
- `AXID.History.*` — `addButton`, `entryList`, `entryRow`

### Snapshot tests

`SnapshotTesting` 1.19.1 via SPM. `SnapshotTests.swift` contains three suites:

| Suite | Tests | Reference PNGs |
|-------|-------|----------------|
| `TodayView Snapshots` | 4 (empty, partial, goal met, streak) | `__Snapshots__/SnapshotTests/` |
| `HistoryView Snapshots` | 3 (empty, with entries, with sleep+water) | `__Snapshots__/HistoryViewSnapshotTests/` |
| `SleepCard Snapshots` | 2 (with stages, without stages) | `__Snapshots__/SleepCardSnapshotTests/` |

`HistoryView` accepts an optional `viewModel` parameter for injection (mirrors `TodayView`), allowing snapshot tests to pre-load data without relying on `.onAppear`.

Two quirks to know:

1. **`named: "1"` is required.** xcodebuild runs Swift Testing suites through two runners simultaneously (native + XCTest bridge), so `assertSnapshot` gets called twice per test. Passing `named: "1"` pins both to the same filename.

2. **`precision: 0.99`** absorbs sub-pixel anti-aliasing differences between iOS 26.2 (CI) and 26.3.x (local).

To re-record after an intentional design change:
```swift
assertSnapshot(..., record: true)  // remove before committing
```

Snapshots must be recorded on an iPhone 16 Pro simulator (same as CI) or comparisons will fail.

## CI

Workflow: `.github/workflows/test.yml`. Runs on `macos-15`, auto-selects the newest Xcode. Skips CI when only non-source files change (via `dorny/paths-filter`).

Key flags: `CODE_SIGNING_ALLOWED=NO`, `SWIFT_ENABLE_CODE_COVERAGE=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`.

**Snapshot bootstrap**: The test step runs `xcodebuild` twice (`RUN_TESTS || RUN_TESTS`). SnapshotTesting's default `record: .missing` mode records new reference PNGs to disk on the first run (and fails), then the second run compares against them and passes. Real failures (logic errors, comparison mismatches against committed PNGs) fail on both runs.

A `Test summary` step runs `xcresulttool get test-results summary --compact` after every run (pass or fail). On failure, the full `.xcresult` bundle is uploaded as an artifact (7-day retention).

UI tests are excluded from CI (`-skip-testing:lifetrakUITests`). Run them locally before merging.

## How Claude Code inspects failures

```bash
# Find the most recent result bundle
RESULT=$(find ~/Library/Developer/Xcode/DerivedData -name "*.xcresult" | sort -t/ -k1,1 | tail -1)

# Summary of all tests
xcrun xcresulttool get test-results summary --path "$RESULT" --compact

# Details for one failing test
xcrun xcresulttool get test-results test-details \
  --path "$RESULT" \
  --test-id 'AllTests/todayVM_streak(skipsYesterday)' \
  --compact

# Export failure images (snapshot diffs, UI test screenshots)
xcrun xcresulttool export attachments \
  --path "$RESULT" --output-path ./test-artifacts --only-failures
```

Use `xcresulttool` over MCP output when the test suite is large — MCP truncates; xcresulttool does not.

## Current coverage (March 2026)

| Area | Tests |
|------|-------|
| `Activity` model | 5 |
| `Event` model | 9 |
| `Routine` / `Goal` model | 4 |
| `RoutineSchedule` model | 2 |
| `TodayViewModel` (progress, streak, weekly, settings, edges) | 25 |
| `HistoryViewModel` (grouping, CRUD, sort) | 10 |
| `HistoryViewModel` + `MockHealthKitService` (sleep merge, auth, failures) | 9 |
| `SleepNight` model + `TimeInterval.sleepFormatted` | 7 |
| `SleepAggregator` | 6+ |
| Snapshot (`TodayView`) | 4 |
| Snapshot (`HistoryView`) | 3 |
| Snapshot (`SleepCard`) | 2 |
| UI tests (`TodayView`) | 3 |
| UI tests (`HistoryView`) | 3 |

### Notes on streak tests

The five streak boundary cases are covered by a single parameterized test `todayVM_streak` in `AllTests` using `@Test(arguments:)` with a `StreakCase` struct. Cases: `noEntries`, `todayOnly`, `threeConsecutive`, `skipsYesterday`, `onlyPriorDays`. To add a new boundary case, append a `StreakCase` to the arguments array.
