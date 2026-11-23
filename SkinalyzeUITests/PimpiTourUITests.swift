import XCTest

/// Walks every screen where Pimpi appears and moves, slowly, so a screen recording shows the animations
/// (run with `xcrun simctl io <sim> recordVideo` alongside). Screenshots are attached too.
final class PimpiTourUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            for title in ["Allow", "OK", "Don’t Allow"] where alert.buttons[title].firstMatch.exists {
                alert.buttons[title].firstMatch.tap()
                return true
            }
            return false
        }
        app.launchArguments = ["-seedDemoData", "-resetDemoData", "YES", "-demoActivity", "YES", "-questDebugChests", "1",
                               "-socialDemo", "YES", "-recapToday", "2026-11-22", "-proOverride", "pro"]
        app.launch()
        _ = app.buttons["mirrorIndex"].waitForExistence(timeout: 30)
        sleep(3)
    }

    private func pause(_ name: String, _ seconds: UInt32 = 3) {
        sleep(seconds)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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

    func testPimpiEverywhere() {
        pause("01 Mirror badge")
        let badge = app.buttons["pimpiStreak"]
        if badge.waitForExistence(timeout: 5) {
            badge.tap()
            pause("02 Streak sheet")
            let chest = app.buttons["chestOpen"]
            if !chest.exists, app.buttons["questChest"].exists { app.buttons["questChest"].tap() }
            if chest.waitForExistence(timeout: 3) {
                chest.tap()
                pause("03 Chest opened", 4)
                if app.buttons["chestWear"].exists { app.buttons["chestWear"].tap() } else { close() }
            }
            close()
        }
        app.buttons["dock.shelf"].tap()
        pause("04 Shelf cards")
        if app.buttons["recapBanner"].exists {
            app.buttons["recapBanner"].tap()
            pause("05 Recap")
            close()
        }
        app.buttons["journeyCard"].tap()
        pause("06 Journey map")
        for _ in 0..<3 { app.swipeUp() }
        pause("07 Journey lower")
        let social = app.buttons["socialEntry"]
        if social.exists {
            social.tap()
            if app.buttons["socialJoin"].waitForExistence(timeout: 3) { app.buttons["socialJoin"].tap() }
            pause("08 Friends")
            app.buttons["League"].tap()
            pause("09 League")
            close()
        }
        close()
        let school = app.buttons["skinSchoolCard"]
        if school.waitForExistence(timeout: 3) {
            school.tap()
            pause("10 Skin School path")
            close()
        }
    }
}
