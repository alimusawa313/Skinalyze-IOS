import XCTest

/// Phase 9 (local parts): Pimpi's recaps, Skin Wrapped, the journey map and 30-day challenges, on seeded demo
/// scans plus ~10 weeks of demo routine and quest activity.
final class JourneyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            for title in ["Allow", "OK", "Don’t Allow"] where alert.buttons[title].firstMatch.exists {
                alert.buttons[title].firstMatch.tap()
                return true
            }
            return false
        }
    }

    /// `recapToday` pretends the date for which a recap is due (yyyy-MM-dd).
    private func launch(recapToday: String, extra: [String] = []) {
        app.launchArguments = ["-seedDemoData", "-resetDemoData", "YES", "-demoActivity", "YES",
                               "-recapToday", recapToday, "-startTab", "products"] + extra
        app.launch()
        _ = app.descendants(matching: .any)["shelfView"].waitForExistence(timeout: 30)
        sleep(4) // demo scans arrive one by one
    }

    /// On a Sunday Pimpi offers the week's recap; once opened it doesn't come back.
    func testWeeklyRecapFromShelf() {
        launch(recapToday: "2026-11-22")
        let banner = app.buttons["recapBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        attachScreenshot("Shelf · recap banner")
        banner.tap()
        XCTAssertTrue(app.navigationBars["Your week"].waitForExistence(timeout: 10))
        sleep(1)
        attachScreenshot("Weekly recap")
        app.buttons["shareCard"].tap()
        sleep(3)
        attachScreenshot("Weekly recap · share")
        app.swipeDown(velocity: .fast)
        sleep(1)
        app.navigationBars["Your week"].buttons["Done"].tap()
        sleep(1)
        XCTAssertFalse(app.buttons["recapBanner"].exists)
    }

    /// Early January: last year's Wrapped, with the gentle highlights from the demo scans.
    func testYearWrapped() {
        launch(recapToday: "2027-01-03")
        let banner = app.buttons["recapBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        banner.tap()
        XCTAssertTrue(app.navigationBars["Your 2026 Wrapped"].waitForExistence(timeout: 10))
        sleep(1)
        attachScreenshot("Wrapped · top")
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["wrappedHighlights"].waitForExistence(timeout: 5))
        attachScreenshot("Wrapped · highlights")
    }

    /// The journey map, then swapping the running challenge for "hands off" and checking in today.
    func testJourneyAndChallenge() {
        launch(recapToday: "2026-11-25")
        XCTAssertFalse(app.buttons["recapBanner"].exists)
        let card = app.buttons["journeyCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any)["journeyStop.7"].waitForExistence(timeout: 10))
        attachScreenshot("Journey map")
        let stop = app.buttons["Stop challenge"].firstMatch
        for _ in 0..<8 where !stop.isHittable { app.swipeUp() }
        attachScreenshot("Journey · running challenge")
        stop.tap()
        sleep(1)
        // The confirmation dialog's own "Stop challenge".
        let buttons = app.buttons.matching(identifier: "Stop challenge")
        buttons.element(boundBy: buttons.count - 1).tap()
        let start = app.buttons["challenge.start.handsOff"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let checkIn = app.buttons["challenge.handsOff"]
        XCTAssertTrue(checkIn.waitForExistence(timeout: 5))
        checkIn.tap()
        let dayOne = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Day 1 of 30")).firstMatch
        XCTAssertTrue(dayOne.waitForExistence(timeout: 5))
        attachScreenshot("Journey · hands off day 1")
        for _ in 0..<4 { app.swipeUp() }
        attachScreenshot("Journey · recaps")
    }

    /// Largest text: the Shelf cards and a recap still fit.
    func testJourneyAtLargestText() {
        launch(recapToday: "2026-11-23",
               extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let banner = app.buttons["recapBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        attachScreenshot("Shelf · AX5")
        banner.tap()
        sleep(1)
        attachScreenshot("Weekly recap · AX5")
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
