import XCTest

/// The first-time tutorial (ONBOARDING-PLAN.md §5): Pimpi's coach marks, the result tour, and the first-week path.
/// Screenshots of each; run with a screen recording alongside to check the motion.
final class TutorialUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
    }

    private func launch(_ extra: [String]) {
        app.launchArguments = ["-seedDemoData", "-resetDemoData", "YES", "-tutorialOn", "YES", "-resetTutorial", "YES"] + extra
        app.launch()
        _ = app.buttons["dock.mirror"].waitForExistence(timeout: 30)
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var gotIt: XCUIElement { app.buttons["coachGotIt"] }

    func testCoachMarksOnePerScreenTwoPerSession() {
        launch([])
        XCTAssertTrue(gotIt.waitForExistence(timeout: 8), "Home offers a coach mark")
        snap("C1 Home coach")
        do {
            try app.performAccessibilityAudit(for: [.contrast, .elementDetection, .hitRegion, .sufficientElementDescription]) { issue in
                // Only the coach is judged here: everything behind the dim is the Home screen (audited elsewhere).
                guard let label = issue.element?.label else { return true }
                return !(label == "Got it" || label.contains("Show up each day"))
            }
        } catch {
            // -902: the audit isn't available on this simulator runtime; anything else is a real failure.
            let code = (error as NSError).code
            if code != -902 { XCTFail("Accessibility audit of the coach mark failed: \(error)") }
        }
        gotIt.tap()
        sleep(1)
        XCTAssertFalse(gotIt.exists)
        // Then at most one more this session, wherever it comes up (the demo data has already used some features,
        // and someone who already used a feature never gets its coach).
        var shown = 1
        for tab in ["dock.shelf", "dock.deck", "dock.mirror", "dock.shelf"] {
            app.buttons[tab].tap()
            if gotIt.waitForExistence(timeout: 4) {
                shown += 1
                snap("C\(shown) Coach on \(tab)")
                gotIt.tap()
                sleep(1)
            }
        }
        XCTAssertLessThanOrEqual(shown, 2, "No more than two coach marks a session")
    }

    func testResultTour() {
        launch(["-openLatestScan", "YES", "-resultTourDemo", "YES"])
        XCTAssertTrue(gotIt.waitForExistence(timeout: 15), "The first result gets a tour")
        for step in 1...4 {
            let hittable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: gotIt)
            wait(for: [hittable], timeout: 6)
            sleep(1)
            snap("T\(step) Result tour")
            gotIt.tap()
        }
        sleep(1)
        XCTAssertFalse(gotIt.exists, "The tour ends after four steps")
    }

    func testFirstWeekPath() {
        launch(["-firstWeekDemo", "YES"])
        if gotIt.waitForExistence(timeout: 6) { gotIt.tap() }
        let chip = app.buttons["firstWeekChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        snap("W1 Home with first-week chip")
        chip.tap()
        sleep(2)
        snap("W2 First week path")
    }
}
