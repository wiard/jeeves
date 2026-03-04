import XCTest

final class jeevesUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {}

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testKnowledgeCardVisibleInHouse() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MOCK"] = "1"
        app.launch()

        let mockButton = app.buttons["Gebruik mock modus"]
        if mockButton.waitForExistence(timeout: 3.0) {
            mockButton.tap()
        }

        let houseTab = app.tabBars.buttons["Huis"]
        if houseTab.waitForExistence(timeout: 5.0) {
            houseTab.tap()
        } else {
            let moreTab = app.tabBars.buttons["More"]
            XCTAssertTrue(moreTab.waitForExistence(timeout: 5.0))
            moreTab.tap()
            let houseCell = app.tables.staticTexts["Huis"]
            XCTAssertTrue(houseCell.waitForExistence(timeout: 5.0))
            houseCell.tap()
        }

        let knowledgeTitle = app.staticTexts["Observatory / Knowledge"]
        XCTAssertTrue(knowledgeTitle.waitForExistence(timeout: 8.0))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
