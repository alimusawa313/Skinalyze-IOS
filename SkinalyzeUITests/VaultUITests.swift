import XCTest

/// Phase 10 batch D: private vault (P13), barcode linking (P8), UV card (P10), creator kit (G9).
final class VaultUITests: XCTestCase {
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
        app.launchArguments = ["-seedDemoData", "-resetDemoData", "YES", "-vaultSkipAuth", "YES",
                               "-barcodeLinks", "", "-uvNudgeEnabled", "NO", "-proOverride", "pro"] + extra
        app.launch()
        _ = app.buttons["mirrorIndex"].waitForExistence(timeout: 30)
        sleep(3)
    }

    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
    }

    private var scanRows: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label CONTAINS ', Calm' OR label CONTAINS ', Mild' OR label CONTAINS ', Active' OR label CONTAINS ', Flared'"))
    }

    func testHideScanAndFindItInTheVault() {
        launch()
        app.buttons["dock.deck"].tap()
        let firstRow = scanRows.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10))
        let count = app.staticTexts["deckCount"]
        let before = Int(count.label) ?? 0
        firstRow.tap()
        let more = app.buttons["scanMore"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        app.buttons["Hide this scan"].tap()
        app.buttons["Hide"].tap()
        sleep(2)
        XCTAssertEqual(Int(count.label), before - 1)
        // Profile → Hidden scans lists it (or, if an earlier run left secret mode on, the Deck title opens it).
        let secret = app.switches["vaultSecret"]
        app.buttons["dock.mirror"].tap()
        app.buttons["Profile and settings"].tap()
        let row = app.buttons["hiddenScansRow"]
        scrollTo(row)
        if row.exists {
            row.tap()
            XCTAssertTrue(app.navigationBars["Hidden scans"].waitForExistence(timeout: 5))
            attachScreenshot("Hidden scans")
            scrollTo(secret)
            secret.switches.firstMatch.exists ? secret.switches.firstMatch.tap() : secret.tap()
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertFalse(app.buttons["hiddenScansRow"].waitForExistence(timeout: 2))
        }
        let profileBar = app.navigationBars["Profile"]
        if profileBar.buttons["Done"].exists { profileBar.buttons["Done"].tap() } else { profileBar.swipeDown(velocity: .fast) }
        XCTAssertTrue(profileBar.waitForNonExistence(timeout: 5))
        // Secret mode: press and hold the Deck title.
        app.buttons["dock.deck"].tap()
        let title = app.staticTexts["deckTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.press(forDuration: 2)
        XCTAssertTrue(app.navigationBars["Hidden scans"].waitForExistence(timeout: 5))
        attachScreenshot("Hidden scans · from Deck title")
        // Leave secret mode off for the next run.
        scrollTo(secret)
        secret.switches.firstMatch.exists ? secret.switches.firstMatch.tap() : secret.tap()
    }

    func testSecretEntryFromDeckTitle() {
        launch(["-vaultSecret", "YES"])
        app.buttons["dock.deck"].tap()
        let title = app.staticTexts["deckTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.press(forDuration: 2.5)
        XCTAssertTrue(app.navigationBars["Hidden scans"].waitForExistence(timeout: 5))
    }

    func testBarcodeLinksToAProduct() {
        launch(["-startTab", "products"])
        let scan = app.buttons["scanBarcode"]
        XCTAssertTrue(scan.waitForExistence(timeout: 10))
        scan.tap()
        let field = app.textFields["barcodeField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("4005900036728")
        app.buttons["barcodeCheck"].tap()
        XCTAssertTrue(app.buttons["lookupOnline"].waitForExistence(timeout: 5))
        attachScreenshot("Barcode · unknown")
        app.buttons["linkBarcode"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Moisturizer")
        let pick = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Moisturizer")).firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        XCTAssertTrue(app.buttons["startPatchTest"].waitForExistence(timeout: 10) || app.staticTexts["Patch test"].exists)
        attachScreenshot("Barcode · linked product")
    }

    func testUVCard() {
        launch(["-startTab", "products", "-uvDebugIndex", "8"])
        let enable = app.buttons["uvEnable"]
        XCTAssertTrue(enable.waitForExistence(timeout: 10))
        enable.tap()
        let card = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "UV 8 today")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        attachScreenshot("UV card")
    }

    func testCreatorKit() {
        launch()
        app.buttons["Profile and settings"].tap()
        let kit = app.buttons["Creator kit"]
        scrollTo(kit)
        kit.tap()
        XCTAssertTrue(app.buttons["reelTemplate.dayCounter"].waitForExistence(timeout: 5))
        attachScreenshot("Creator kit")
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
