import XCTest

final class ShiftlineUITests : XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    private func launch( _ arguments : [String] ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [ "-uiTesting" ] + arguments
        app.launch()
        return app
    }

    func testFirstTimeFlowReachesTheBasicsTutorial() {
        let app = launch( [] )
        let nameField = app.textFields[ "profileNameField" ]
        XCTAssertTrue( nameField.waitForExistence( timeout : 5 ) )
        nameField.tap()
        nameField.typeText( "Racer" )
        app.buttons[ "createProfileButton" ].tap()

        let starter = app.buttons[ "starter-hayase-kite-s" ]
        XCTAssertTrue( starter.waitForExistence( timeout : 5 ) )
        starter.tap()
        app.buttons[ "confirmStarterButton" ].tap()

        XCTAssertTrue( app.buttons[ "Pause" ].waitForExistence( timeout : 10 ) )
        XCTAssertTrue( app.staticTexts[ "HOLD THE ACCELERATOR ON THE RIGHT" ].waitForExistence( timeout : 5 ) )

        app.buttons[ "Pause" ].tap()
        app.buttons[ "QUIT EVENT" ].tap()
        XCTAssertTrue( app.buttons[ "menu-Career" ].waitForExistence( timeout : 5 ) )
    }

    func testBuyingACarFromTheDealership() {
        let app = launch( [ "-debugProfile" ] )
        let dealership = app.buttons[ "menu-Dealership" ]
        XCTAssertTrue( dealership.waitForExistence( timeout : 10 ) )
        dealership.tap()

        let car = app.buttons[ "dealer-wrenfield-linnet" ]
        XCTAssertTrue( car.waitForExistence( timeout : 5 ) )
        car.tap()
        app.buttons[ "buyCarButton" ].tap()

        let confirm = app.buttons.matching( NSPredicate( format : "label BEGINSWITH 'Buy for'" ) ).firstMatch
        XCTAssertTrue( confirm.waitForExistence( timeout : 5 ) )
        confirm.tap()

        XCTAssertTrue( app.staticTexts[ "IN YOUR GARAGE" ].waitForExistence( timeout : 5 ) )
        app.buttons[ "Back" ].tap()
        app.buttons[ "menu-Garage" ].tap()
        XCTAssertTrue( app.buttons[ "garage-wrenfield-linnet" ].waitForExistence( timeout : 5 ) )
    }

    func testEnteringACareerEvent() {
        let app = launch( [ "-debugProfile" ] )
        let career = app.buttons[ "menu-Career" ]
        XCTAssertTrue( career.waitForExistence( timeout : 10 ) )
        career.tap()

        app.buttons[ "tier-0" ].tap()
        let event = app.buttons[ "event-r-sprint-1" ]
        XCTAssertTrue( event.waitForExistence( timeout : 5 ) )
        event.tap()

        let start = app.buttons[ "startRaceButton" ]
        XCTAssertTrue( start.waitForExistence( timeout : 5 ) )
        XCTAssertTrue( start.isEnabled )
        start.tap()

        XCTAssertTrue( app.buttons[ "Pause" ].waitForExistence( timeout : 10 ) )
        app.buttons[ "Pause" ].tap()
        app.buttons[ "QUIT EVENT" ].tap()
        XCTAssertTrue( app.buttons[ "startRaceButton" ].waitForExistence( timeout : 5 ) )
    }

    func testRaceToResultsFlow() {
        let app = launch( [ "-debugProfile", "-debugRace", "kestrel-eighth", "drag", "-debugAutopilot" ] )
        let continueButton = app.buttons[ "CONTINUE" ]
        XCTAssertTrue( continueButton.waitForExistence( timeout : 60 ) )
        XCTAssertTrue( app.staticTexts[ "REWARDS" ].exists )
        continueButton.tap()
        XCTAssertTrue( app.buttons[ "menu-Career" ].waitForExistence( timeout : 5 ) )
    }
}
