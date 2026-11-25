import XCTest

/// Walks every V2 screen on seeded demo data and attaches a screenshot of each, for visual review
/// (`xcrun xcresulttool export attachments`). Asserts only that each screen is reachable.
final class VisualTourUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        // Demo scans plus a five-day routine streak ending today.
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let days = (0..<5).map { formatter.string(from: Calendar.current.date(byAdding: .day, value: -$0, to: .now)!) }
        app.launchArguments = ["-seedDemoData", "-resetDemoData", "YES", "-routineDoneDays", days.joined(separator: ","), "-routineDoneDaysImported", "YES"]
        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            for title in ["Allow", "OK"] where alert.buttons[title].firstMatch.exists {
                alert.buttons[title].firstMatch.tap()
                return true
            }
            return false
        }
        app.launch()
    }

    func testTour() {
        XCTAssertTrue(app.buttons["mirrorIndex"].waitForExistence(timeout: 10))
        snap("01 Mirror")
        let pimpi = app.buttons["pimpiStreak"]
        if pimpi.waitForExistence(timeout: 5) {
            for _ in 0..<3 where !app.staticTexts["Scan streak"].exists {
                pimpi.tap()
                _ = app.staticTexts["Scan streak"].waitForExistence(timeout: 3)
            }
            sleep(1)
            snap("01b Streaks")
            app.buttons["Done"].firstMatch.tap()
            sleep(1)
        }

        // Result: chapters + 3D hero.
        let toggle = app.descendants(matching: .any)["toggle3D"]
        for _ in 0..<3 where !toggle.exists {
            app.buttons["mirrorIndex"].tap()
            _ = toggle.waitForExistence(timeout: 4)
        }
        sleep(2)
        snap("02 Result · 3D hero")
        app.swipeUp()
        snap("03 Result · What changed")
        app.buttons["What we noticed"].tap()
        sleep(1)
        snap("04 Result · What we noticed")
        app.buttons["What helps"].tap()
        sleep(1)
        snap("05 Result · What helps")
        // Drag the page up from a row (a plain swipe here can start on the chapter pager and not scroll).
        for name in ["05b What helps · for what was noticed", "05c What helps · habits"] {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)))
            sleep(1)
            snap(name)
        }
        // Back to the top by tapping the status bar (a swipe on the 3D head turns it instead of scrolling).
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.01)).tap()
        sleep(2) // let the scroll settle: a tap while it is still moving only stops it
        if toggle.exists {
            toggle.tap()
            sleep(1)
            snap("06 Result · photo")
            // Poke the small Pimpi beside the index: its handwritten line must still fit there.
            let cheering = app.buttons.matching(identifier: "Pimpi").allElementsBoundByIndex.first { $0.isHittable }
                ?? app.buttons["Pimpi"].firstMatch
            if cheering.exists {
                for _ in 0..<4 { cheering.tap() }
                sleep(1)
                snap("06a Result · Pimpi poked")
            }
            let pin = app.buttons.matching(identifier: "spotPin").firstMatch
            if pin.waitForExistence(timeout: 3) {
                pin.tap()
                sleep(1)
                snap("06b Spot pop-up")
                app.tap() // dismiss the pop-up
            }
        }
        app.buttons["Done"].firstMatch.tap()
        sleep(1)

        // Deck: flick, then compare.
        app.buttons["dock.deck"].tap()
        sleep(2)
        snap("07 Deck")
        app.swipeUp()
        sleep(1)
        snap("08 Deck · flicked")
        if app.buttons["Compare"].exists {
            app.buttons["Compare"].tap()
            sleep(1)
            snap("09 Deck · picking")
            let cards = app.buttons.matching(NSPredicate(format: "label CONTAINS ', Calm' OR label CONTAINS ', Mild' OR label CONTAINS ', Active' OR label CONTAINS ', Flared'"))
            if cards.count >= 2 {
                cards.element(boundBy: 0).tap()
                app.swipeUp()
                sleep(1)
                cards.element(boundBy: 1).tap()
                if app.buttons["Compare these two"].waitForExistence(timeout: 3) {
                    app.buttons["Compare these two"].tap()
                    sleep(3)
                    snap("09b Compare aligned")
                    app.buttons["Done"].firstMatch.tap()
                    sleep(1)
                }
            }
        }

        // Shelf: tiles, search.
        app.buttons["dock.shelf"].tap()
        sleep(2)
        snap("10 Shelf")
        // Poke Pimpi for a longer line: the bubble must stay beside Pimpi, level with it.
        let shelfPimpi = app.buttons["Pimpi"].firstMatch
        if shelfPimpi.exists {
            for _ in 0..<3 { shelfPimpi.tap() }
            sleep(1)
            snap("10b Shelf · Pimpi poked")
        }
        let field = app.textFields["shelfSearch"]
        if field.waitForExistence(timeout: 5) {
            field.tap()
            field.typeText("niacinamide")
            sleep(1)
            snap("11 Shelf · search")
            let result = app.buttons.matching(identifier: "shelfResult").firstMatch
            if result.waitForExistence(timeout: 5) { result.tap() }
            sleep(2)
            snap("12 Product check")
            // Back to the Shelf with the keyboard down, so the dock is on screen again.
            let back = app.navigationBars.buttons.firstMatch
            if back.exists { back.tap() }
            // An imported product that isn't a shelf slot: it can go into a routine, and its source is credited.
            field.tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20) + "Skin Renewing Eye Cream")
            if result.waitForExistence(timeout: 5) {
                result.tap()
                sleep(2)
                snap("12b Imported eye cream")
                app.swipeUp()
                sleep(1)
                snap("12c Imported eye cream · lower")
                if back.exists { back.tap() }
            }
            if app.keyboards.firstMatch.exists { field.typeText("\n") }
        }
        XCTAssertTrue(app.buttons["dock.mirror"].waitForExistence(timeout: 10))

        // Profile from the Mirror avatar.
        app.buttons["dock.mirror"].tap()
        sleep(1)
        app.buttons["Profile and settings"].tap()
        sleep(2)
        snap("13 Profile")
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
