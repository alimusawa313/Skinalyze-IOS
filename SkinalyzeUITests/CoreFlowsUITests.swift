import XCTest

/// End-to-end smoke of the core flows on seeded demo data (the Simulator has no camera, so scanning itself is
/// verified on device; here we verify the camera-unavailable path is handled gracefully).
final class CoreFlowsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // A fresh, complete set of demo scans for every test (an earlier test may have ended mid-seed).
        app.launchArguments = ["-seedDemoData", "-resetDemoData", "YES"]
        // Starting a scan asks for camera access (system alert).
        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            for title in ["Allow", "OK", "Don’t Allow"] where alert.buttons[title].firstMatch.exists {
                alert.buttons[title].firstMatch.tap()
                return true
            }
            return false
        }
        app.launch()
        waitForDemoData()
    }

    /// Demo scans are saved one by one, oldest first; the Mirror shows the newest (index 1) once all are in.
    /// Waiting avoids screens rebuilding (and sheets closing) while scans are still arriving.
    private func waitForDemoData(newestIndex: String = "1,") {
        let index = app.buttons["mirrorIndex"]
        let done = NSPredicate(format: "label BEGINSWITH %@", newestIndex)
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: done, object: index)], timeout: 30)
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

    /// A scan can be shared as a card, and hiding the face makes a new picture before sharing is offered again.
    func testShareSkinCardWithFaceHidden() {
        openDock("dock.deck")
        let firstRow = scanRows.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10))
        firstRow.tap()
        let share = app.buttons["shareCard"].firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        // Scans with a 3D head open a menu first (card or turntable).
        let cardItem = app.buttons["Skin card"]
        if cardItem.waitForExistence(timeout: 3) { cardItem.tap() }
        let preview = app.images["shareCardPreview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["shareCardButton"].waitForExistence(timeout: 5))
        attachScreenshot("Share card")
        // The row's label does not flip the switch; tap the switch itself at the trailing edge.
        app.switches["shareHideFace"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertTrue(app.images["Preview of your card with your face hidden"].waitForExistence(timeout: 20))
        app.buttons["Square"].tap()
        XCTAssertTrue(app.images["Preview of your card with your face hidden"].waitForExistence(timeout: 20))
        attachScreenshot("Share card · face hidden")
    }

    /// The glow-up reel is made from the Deck and offered for sharing once it is ready.
    func testGlowUpReelIsMade() {
        openDock("dock.deck")
        let reel = app.buttons["deckReel"]
        XCTAssertTrue(reel.waitForExistence(timeout: 10))
        reel.tap()
        XCTAssertTrue(app.buttons["videoShareButton"].waitForExistence(timeout: 60))
        attachScreenshot("Glow-up reel")
    }

    /// Relaunches with extra arguments (a free account, or a scan already taken today).
    private func relaunch(_ extra: [String]) {
        app.terminate()
        app.launchArguments = ["-seedDemoData", "-resetDemoData", "YES"] + extra
        app.launch()
        waitForDemoData()
    }

    /// Pimpi's streak sheet shows today's quests; a chest opens into an outfit Pimpi can wear.
    func testQuestsChestAndWardrobe() {
        relaunch(["-questDebugChests", "1", "-proOverride", "free"])
        let pimpi = app.buttons["pimpiStreak"]
        XCTAssertTrue(pimpi.waitForExistence(timeout: 10))
        for _ in 0..<3 where !app.staticTexts["Today's quests"].exists {
            pimpi.tap()
            _ = app.staticTexts["Today's quests"].waitForExistence(timeout: 3)
        }
        XCTAssertTrue(app.staticTexts["Today's quests"].exists)
        attachScreenshot("Quests")
        let open = app.buttons["openChest"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        let chest = app.buttons["chestOpen"]
        XCTAssertTrue(chest.waitForExistence(timeout: 5))
        attachScreenshot("Chest · closed")
        chest.tap()
        // A new outfit to wear — or, once every free outfit is owned (as on a reused Simulator), bonus points.
        let wear = app.buttons["chestWear"]
        let bonus = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'glow points instead'")).firstMatch
        XCTAssertTrue(wear.waitForExistence(timeout: 5) || bonus.exists)
        sleep(1)
        attachScreenshot("Chest · opened")
        if wear.exists { wear.tap() } else { app.buttons["Done"].firstMatch.tap() }
        let wardrobe = app.buttons["wardrobeLink"]
        for _ in 0..<4 where !wardrobe.isHittable { app.swipeUp() }
        attachScreenshot("Badges")
        wardrobe.tap()
        XCTAssertTrue(app.navigationBars["Wardrobe"].waitForExistence(timeout: 5))
        attachScreenshot("Wardrobe")
    }

    /// Free accounts: after today's saved scan, the shutter explains Pro and the camera stays on.
    func testSecondScanTodayOpensPaywall() {
        relaunch(["-proOverride", "free", "-demoNewestDaysAgo", "0"])
        let note = app.staticTexts["Next free scan at midnight"]
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        let shutter = app.buttons["mirrorShutter"]
        XCTAssertTrue(shutter.isEnabled)
        shutter.tap()
        XCTAssertTrue(app.buttons["paywallClose"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Restore purchases"].exists)
        attachScreenshot("Paywall · scan limit")
        app.buttons["paywallClose"].tap()
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
    }

    /// Profile opens the paywall; the plans come from the App Store (the local StoreKit file here).
    func testPaywallFromProfile() {
        relaunch(["-proOverride", "free"])
        XCTAssertTrue(app.buttons["mirrorIndex"].waitForExistence(timeout: 10))
        app.buttons["Profile and settings"].tap()
        let pro = app.buttons["profilePro"]
        XCTAssertTrue(pro.waitForExistence(timeout: 10))
        pro.tap()
        XCTAssertTrue(app.buttons["paywallClose"].waitForExistence(timeout: 10))
        let plans = app.buttons["plan.com.Patani.Skinalyze.pro.annual"]
        let unavailable = app.otherElements["paywallUnavailable"]
        _ = plans.waitForExistence(timeout: 10)
        XCTAssertTrue(plans.exists || unavailable.exists)
        attachScreenshot("Paywall · profile")
    }

    /// Turning the 3D head asks for Pro on a free account.
    func testTurning3DAsksForPro() {
        relaunch(["-proOverride", "free"])
        let index = app.buttons["mirrorIndex"]
        XCTAssertTrue(index.waitForExistence(timeout: 10))
        let hint = app.staticTexts["Drag to turn · pinch to zoom · double-tap to reset"]
        for _ in 0..<3 where !hint.exists {
            index.tap()
            _ = hint.waitForExistence(timeout: 4)
        }
        XCTAssertTrue(hint.exists)
        let head = hint.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -4))
        head.press(forDuration: 0.1, thenDragTo: hint.coordinate(withNormalizedOffset: CGVector(dx: 1.4, dy: -4)))
        XCTAssertTrue(app.buttons["paywallClose"].waitForExistence(timeout: 10))
        attachScreenshot("Paywall · 3D turn")
    }

    /// A scan with a 3D head can be exported as a turntable video.
    func testTurntableIsMade() {
        relaunch(["-proOverride", "pro"])
        openDock("dock.deck")
        let firstRow = scanRows.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10))
        firstRow.tap()
        let share = app.buttons["shareCard"].firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        let item = app.buttons["3D turntable"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
        XCTAssertTrue(app.buttons["videoShareButton"].waitForExistence(timeout: 60))
        attachScreenshot("3D turntable")
    }

    /// Skin School from the Shelf: path → lesson cards → two questions → result with XP and sources.
    private func takeFirstLesson(_ label: String) {
        openDock("dock.shelf")
        let card = app.buttons["skinSchoolCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        let first = app.buttons["lesson.how-a-spot-starts"]
        sleep(1) // let the Shelf finish sliding in, so the tap lands on the card
        // Tap again only while the card is still on screen (the path covers it once open).
        for _ in 0..<3 where !first.exists && card.exists {
            card.tap()
            _ = first.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(first.exists)
        attachScreenshot("School path\(label)")
        first.tap()
        let next = app.buttons["lessonContinue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        attachScreenshot("Lesson card\(label)")
        for _ in 0..<4 { next.tap() } // four cards
        for question in 0..<2 {
            let option = app.buttons["quizOption.0"]
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.tap()
            if question == 0 { attachScreenshot("Lesson quiz\(label)") }
            next.tap()
        }
        XCTAssertTrue(app.staticTexts["Lesson done!"].waitForExistence(timeout: 5))
        attachScreenshot("Lesson done\(label)")
        next.tap()
    }

    func testSkinSchoolLesson() {
        takeFirstLesson("")
    }

    func testSkinSchoolAtLargestText() {
        app.terminate()
        app.launchArguments = ["-seedDemoData", "-resetDemoData", "YES",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        waitForDemoData()
        takeFirstLesson(" · AX5")
    }

    /// Pro: the zone map opens from the Deck and scrubs through the scans.
    func testZoneMap() {
        // DEBUG_MESH_DIR (passed as TEST_RUNNER_DEBUG_MESH_DIR): check the glows on a real captured head.
        let mesh = ProcessInfo.processInfo.environment["DEBUG_MESH_DIR"].map { ["-debugMeshDir", $0] } ?? []
        relaunch(["-proOverride", "pro"] + mesh)
        openDock("dock.deck")
        let button = app.buttons["deckZoneMap"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 10))
        sleep(2)
        attachScreenshot("Zone map · newest")
        slider.adjust(toNormalizedSliderPosition: 0)
        sleep(1)
        attachScreenshot("Zone map · oldest")
    }

    /// Pro: a tapped spot on a scan photo opens the same area across every scan.
    func testAreaOverTime() {
        relaunch(["-proOverride", "pro"])
        openDock("dock.deck")
        let firstRow = scanRows.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10))
        firstRow.tap()
        let toggle = app.switches["3D view"]
        if toggle.waitForExistence(timeout: 5), (toggle.value as? String) == "1" { toggle.tap() }
        let pin = app.buttons.matching(identifier: "spotPin").firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        pin.tap()
        let follow = app.buttons["followArea"]
        XCTAssertTrue(follow.waitForExistence(timeout: 5))
        follow.tap()
        XCTAssertTrue(app.navigationBars["This area over time"].waitForExistence(timeout: 10))
        sleep(3)
        attachScreenshot("Area over time")
    }

    /// Compare can be shared as a before/after slider video.
    func testSliderVideoIsMade() {
        openDock("dock.deck")
        XCTAssertTrue(app.buttons["Compare"].waitForExistence(timeout: 10))
        app.buttons["Compare"].tap()
        XCTAssertTrue(scanRows.element(boundBy: 0).waitForExistence(timeout: 10))
        scanRows.element(boundBy: 0).tap()
        scanRows.element(boundBy: 1).tap()
        app.buttons["Compare these two"].tap()
        let share = app.buttons["compareShare"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: share)
        waitForExpectations(timeout: 15)
        share.tap()
        app.buttons["Slider video"].tap()
        XCTAssertTrue(app.buttons["videoShareButton"].waitForExistence(timeout: 60))
        attachScreenshot("Slider video")
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

    /// Home never opens the camera; asking for a scan does. Without one, Home says so and the button turns off.
    func testMirrorWithoutCameraFailsGracefully() {
        let shutter = app.buttons["mirrorShutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 10))
        let unavailable = app.staticTexts["Camera unavailable — scan on a real iPhone."]
        let denied = app.staticTexts["Camera access is off"]
        let deadline = Date.now.addingTimeInterval(15)
        while Date.now < deadline, !unavailable.exists, !denied.exists {
            // Asks for the camera. While the scan screen is up (Scan hidden), a tap lets the interruption monitor
            // handle the permission alert.
            if shutter.exists, shutter.isEnabled { shutter.tap() } else { app.tap() }
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
