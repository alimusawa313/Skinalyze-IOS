import XCTest

/// Phase 10 batch C: trigger journal and patterns (P3), the visit pack (P11).
final class JournalUITests: XCTestCase {
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

    private func launch(_ extra: [String] = []) {
        app.launchArguments = ["-seedDemoData", "-resetDemoData", "YES", "-demoActivity", "YES", "-startTab", "products"] + extra
        app.launch()
        _ = app.descendants(matching: .any)["shelfView"].waitForExistence(timeout: 30)
        sleep(4)
    }

    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<10 where !element.isHittable { app.swipeUp() }
    }

    func testCheckInAndPatterns() {
        launch(["-proOverride", "free"])
        let chip = app.buttons["journal.sweets"]
        scrollTo(chip)
        chip.tap()
        XCTAssertTrue(chip.isSelected)
        attachScreenshot("Journal card")
        app.buttons["journalPatterns"].tap()
        let stressed = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "\"stressed\" days had more marked")).firstMatch
        XCTAssertTrue(stressed.waitForExistence(timeout: 10))
        attachScreenshot("Patterns")
    }

    func testVisitPack() {
        launch(["-proOverride", "pro"])
        app.buttons["dock.mirror"].tap()
        let profile = app.buttons["Profile and settings"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        profile.tap()
        let entry = app.buttons["Dermatologist visit pack"]
        scrollTo(entry)
        entry.tap()
        app.buttons["createPack"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["sharePack"].waitForExistence(timeout: 20))
        attachScreenshot("Visit pack ready")
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
