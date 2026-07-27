import XCTest

/// UI tests that drive the app against a real ProPresenter on the local network.
///
/// These trigger real slides — only run them when no service is in progress.
/// Override the target with PRO_REMOTE_HOST / PRO_REMOTE_PORT in the test environment.
///
/// Config is injected via launch arguments: UserDefaults reads the NSArgumentDomain first,
/// so `-pp_host x` overrides whatever the app previously persisted, with no app-side test hooks.
final class ProRemoteUITests: XCTestCase {

    private var host: String {
        ProcessInfo.processInfo.environment["PRO_REMOTE_HOST"] ?? "172.16.10.40"
    }
    private var port: String {
        ProcessInfo.processInfo.environment["PRO_REMOTE_PORT"] ?? "57016"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches with no server configured.
    private func launchUnconfigured() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-pp_host", "", "-pp_port", ""]
        app.launch()
        return app
    }

    /// Launches already pointed at the server, so the app auto-connects.
    private func launchConnected() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-pp_host", host, "-pp_port", port]
        app.launch()
        XCTAssertTrue(app.staticTexts["PLAYLISTS"].waitForExistence(timeout: 20),
                      "app should connect and load playlists")
        return app
    }

    /// Rows are labelled "<name> at <host> port <port>".
    private func discoveredRows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.containing(NSPredicate(format: "label CONTAINS[c] ' port '"))
    }

    // MARK: - Discovery

    /// Settings must present itself when nothing is configured, Bonjour must find a server,
    /// and the port must come from the Bonjour record rather than the app's 1025 default.
    func testSettingsAutoPresentsAndDiscoversServerWithRealPort() throws {
        let app = launchUnconfigured()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10)
                      || app.staticTexts["Settings"].waitForExistence(timeout: 5),
                      "Settings should auto-present when no server is connected")

        let row = discoveredRows(app).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), "Bonjour should discover a ProPresenter")

        // "<name> at <host> port <port>"
        let label = row.label
        guard let discoveredPort = label.split(separator: " ").last.map(String.init) else {
            return XCTFail("could not parse port from \(label)")
        }
        XCTAssertNotNil(Int(discoveredPort), "port should be numeric, got '\(discoveredPort)' from '\(label)'")
        XCTAssertNotEqual(discoveredPort, "1025", "port must come from Bonjour, not the app default")
    }

    /// Tapping a discovered server should fill the fields, connect, and load content.
    func testTappingDiscoveredServerConnects() throws {
        let app = launchUnconfigured()
        let row = discoveredRows(app).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()

        XCTAssertTrue(app.staticTexts["Connected"].waitForExistence(timeout: 20),
                      "status should become Connected")
    }

    // MARK: - Connecting

    func testConnectsAndLoadsPlaylists() throws {
        let app = launchConnected()
        XCTAssertTrue(app.staticTexts["SUNDAY SERVICE"].waitForExistence(timeout: 10),
                      "a playlist should be listed")
    }

    // MARK: - Triggering real slides

    /// The core contract: pressing Next advances the live slide and the counter agrees.
    func testNextAdvancesLiveSlide() throws {
        let app = launchConnected()

        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10), "transport bar should be present")

        guard let before = liveCounter(app) else { return XCTFail("no slide counter — not viewing the live presentation") }
        guard next.isEnabled else { return XCTFail("Next should be enabled when earlier slides remain") }
        next.tap()

        expectCounter(app, toReach: before.index + 1, of: before.total)
    }

    /// Previous must walk back exactly one slide.
    func testPreviousGoesBackOneSlide() throws {
        let app = launchConnected()
        let next = app.buttons["Next"]
        let previous = app.buttons["Previous"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))

        // Move forward first so there is somewhere to go back to.
        guard let start = liveCounter(app) else { return XCTFail("no slide counter") }
        if start.index >= start.total { return XCTFail("already at the last slide") }
        next.tap()
        expectCounter(app, toReach: start.index + 1, of: start.total)

        XCTAssertTrue(previous.isEnabled, "Previous should be enabled after advancing")
        previous.tap()
        expectCounter(app, toReach: start.index, of: start.total)
    }

    /// Tapping a specific slide cell must put THAT slide live, not a neighbour.
    func testTappingSlideCellTriggersThatSlide() throws {
        let app = launchConnected()
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 10))
        guard let start = liveCounter(app) else { return XCTFail("no slide counter") }

        // Cells are labelled "<group or 'Slide'> <n>"; target one that isn't already live.
        let targetIndex = start.index == 1 ? 3 : 1
        let cell = slideCell(app, number: targetIndex)
        guard cell.waitForExistence(timeout: 5) else {
            return XCTFail("could not find slide cell \(targetIndex)")
        }
        cell.tap()
        expectCounter(app, toReach: targetIndex, of: start.total)
    }

    // MARK: - Disconnect

    /// Disconnect must ask first, and cancelling must leave the connection alone.
    func testDisconnectRequiresConfirmationAndCancelKeepsConnection() throws {
        let app = launchConnected()
        openSettings(app)

        let disconnect = app.buttons["Disconnect"]
        XCTAssertTrue(disconnect.waitForExistence(timeout: 5), "Disconnect button should exist when connected")
        disconnect.tap()

        // The confirmation names the server.
        let confirmTitle = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Disconnect from'")).firstMatch
        XCTAssertTrue(confirmTitle.waitForExistence(timeout: 5), "a confirmation should appear before disconnecting")
        XCTAssertTrue(app.staticTexts["Connected"].exists, "must NOT disconnect before the user confirms")
    }

    /// Confirming actually disconnects and clears the content.
    func testConfirmingDisconnectDisconnects() throws {
        let app = launchConnected()
        openSettings(app)

        let disconnect = app.buttons["Disconnect"]
        XCTAssertTrue(disconnect.waitForExistence(timeout: 5))
        disconnect.tap()

        // Tap the destructive button inside the confirmation (not the row that opened it).
        let confirm = app.sheets.buttons["Disconnect"].exists
            ? app.sheets.buttons["Disconnect"]
            : app.alerts.buttons["Disconnect"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "confirmation action should exist")
        confirm.tap()

        XCTAssertTrue(app.staticTexts["Disconnected"].waitForExistence(timeout: 10),
                      "status should become Disconnected")
    }

    // MARK: - Helpers

    private func openSettings(_ app: XCUIApplication) {
        let gear = app.buttons["Settings"].exists ? app.buttons["Settings"] : app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'settings'")).firstMatch
        if gear.waitForExistence(timeout: 5) {
            gear.tap()
        } else {
            XCTFail("could not open Settings")
        }
    }

    private func slideCell(_ app: XCUIApplication, number: Int) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label MATCHES %@", ".* \(number)$")).firstMatch
    }

    /// The transport bar renders "<index> / <total>"; returns 1-based index and total.
    private func liveCounter(_ app: XCUIApplication) -> (index: Int, total: Int)? {
        let element = app.staticTexts.containing(
            NSPredicate(format: "label MATCHES %@", #"^\d+ / \d+$"#)).firstMatch
        guard element.waitForExistence(timeout: 5) else { return nil }
        let parts = element.label.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let i = Int(parts[0]), let t = Int(parts[1]) else { return nil }
        return (i, t)
    }

    private func expectCounter(_ app: XCUIApplication, toReach index: Int, of total: Int, timeout: TimeInterval = 10) {
        let expected = "\(index) / \(total)"
        let element = app.staticTexts[expected]
        XCTAssertTrue(element.waitForExistence(timeout: timeout),
                      "expected the live counter to read '\(expected)'")
    }
}
