import XCTest

/// End-to-end smoke of the core flows on seeded demo data (the Simulator has no camera, so scanning itself is
/// verified on device; here we verify the camera-unavailable path is handled gracefully).
final class CoreFlowsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-seedDemoData"]
        app.launch()
    }

    func testTodayShowsLatestScan() {
        XCTAssertTrue(app.staticTexts["Latest scan"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Breakout index"].firstMatch.exists)
        attachScreenshot("Today")
    }

    /// Timeline rows read like "Tue, Nov 17, Mild, 1 fewer".
    private var scanRows: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label CONTAINS ', Calm' OR label CONTAINS ', Mild' OR label CONTAINS ', Active' OR label CONTAINS ', Flared'"))
    }

    func testTimelineOpensScanDetail() {
        openTab("Timeline")
        let firstRow = scanRows.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10))
        attachScreenshot("Timeline")
        firstRow.tap()
        XCTAssertTrue(app.staticTexts["What we noticed"].waitForExistence(timeout: 10))
        attachScreenshot("Scan detail")
    }

    func testLatestScanShows3DView() {
        XCTAssertTrue(app.staticTexts["Latest scan"].waitForExistence(timeout: 10))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Latest scan'")).firstMatch.tap()
        let toggle = app.switches["3D view"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.tap()
        XCTAssertTrue(app.staticTexts["Drag to turn · pinch to zoom · double-tap to reset"].waitForExistence(timeout: 10))
        attachScreenshot("3D view")
    }

    func testCompareTwoScans() {
        openTab("Timeline")
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

    func testSearchFindsByIngredient() {
        openTab("Search")
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("niacinamide")
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10))
        app.cells.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 10))
        attachScreenshot("Product check")
    }

    func testScanWithoutCameraFailsGracefully() {
        // Fresh installs ask for camera access first (system alert).
        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            for title in ["Allow", "OK", "Don’t Allow"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
        XCTAssertTrue(app.buttons["Scan my skin"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Scan my skin"].firstMatch.tap()
        let unavailable = app.staticTexts["Camera unavailable"]
        let denied = app.staticTexts["Camera access is off"]
        let deadline = Date.now.addingTimeInterval(15)
        while Date.now < deadline, !unavailable.exists, !denied.exists {
            app.tap() // lets the interruption monitor handle the permission alert
            _ = unavailable.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(unavailable.exists || denied.exists)
        attachScreenshot("Scan (no camera)")
    }

    func testAccessibilityAuditOnToday() throws {
        XCTAssertTrue(app.staticTexts["Latest scan"].waitForExistence(timeout: 10))
        do {
            try app.performAccessibilityAudit(for: [.dynamicType, .elementDetection, .hitRegion, .sufficientElementDescription]) { issue in
                // System tab bar / bottom accessory internals are owned by UIKit.
                issue.element?.elementType == .tabBar
            }
        } catch let error as NSError where error.domain == "com.apple.accessibilityAudit" && error.code == -902 {
            throw XCTSkip("Accessibility audit unavailable on this simulator runtime: \(error.localizedDescription)")
        }
    }

    /// Tab bar on compact widths; sidebar on regular widths (e.g. iPhone Duo open, `.sidebarAdaptable`).
    private func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 3) {
            tab.tap()
            return
        }
        let sidebarItem = app.buttons.matching(identifier: name).firstMatch
        if sidebarItem.waitForExistence(timeout: 3) {
            sidebarItem.tap()
        } else {
            app.staticTexts[name].firstMatch.tap()
        }
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
