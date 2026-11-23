import XCTest

/// Friends, leagues and invites (E15, E16, G8) on the in-memory demo service (`-socialDemo YES`), since the
/// Simulator has no iCloud account. The real iCloud public database is checked on the owner's phone.
final class SocialUITests: XCTestCase {
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
        app.launchArguments = ["-seedDemoData", "-resetDemoData", "YES", "-demoActivity", "YES", "-socialDemo", "YES",
                               "-socialState", "", "-recapToday", "2026-11-25", "-startTab", "products"]
        app.launch()
        _ = app.descendants(matching: .any)["shelfView"].waitForExistence(timeout: 30)
        sleep(4)
    }

    private func openSocial() {
        let card = app.buttons["journeyCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        let entry = app.buttons["socialEntry"]
        for _ in 0..<6 where !entry.isHittable { app.swipeUp() }
        entry.tap()
    }

    /// Opt in, see the demo friends' streaks and the friend quest, add a friend by code, then the league.
    func testJoinFriendsAndLeague() {
        openSocial()
        let join = app.buttons["socialJoin"]
        XCTAssertTrue(join.waitForExistence(timeout: 10))
        attachScreenshot("Social · join")
        join.tap()
        let field = app.textFields["friendCodeField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("frnd-22")
        app.buttons["addFriend"].tap()
        // An earlier run may already have added this friend (the list comes back through iCloud).
        let added = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["Friend added!", "Already your friend."])).firstMatch
        XCTAssertTrue(added.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("paws33")
        app.buttons["addFriend"].tap()
        sleep(2)
        attachScreenshot("Social · friends")
        app.swipeUp()
        attachScreenshot("Social · friends lower")
        app.buttons["League"].tap()
        let you = app.staticTexts["You"]
        XCTAssertTrue(you.waitForExistence(timeout: 10))
        attachScreenshot("Social · league")
        app.swipeUp()
        attachScreenshot("Social · league lower")
    }

    /// A wrong code is explained, not silently ignored.
    func testInvalidCode() {
        openSocial()
        app.buttons["socialJoin"].tap()
        let field = app.textFields["friendCodeField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("ABC")
        app.buttons["addFriend"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "That code doesn't look right"))
            .firstMatch.waitForExistence(timeout: 5))
    }

    /// Opening an invite link asks to join and add the friend, and offers the free month.
    func testInviteLink() {
        app.open(URL(string: "skinalyze://friend/MATE44")!)
        let title = app.staticTexts["A friend invited you"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        attachScreenshot("Invite")
        app.buttons["Join and add friend"].tap()
        XCTAssertTrue(app.staticTexts["Friend added!"].waitForExistence(timeout: 10))
        attachScreenshot("Invite · added")
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
