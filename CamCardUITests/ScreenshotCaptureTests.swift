import XCTest

final class ScreenshotCaptureTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureReadmeScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetStore", "-uiTestSeedFixture", "three"]
        app.launch()

        XCTAssertTrue(app.staticTexts["张三"].waitForExistence(timeout: 15))
        snap(named: "01-card-holder")

        app.staticTexts["张三"].tap()
        XCTAssertTrue(app.navigationBars["张三"].waitForExistence(timeout: 15))
        snap(named: "02-card-detail")

        app.buttons["detailEditButton"].tap()
        XCTAssertTrue(app.textFields["reviewField-name"].waitForExistence(timeout: 15))
        snap(named: "03-review")

        app.terminate()
        app.launchArguments = ["-uiTestResetStore"]
        app.launch()
        XCTAssertTrue(app.staticTexts["还没有名片"].waitForExistence(timeout: 15))
        snap(named: "04-empty")
    }

    @MainActor
    private func snap(named name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}