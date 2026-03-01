# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

LifeTrak — a personal iOS app for tracking daily habits (water intake, medication, exercise, etc.). Built with SwiftUI + SwiftData, targeting iOS 26.2. Currently in early development using a "tracer round" strategy: building water tracking end-to-end before generalizing to other tracker types.

## Build & Test Commands

This is an Xcode project (no SPM Package.swift at the root). All build/test commands use `xcodebuild`.

```bash
# Build
xcodebuild -scheme lifetrak -destination 'platform=iOS Simulator,name=iPhone 14' build

# Run all tests
xcodebuild -scheme lifetrak -destination 'platform=iOS Simulator,name=iPhone 14' test

# Run only unit tests
xcodebuild -scheme lifetrak -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:lifetrakTests test

# Run only UI tests
xcodebuild -scheme lifetrak -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:lifetrakUITests test

# Run a single test (Swift Testing)
xcodebuild -scheme lifetrak -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:'lifetrakTests/TestClassName/testMethodName' test
```

## Architecture

- **SwiftUI** views → **@Observable ViewModels** (business logic) → **SwiftData @Model** classes (persistence)
- ViewModels contain all testable logic; views are kept thin and declarative
- Unit tests use **Swift Testing** framework (`@Test` macros, not XCTest)
- UI tests use **XCTest** framework
- No external dependencies — Apple frameworks only
- Settings/preferences use `@AppStorage` / `UserDefaults` (not SwiftData)

## Key Files

- `lifetrak/lifetrakApp.swift` — App entry point, configures `ModelContainer`
- `lifetrak/WaterEntry.swift` — Water intake data model (SwiftData)
- `PLAN.md` — Detailed build plan with tracer round strategy and future phases

## Conventions

- TDD: write model/logic tests first, then implement, then build views
- PRs for each feature step; merge to `main`
- `gh` CLI is at `/opt/homebrew/bin/gh`
- Swift concurrency defaults: `MainActor` isolation, approachable concurrency enabled
