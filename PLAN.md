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

# Plan

## Current State

Xcode has generated a working SwiftUI + SwiftData scaffold with a basic list view, a placeholder `Item` model, and empty test targets. CloudKit entitlements and push notifications are configured but not yet wired up. We have a clean git history and a solid starting point.

## Technical Stack

| Layer | Choice | Why |
|-------|--------|-----|
| UI | **SwiftUI** | Already set up; declarative, modern, good for rapid iteration |
| Persistence | **SwiftData** | Already set up; Apple's modern ORM, works naturally with SwiftUI |
| Health Data | **HealthKit** | Apple's framework for reading health metrics (heart rate, sleep, steps, etc.) |
| Architecture | **MVVM** | Natural fit for SwiftUI's data binding; keeps views thin and logic testable |
| Unit Tests | **Swift Testing** | Already scaffolded; modern, expressive test framework |
| UI Tests | **XCTest** | Already scaffolded; standard for UI automation |
| CI | **GitHub Actions** | Free for personal repos; `xcodebuild test` in a macOS runner |
| Dependency Mgmt | **Swift Package Manager** | Built into Xcode; no CocoaPods/Carthage overhead needed |

## Architecture

```
┌─────────────────────────────────────────────┐
│                   Views                      │
│  (SwiftUI screens - thin, declarative)       │
├─────────────────────────────────────────────┤
│                ViewModels                    │
│  (ObservableObject classes - business logic) │
├─────────────────────────────────────────────┤
│                 Services                     │
│  HealthKitService, NotificationService       │
├─────────────────────────────────────────────┤
│                  Models                      │
│  SwiftData @Model classes                    │
├─────────────────────────────────────────────┤
│              SwiftData / HealthKit           │
│  (Persistence & OS frameworks)               │
└─────────────────────────────────────────────┘
```

**Key architectural decisions:**
- **Protocol-based services** — e.g., `HealthDataProviding` protocol so we can inject a mock in tests instead of hitting real HealthKit
- **ViewModels are unit-testable** — no UIKit/SwiftUI imports in ViewModels; they work with plain data
- **Models are the source of truth** — SwiftData models hold all persisted state; ViewModels query/mutate them

## Data Models (Draft)

```swift
// What the user tracks (configured in Settings)
@Model TrackerDefinition {
    name: String              // "Water", "Medication X", "Meditation"
    category: TrackerCategory // .medication, .hydration, .exercise, .habit, .custom
    unit: String?             // "oz", "mg", "minutes", nil for simple check-off
    dailyGoal: Double?        // 64 (oz), 1 (took it), 30 (minutes)
    icon: String              // SF Symbol name
    color: String             // hex color
    isArchived: Bool
    sortOrder: Int
}

// Each time the user logs something
@Model TrackerEntry {
    tracker: TrackerDefinition
    timestamp: Date
    value: Double             // 8 (oz), 1 (yes/no), 20 (minutes)
    note: String?
}

// Cached snapshots from HealthKit (read-only display)
@Model HealthSnapshot {
    metricType: HealthMetricType  // .heartRate, .steps, .sleep, .activeEnergy
    date: Date
    value: Double
    unit: String
}
```

## Feature Build Order

We'll build in vertical slices — each phase delivers a usable feature end-to-end, with tests.

### Phase 1: Foundation & Settings
**Goal:** Replace the Xcode template with real data models and a settings screen to configure trackers.

1. Define `TrackerDefinition` model and write unit tests for it
2. Build Settings screen — CRUD for tracker definitions (name, category, goal, icon)
3. Replace `Item` model and `ContentView` with the new structure
4. Set up CI (GitHub Actions running tests on push)

### Phase 2: Data Entry (Core Loop)
**Goal:** The main screen where you one-tap to log activities.

1. Build the "Today" dashboard view — shows all active trackers with current progress
2. Implement one-tap logging (tap = create a `TrackerEntry` with value=1 or configurable increment)
3. Add quick-entry variations: simple toggle, counter (+1 each tap), quantity input (e.g., "how many oz?")
4. Haptic feedback and animations on log

### Phase 3: Progress Rings (Gamification)
**Goal:** Visual motivation to complete daily goals.

1. Build ring/progress components (similar to Apple Activity rings)
2. Show daily completion percentage per tracker
3. Add an overall "day score" — percentage of all goals met
4. Celebrate 100% completion (animation, optional notification)

### Phase 4: History & Editing
**Goal:** Browse and correct past entries.

1. Build a history view — filterable by tracker, date range
2. Detail view for each entry (edit value, timestamp, note)
3. Add/delete entries manually (fix mistakes)
4. Calendar heat-map view showing activity density

### Phase 5: Apple Health Integration
**Goal:** Pull health metrics and display alongside manual tracking.

1. Implement `HealthKitService` with authorization flow
2. Read heart rate, steps, sleep, active energy (configurable)
3. Store snapshots in `HealthSnapshot` for offline display
4. Show health data in the Today dashboard alongside manual trackers

### Phase 6: Analysis & Trends
**Goal:** Visualizations that surface insights.

1. Streak tracking (consecutive days meeting a goal)
2. Trend charts (weekly/monthly views using Swift Charts)
3. Correlation hints (e.g., "You sleep better on days you exercise")
4. Export data (CSV or JSON)

### Phase 7: Polish & Quality of Life
**Goal:** Make it feel like a finished app.

1. Notifications/reminders (e.g., "Don't forget evening meds")
2. Widgets (iOS home screen widget showing today's progress)
3. App icon and visual design polish
4. Onboarding flow for first launch
5. iCloud sync via CloudKit (entitlements already configured)

## TDD Approach

For each feature:
1. **Write model/logic tests first** — verify data transformations, goal calculations, streak logic
2. **Implement the minimum code** to make tests pass
3. **Build the view** — SwiftUI previews for rapid visual iteration
4. **Add UI tests** for critical flows (logging an entry, editing settings)

We'll keep test coverage high on ViewModels and Services (where the logic lives). Views will be thin enough that SwiftUI previews + targeted UI tests provide sufficient coverage.

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

Simple to start — we can add linting (SwiftLint), code coverage reporting, and build artifact archiving later.

## File/Folder Structure (Target)

```
lifetrak/
├── App/
│   └── lifetrakApp.swift
├── Models/
│   ├── TrackerDefinition.swift
│   ├── TrackerEntry.swift
│   ├── HealthSnapshot.swift
│   └── Enums/ (TrackerCategory, HealthMetricType)
├── ViewModels/
│   ├── TodayViewModel.swift
│   ├── SettingsViewModel.swift
│   ├── HistoryViewModel.swift
│   └── AnalyticsViewModel.swift
├── Views/
│   ├── Today/
│   ├── Settings/
│   ├── History/
│   ├── Analytics/
│   └── Components/ (ProgressRing, TrackerCard, etc.)
├── Services/
│   ├── HealthKitService.swift
│   └── NotificationService.swift
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

---

# Questions for You

Before we start building, a few things to clarify:

1. **Tracker types** — I'm planning for three input modes: simple toggle (did it / didn't), counter (tap to increment), and quantity input (type a number). Does that cover your use cases, or do you need others (e.g., duration timer, rating scale 1-5)?

2. **Medications specifically** — Do you want medication tracking to support dose times (morning/evening), dosage amounts (mg), and refill reminders? Or is a simple "took it" toggle sufficient?

3. **Apple Health data** — Which metrics do you actually care about? Heart rate, sleep, and steps are the most common. Others available: active calories, walking distance, blood oxygen, respiratory rate, mindful minutes, etc.

4. **Notifications** — Do you want reminder notifications (e.g., "Time to take evening meds")? If so, how sophisticated — fixed times, or smart reminders that notice you haven't logged something yet?

5. **iCloud sync** — The project has CloudKit entitlements already. Do you want cross-device sync, or is this single-device only? (Single-device is simpler to build and test.)

6. **Starting point** — I'm planning to start with Phase 1 (data models + settings). Does that sequencing make sense, or would you rather see the data entry UI first and configure trackers later?

	