import XCTest

/// Phase 10 batch A: patch test, opened date, similar formulas, shelf card and shelf links.
final class ShelfToolsUITests: XCTestCase {
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
        app.launchArguments = ["-seedDemoData", "-resetDemoData", "YES", "-demoActivity", "YES", "-startTab", "products",
                               "-patchTests", "", "-openedProducts", ""] + extra
        app.launch()
        _ = app.descendants(matching: .any)["shelfView"].waitForExistence(timeout: 30)
        sleep(3)
    }

    private func openProduct(_ query: String) {
        let search = app.textFields["shelfSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText(query + "\n")
        let first = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", query)).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.tap()
    }

    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
    }

    func testPatchTestOpenedAndDupes() {
        launch(["-proOverride", "pro"])
        openProduct("Moisturizer")
        let start = app.buttons["startPatchTest"]
        scrollTo(start)
        start.tap()
        let noChange = app.buttons["patchNoChange"]
        XCTAssertTrue(noChange.waitForExistence(timeout: 5))
        attachScreenshot("Patch test · day 1")
        noChange.tap()
        XCTAssertTrue(app.staticTexts["Checked today"].waitForExistence(timeout: 5))
        let opened = app.buttons["markOpened"]
        scrollTo(opened)
        opened.tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 5))
        app.buttons["Save"].tap()
        let similar = app.staticTexts["Similar formulas"]
        scrollTo(similar)
        app.swipeUp(velocity: .slow)
        sleep(1)
        attachScreenshot("Opened + similar formulas")
    }

    func testDupesLockedOnFree() {
        launch(["-proOverride", "free"])
        openProduct("Moisturizer")
        let locked = app.buttons["dupesLocked"]
        scrollTo(locked)
        if locked.exists {
            locked.tap()
            XCTAssertTrue(app.staticTexts["Find products with a similar formula with Pro."].waitForExistence(timeout: 5))
        }
    }

    func testShelfLinkOpensProducts() {
        launch()
        app.open(URL(string: "skinalyze://shelf?p=18,1,999999")!)
        XCTAssertTrue(app.navigationBars["A friend's shelf"].waitForExistence(timeout: 10))
        let biore = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "UV Aqua Rich Aqua Protect Mist")).firstMatch
        XCTAssertTrue(biore.waitForExistence(timeout: 5))
        attachScreenshot("Shared shelf")
    }

    /// P5: two typed-in steps that shouldn't share a night are flagged.
    func testRoutineBuilderWarns() {
        launch(["-routinePlan", ""])
        let edit = app.buttons["editRoutine"]
        scrollTo(edit)
        edit.tap()
        app.buttons["Evening"].firstMatch.tap()
        for (name, active) in [("Night retinol", "Retinoid (retinol, adapalene)"), ("BHA liquid", "BHA (salicylic acid)")] {
            let add = app.buttons["addRoutineStep"]
            scrollTo(add)
            add.tap()
            let field = app.textFields["stepName"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(name)
            let toggle = app.switches[active]
            scrollTo(toggle)
            toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
            app.buttons["confirmAddStep"].tap()
        }
        app.swipeDown()
        let warning = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "a retinoid and an exfoliating acid")).firstMatch
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        attachScreenshot("Routine builder · warning")
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
