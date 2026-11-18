import XCTest

/// End-to-end smoke of the core flows on seeded demo data (the Simulator has no camera, so scanning itself is
/// verified on device; here we verify the camera-unavailable path is handled gracefully).
final class CoreFlowsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-seedDemoData"]
        // The Mirror asks for camera access on launch (system alert).
        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            for title in ["Allow", "OK", "Don’t Allow"] where alert.buttons[title].firstMatch.exists {
                alert.buttons[title].firstMatch.tap()
                return true
            }
            return false
        }
        app.launch()
    }

    func testMirrorShowsLatestScanAndShutter() {
        XCTAssertTrue(app.buttons["mirrorIndex"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["mirrorShutter"].exists)
        XCTAssertTrue(app.buttons["dock.mirror"].isSelected)
        attachScreenshot("Mirror")
    }

    /// Timeline rows read like "Tue, Nov 17, Mild, 1 fewer".
    private var scanRows: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label CONTAINS ', Calm' OR label CONTAINS ', Mild' OR label CONTAINS ', Active' OR label CONTAINS ', Flared'"))
    }

    func testTimelineOpensScanDetail() {
        openDock("dock.deck")
        let firstRow = scanRows.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10))
        attachScreenshot("Timeline")
        firstRow.tap()
        XCTAssertTrue(app.buttons["What changed"].waitForExistence(timeout: 10))
        app.buttons["What we noticed"].tap()
        attachScreenshot("Scan detail")
    }

    func testLatestScanShows3DView() {
        let index = app.buttons["mirrorIndex"]
        XCTAssertTrue(index.waitForExistence(timeout: 10))
        let toggle = app.switches["3D view"]
        // The first tap may be consumed by the camera-permission alert's interruption monitor.
        for _ in 0..<3 where !toggle.exists {
            index.tap()
            _ = toggle.waitForExistence(timeout: 4)
        }
        XCTAssertTrue(toggle.exists)
        // Scans with a 3D scan open on it.
        XCTAssertTrue(app.staticTexts["Drag to turn · pinch to zoom · double-tap to reset"].waitForExistence(timeout: 10))
        attachScreenshot("3D view")
    }

    func testCompareTwoScans() {
        openDock("dock.deck")
        XCTAssertTrue(app.buttons["Compare"].waitForExistence(timeout: 10))
        app.buttons["Compare"].tap()
        XCTAssertTrue(scanRows.element(boundBy: 0).waitForExistence(timeout: 10))
        scanRows.element(boundBy: 0).tap()
        scanRows.element(boundBy: 1).tap()
        let compare = app.buttons["Compare these two"]
        XCTAssertTrue(compare.waitForExistence(timeout: 10))
        compare.tap()
        XCTAssertTrue(app.staticTexts["By type"].waitForExistence(timeout: 10))
        attachScreenshot("Compare")
    }

    func testShelfSearchFindsByIngredient() {
        openDock("dock.shelf")
        let field = app.textFields["shelfSearch"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("niacinamide")
        let result = app.buttons.matching(identifier: "shelfResult").firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        attachScreenshot("Shelf search")
        result.tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 10))
        attachScreenshot("Product check")
    }

    func testMirrorWithoutCameraFailsGracefully() {
        XCTAssertTrue(app.buttons["mirrorShutter"].waitForExistence(timeout: 10))
        let unavailable = app.staticTexts["Camera unavailable — scan on a real iPhone."]
        let denied = app.staticTexts["Camera access is off"]
        let deadline = Date.now.addingTimeInterval(15)
        while Date.now < deadline, !unavailable.exists, !denied.exists {
            app.tap() // lets the interruption monitor handle the permission alert
            _ = unavailable.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(unavailable.exists || denied.exists)
        if unavailable.exists { XCTAssertFalse(app.buttons["mirrorShutter"].isEnabled) }
        attachScreenshot("Mirror (no camera)")
    }

    func testDockMovesBetweenPages() {
        openDock("dock.shelf")
        XCTAssertTrue(app.buttons["dock.shelf"].isSelected)
        attachScreenshot("Shelf")
        openDock("dock.mirror")
        XCTAssertTrue(app.buttons["mirrorShutter"].waitForExistence(timeout: 10))
    }

    func testAccessibilityAuditOnMirror() throws {
        XCTAssertTrue(app.buttons["mirrorIndex"].waitForExistence(timeout: 10))
        do {
            try app.performAccessibilityAudit(for: [.dynamicType, .elementDetection, .hitRegion, .sufficientElementDescription]) { issue in
                // The live camera layer has no accessible content by design.
                issue.element?.elementType == .other && issue.element?.label.isEmpty == true
            }
        } catch let error as NSError where error.domain == "com.apple.accessibilityAudit" && error.code == -902 {
            throw XCTSkip("Accessibility audit unavailable on this simulator runtime: \(error.localizedDescription)")
        }
    }

    /// The floating Mirror · Deck · Shelf dock (same on every width and pose).
    private func openDock(_ identifier: String) {
        let item = app.buttons[identifier]
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        item.tap()
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
