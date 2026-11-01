import XCTest

final class CamCardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    @MainActor
    private func launchSeeded() -> XCUIApplication {
        launch(["-uiTestResetStore", "-uiTestSeedFixture", "three"])
    }

    @MainActor
    private func any(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    @MainActor
    func testR01ColdLaunchShowsEmptyCardHolder() throws {
        let app = launch(["-uiTestResetStore"])
        XCTAssertTrue(app.staticTexts["还没有名片"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["拍摄名片"].exists)
        XCTAssertTrue(app.buttons["从相册导入"].exists)
    }

    @MainActor
    func testR03CameraPermissionDeniedKeepsPhotoImportAvailable() throws {
        let app = launch(["-uiTestResetStore", "-uiTestSkipCamera"])
        XCTAssertTrue(app.staticTexts["还没有名片"].waitForExistence(timeout: 10))
        app.buttons["拍摄名片"].tap()

        let alert = app.alerts["需要相机权限"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.buttons["从相册导入"].exists)
        XCTAssertTrue(alert.buttons["打开设置"].exists)
    }

    @MainActor
    func testR04CancelCaptureReturnsToEmptyHolder() throws {
        let app = launch(["-uiTestResetStore", "-uiTestSkipCamera"])
        XCTAssertTrue(app.staticTexts["还没有名片"].waitForExistence(timeout: 10))
        app.buttons["拍摄名片"].tap()
        let alert = app.alerts["需要相机权限"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["还没有名片"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testR08ToR13DetailShowsOnlyFinalValues() throws {
        let app = launchSeeded()
        XCTAssertTrue(app.staticTexts["张三"].waitForExistence(timeout: 10))
        app.staticTexts["张三"].tap()

        XCTAssertTrue(app.navigationBars["张三"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["张三"].exists)
        XCTAssertTrue(app.staticTexts["星河科技有限公司"].exists)
        XCTAssertTrue(app.staticTexts["13800138000"].exists)
        XCTAssertTrue(app.staticTexts["010-88886666"].exists)
        XCTAssertTrue(app.staticTexts["010-88887777"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "zhangsan@xinghe.com")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["www.xinghe.com"].exists)
        XCTAssertTrue(app.staticTexts["北京市朝阳区建国路88号"].exists)
        XCTAssertTrue(app.staticTexts["100022"].exists)
        XCTAssertTrue(app.staticTexts["重点客户"].exists)
        XCTAssertTrue(app.staticTexts["客户"].exists)

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["王五"].waitForExistence(timeout: 10))
        app.staticTexts["王五"].tap()
        XCTAssertTrue(app.navigationBars["王五"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "wangwu@example.com")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["网站"].exists)
        XCTAssertFalse(app.staticTexts["地址"].exists)
        XCTAssertFalse(app.staticTexts["备注"].exists)
    }

    @MainActor
    func testR14EditingUpdatesCardWithoutAddingAnother() throws {
        let app = launchSeeded()
        XCTAssertTrue(app.staticTexts["张三"].waitForExistence(timeout: 10))
        app.staticTexts["张三"].tap()
        XCTAssertTrue(app.buttons["编辑"].waitForExistence(timeout: 10))
        app.buttons["编辑"].tap()

        let nameField = app.textFields["reviewField-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        nameField.typeText("张三丰")
        app.buttons["reviewSaveButton"].tap()

        XCTAssertTrue(app.navigationBars["张三丰"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["张三丰"].exists)

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["张三丰"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "张三丰")).count, 1)
    }

    @MainActor
    func testR15DeleteRequiresConfirmationAndRemovesCard() throws {
        let app = launchSeeded()
        XCTAssertTrue(app.staticTexts["李四"].waitForExistence(timeout: 10))
        app.staticTexts["李四"].tap()
        XCTAssertTrue(app.buttons["删除名片"].waitForExistence(timeout: 10))
        app.buttons["删除名片"].tap()

        let deleteButton = app.buttons["删除"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
        deleteButton.tap()

        XCTAssertTrue(app.staticTexts["张三"].waitForExistence(timeout: 10))
        let gone = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: app.staticTexts["李四"]
        )
        wait(for: [gone], timeout: 10)
    }

    @MainActor
    func testR16SearchAndTagFilter() throws {
        let app = launchSeeded()
        XCTAssertTrue(app.staticTexts["张三"].waitForExistence(timeout: 10))

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("云")
        XCTAssertTrue(app.staticTexts["李四"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["张三"].exists)
    }

    @MainActor
    func testR16bTagFilter() throws {
        let app = launchSeeded()
        XCTAssertTrue(app.staticTexts["张三"].waitForExistence(timeout: 10))
        app.buttons["标签筛选"].tap()
        let customer = app.buttons.matching(NSPredicate(format: "label == %@", "客户")).firstMatch
        XCTAssertTrue(customer.waitForExistence(timeout: 10))
        customer.tap()
        XCTAssertTrue(app.staticTexts["张三"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["王五"].exists)
        XCTAssertFalse(app.staticTexts["李四"].exists)
    }

    @MainActor
    func testR17TagAndSortControlsAreAvailable() throws {
        let app = launchSeeded()
        XCTAssertTrue(app.staticTexts["张三"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["排序"].exists)
        XCTAssertTrue(app.buttons["标签筛选"].exists)
        app.buttons["排序"].tap()
        let nameSort = app.buttons.matching(NSPredicate(format: "label == %@", "姓名")).firstMatch
        XCTAssertTrue(nameSort.waitForExistence(timeout: 10))
        nameSort.tap()
        XCTAssertTrue(app.staticTexts["张三"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testR20ExportFailureShowsMessageAndKeepsData() throws {
        let app = launch([
            "-uiTestResetStore",
            "-uiTestSeedFixture", "three",
            "-uiTestForceExportFailure"
        ])
        XCTAssertTrue(app.staticTexts["张三"].waitForExistence(timeout: 10))
        app.buttons["选择"].tap()
        app.staticTexts["张三"].tap()
        app.buttons["导出"].tap()
        XCTAssertTrue(app.alerts["提示"].waitForExistence(timeout: 10))
        app.alerts["提示"].buttons["好"].tap()
        XCTAssertTrue(app.staticTexts["张三"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testR18NotesAndRawTextAreReachable() throws {
        let app = launchSeeded()
        XCTAssertTrue(app.staticTexts["张三"].waitForExistence(timeout: 10))
        app.staticTexts["张三"].tap()
        let notes = app.staticTexts["重点客户"]
        XCTAssertTrue(notes.waitForExistence(timeout: 10))
        app.buttons["查看 OCR 原始文本"].tap()
        XCTAssertTrue(app.staticTexts["OCR 原始文本"].waitForExistence(timeout: 10))
    }
}
