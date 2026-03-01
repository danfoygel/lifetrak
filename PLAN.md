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
3. Apple Health integration
4. Cross-tracker analysis and correlations
5. Notifications/reminders
6. Widgets

	