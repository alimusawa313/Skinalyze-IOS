import XCTest

/// Captures the clean screens the App Store set is framed from (`scripts/store-shots.sh` runs it per device and pose,
/// then the app's debug renderer frames them). Demo data, Pimpi's tips off, every display attached (iPhone Duo).
/// Asserts only that each screen is reachable.
final class StoreShotsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            for title in ["Allow", "OK"] where alert.buttons[title].firstMatch.exists {
                alert.buttons[title].firstMatch.tap()
                return true
            }
            return false
        }
    }

    private func launch(_ extra: [String] = []) {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let days = (0..<12).map { formatter.string(from: Calendar.current.date(byAdding: .day, value: -$0, to: .now)!) }
        app.launchArguments = ["-seedDemoData", "-resetDemoData", "YES", "-demoActivity", "YES", "-tutorialOff", "YES",
                               "-proOverride", "pro", "-questDebugChests", "1", "-skinSensitivity", "Not sensitive",
                               "-routineDoneDays", days.joined(separator: ","), "-routineDoneDaysImported", "YES"] + extra
        app.launch()
    }

    /// The app's display, and on iPhone Duo every other display too ("<name> · screen N"): the script keeps the one
    /// in use for the pose.
    private func snap(_ name: String, settle: UInt32 = 2) {
        sleep(settle)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        for (index, screen) in XCUIScreen.screens.enumerated() where index > 0 {
            let extra = XCTAttachment(screenshot: screen.screenshot())
            extra.name = "\(name) · screen \(index + 1)"
            extra.lifetime = .keepAlways
            add(extra)
        }
    }

    private func close() {
        for label in ["Done", "Close"] where app.buttons[label].firstMatch.exists {
            app.buttons[label].firstMatch.tap()
            sleep(1)
            return
        }
        app.swipeDown(velocity: .fast)
        sleep(1)
    }

    func testApp() {
        launch()
        XCTAssertTrue(app.buttons["mirrorIndex"].waitForExistence(timeout: 30))
        sleep(4) // demo scans arrive one by one
        snap("home")

        // Streaks and a chest.
        let badge = app.buttons["pimpiStreak"]
        if badge.waitForExistence(timeout: 5) {
            badge.tap()
            snap("streaks")
            let chest = app.buttons["chestOpen"]
            if !chest.exists, app.buttons["questChest"].exists { app.buttons["questChest"].tap() }
            if chest.waitForExistence(timeout: 3) {
                chest.tap()
                snap("chest", settle: 4)
                if app.buttons["chestWear"].exists { app.buttons["chestWear"].tap() } else { close() }
            }
            close()
        }

        // The latest result: the 3D head, then the photo with its spots.
        let toggle = app.descendants(matching: .any)["toggle3D"]
        for _ in 0..<3 where !toggle.exists {
            app.buttons["mirrorIndex"].tap()
            _ = toggle.waitForExistence(timeout: 4)
        }
        snap("result-3d", settle: 3)
        app.swipeUp()
        snap("result-changed")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.01)).tap()
        sleep(2)
        if toggle.exists {
            toggle.tap()
            snap("result-photo")
        }
        close()

        // Deck, then two scans side by side.
        app.buttons["dock.deck"].tap()
        snap("deck")
        if app.buttons["Compare"].exists {
            app.buttons["Compare"].tap()
            sleep(1)
            let cards = app.buttons.matching(NSPredicate(format: "label CONTAINS ', Calm' OR label CONTAINS ', Mild' OR label CONTAINS ', Active' OR label CONTAINS ', Flared'"))
            if cards.count >= 2 {
                cards.element(boundBy: 0).tap()
                app.swipeUp()
                sleep(1)
                // The oldest card on screen now (the list is lazy, so count again after the swipe).
                cards.allElementsBoundByIndex.last { $0.isHittable }?.tap()
                if app.buttons["Compare these two"].waitForExistence(timeout: 3) {
                    app.buttons["Compare these two"].tap()
                    snap("compare", settle: 3)
                    close()
                }
            }
        }

        // Shelf, a product check, the journey and Skin School.
        app.buttons["dock.shelf"].tap()
        snap("shelf")
        let journey = app.buttons["journeyCard"]
        for _ in 0..<4 where !journey.isHittable { app.swipeUp() }
        if journey.waitForExistence(timeout: 5) {
            journey.tap()
            snap("journey")
            close()
        }
        let school = app.buttons["skinSchoolCard"]
        for _ in 0..<4 where !school.isHittable { app.swipeUp() }
        if school.waitForExistence(timeout: 5) {
            school.tap()
            snap("school")
            close()
        }

        app.buttons["dock.shelf"].tap()
        sleep(1)
        let field = app.textFields["shelfSearch"]
        if field.waitForExistence(timeout: 5) {
            field.tap()
            field.typeText("niacinamide")
            let result = app.buttons.matching(identifier: "shelfResult").firstMatch
            if result.waitForExistence(timeout: 5) { result.tap() }
            snap("product")
            let back = app.navigationBars.buttons.firstMatch
            if back.exists { back.tap() }
            sleep(1)
            if app.keyboards.firstMatch.exists { field.typeText("\n") }
            if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        }
        // Profile: privacy and Pimpi's tips.
        app.buttons["dock.mirror"].tap()
        sleep(1)
        app.buttons["Profile and settings"].tap()
        snap("profile")
    }

    /// The scan's signature moment: the photo lifts off as a sticker.
    func testSticker() {
        launch(["-stickerDemo", "YES"])
        XCTAssertTrue(app.buttons["dock.mirror"].waitForExistence(timeout: 30))
        // The moment is short and its timing varies: many quick frames, the clean one is picked by eye.
        for step in 1...10 { snap("sticker-\(step)", settle: 0) }
    }

    func testOnboarding() {
        app.launchArguments = ["-resetOnboarding", "YES", "-tutorialOff", "YES"]
        app.launch()
        let next = app.buttons["onboardingContinue"]
        XCTAssertTrue(app.buttons["onboardingPimpi"].waitForExistence(timeout: 20))
        app.buttons["onboardingPimpi"].tap()
        snap("ob-wake")
        next.tap()
        sleep(1)
        let name = app.textFields["onboardingName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Sam")
        snap("ob-name")
        next.tap()
        sleep(1)
        app.buttons["goal.fewerBreakouts"].tap()
        app.buttons["goal.buildRoutine"].tap()
        snap("ob-goals")
        next.tap()
        sleep(1)
        XCTAssertTrue(app.buttons["skinCheck.oily"].waitForExistence(timeout: 5))
        for answer in ["oily", "dry", "balanced"] {
            app.buttons["skinCheck.\(answer)"].tap()
            sleep(1)
        }
        snap("ob-skincheck")
        next.tap()
        sleep(1)
        app.buttons["sensitivity.Somewhat sensitive"].firstMatch.tap()
        next.tap()
        sleep(1)
        app.buttons["onboardingSkip"].tap()
        sleep(1)
        app.descendants(matching: .any)["holdToSeal"].firstMatch.press(forDuration: 1.6)
        snap("ob-promise")
        next.tap()
        sleep(1)
        snap("ob-plan")
    }
}
