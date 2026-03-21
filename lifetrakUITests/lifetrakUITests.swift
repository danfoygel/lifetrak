//
//  lifetrakUITests.swift
//  lifetrakUITests
//

import XCTest

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
        // 3 × 8 oz = 24 oz of 64 oz goal
        XCTAssertTrue(app.staticTexts["24"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["of 64 oz"].exists)
    }

    func testStreakLabelShowsAfter30Days() {
        launch(args: ["--seed-water-history"])
        let streak = app.otherElements[AXID.Today.streakLabel]
        XCTAssertTrue(streak.waitForExistence(timeout: 10))
        XCTAssertTrue(streak.staticTexts["30-day streak"].exists)
    }
}
