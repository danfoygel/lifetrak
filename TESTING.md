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

- **ViewModel logic**: calculations, filtering, aggregation (e.g. `TodayViewModel.totalOz`, goal progress percentages)
- **Pure functions**: `SleepAggregator`, date math, streak calculation
- **Model computed properties**: `SleepNight.efficiency`, `Event.duration`
- **Edge cases**: no data, goal of zero, overnight date boundaries

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

Create a test helper (add to `lifetrakTests/TestHelpers.swift`):

```swift
import SwiftData
import Foundation

/// Creates a ModelContainer backed by memory only — no disk I/O, discarded after tests.
func makeTestContainer(for types: [any PersistentModel.Type]) throws -> ModelContainer {
    let schema = Schema(types)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}
```

Usage in a Swift Testing test:

```swift
@Test func totalOzAccumulatesCorrectly() async throws {
    let container = try makeTestContainer(for: [WaterEntry.self])
    let context = container.mainContext

    // Seed the "existing" data
    context.insert(WaterEntry(timestamp: .now, amount: 16))
    context.insert(WaterEntry(timestamp: .now, amount: 8))
    try context.save()

    let vm = TodayViewModel(modelContext: context)
    await vm.refresh()

    #expect(vm.totalOz == 24)
}
```

### Testing a realistic pre-populated state

For tests that need a believable data set (e.g., "30 days of history"), use a seed helper:

```swift
func seedWaterHistory(context: ModelContext, days: Int, ozPerDay: Double) throws {
    let calendar = Calendar.current
    for dayOffset in 0..<days {
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now)!
        let entries = Int.random(in: 3...6)
        for _ in 0..<entries {
            context.insert(WaterEntry(timestamp: date, amount: ozPerDay / Double(entries)))
        }
    }
    try context.save()
}
```

This lets you write tests like "does the streak calculation correctly handle a 3-day gap in 30 days of data?"

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

### Option A: Xcode Cloud (Recommended for personal projects)

Apple's first-party CI service, integrated directly into Xcode and App Store Connect.

**Free tier**: 25 compute hours/month included with any Apple Developer Program membership ($99/year). For a personal project with a modest test suite, this is likely sufficient.

**Advantages**:
- Zero setup for code signing — Apple handles certificates automatically
- Runs on Apple Silicon hardware (fast)
- Natively understands Xcode project structure
- Results appear directly inside Xcode
- TestFlight integration built in
- Xcode and iOS SDK versions stay current

**Limitations**:
- Cannot run arbitrary shell commands as easily as GitHub Actions
- HealthKit tests require device-side testing (not possible in Xcode Cloud simulators)

**To set up**: In Xcode → Product → Xcode Cloud → Create Workflow. Select the scheme, set the start condition (on push to main, or on every PR), and add a Test action.

### Option B: GitHub Actions with macOS Runners

The plan already references this. It works but has notable costs and constraints.

**Free tier reality**: GitHub gives 2,000 minutes/month total, but macOS runners consume at **10× the rate** of Linux. In practice you get ~200 actual macOS minutes free per month — enough for a short test suite on every push, but not for long UI test runs.

**Key constraints**:
- New iOS SDK versions (like iOS 26) have a lag before appearing on GitHub-hosted runners
- You must pin the simulator name to what's actually available on the runner (check with `xcrun simctl list devices available`)
- Code signing must be disabled for tests (or configured via secrets)

**Sample workflow** (`/.github/workflows/test.yml`):
```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode version
        run: sudo xcode-select -s /Applications/Xcode_16.2.app

      - name: Run unit tests
        run: |
          xcodebuild test \
            -scheme lifetrak \
            -destination 'platform=iOS Simulator,name=iPhone 16' \
            -only-testing:lifetrakTests \
            CODE_SIGNING_ALLOWED=NO \
            | xcpretty

      - name: Upload test results
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: |
            ~/Library/Developer/Xcode/DerivedData/**/Logs/Test/*.xcresult
```

**Note on snapshot tests in CI**: Snapshot tests are pixel-exact. If your reference snapshots were recorded on a local Apple Silicon Mac and CI uses an Intel runner (or a different simulator scale), the tests will fail due to rendering differences. Solution: record reference snapshots on the CI machine by running with `isRecording = true` in a one-time job, then commit the results.

### Option C: Self-Hosted Runner (Mac Mini)

If you have a spare Mac, you can register it as a GitHub Actions self-hosted runner. This gives you:
- Unlimited minutes at no GitHub cost
- The exact simulator versions you have locally
- Apple Silicon performance
- No code-signing complications

For a personal project this is probably overkill, but worth knowing about as the project grows.

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

4. **Use Xcode Cloud for CI** — it's free for 25 hours/month with your Developer Program membership, handles code signing automatically, and tracks your iOS SDK version. Set up a workflow that runs `lifetrakTests` on every push to `main`.

5. **Exclude UI tests from CI by default** — UI tests are slow and fragile in CI environments. Run them locally before merging. If you later want CI UI tests, add them as a separate, less-frequent scheduled workflow.

6. **Use `xcresulttool` as the authoritative source of truth** for test results when working with Claude Code — it provides complete structured output regardless of MCP truncation issues.

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
