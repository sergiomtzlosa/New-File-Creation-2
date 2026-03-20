import AppKit
import CoreGraphics
import XCTest

final class NFCApplicationUITests: XCTestCase {
    private var root: URL!
    private var support: URL!
    private var inbox: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nfc-ui-\(UUID().uuidString)", isDirectory: true)
        support = root.appendingPathComponent("support", isDirectory: true)
        inbox = root.appendingPathComponent("inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

        let config: [String: Any] = [
            "schemaVersion": 2,
            "revision": 0,
            "settings": [
                "defaultBaseName": "Untitled",
                "defaultDirectory": inbox.path,
                "didSeedBundledTemplates": false,
                "globalShortcut": "none",
                "revealAfterCreate": false,
                "openAfterCreate": false,
                "showToast": false,
                "playSound": false,
                "keepQuickPanelOpenAfterDrop": false,
                "onboardingCompleted": true
            ],
            "templates": []
        ]
        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: support.appendingPathComponent("config.json"))

        addUIInterruptionMonitor(withDescription: "Dismiss system alerts") { alert in
            for title in ["Don’t Allow", "Don't Allow", "OK", "Allow"] {
                let button = alert.buttons[title]
                if button.exists {
                    button.click()
                    return true
                }
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        if let root {
            try? FileManager.default.removeItem(at: root)
        }
        try super.tearDownWithError()
    }

    private func launchWithQuickPanel() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NFC_SUPPORT_DIR"] = support.path
        app.launchEnvironment["NFC_UI_TEST_OPEN_QUICK_PANEL"] = "1"
        app.launch()
        return app
    }

    private func requireQuickPanel(in app: XCUIApplication) -> XCUIElement {
        let quickPanel = app.dialogs["Quick New File"]
        XCTAssertTrue(quickPanel.waitForExistence(timeout: 10), "Quick panel should open")
        return quickPanel
    }

    private func requireWelcome(in app: XCUIApplication) -> XCUIElement {
        let dialog = app.dialogs["Get Started"]
        if dialog.waitForExistence(timeout: 4) {
            return dialog
        }
        let window = app.windows["Get Started"]
        XCTAssertTrue(window.waitForExistence(timeout: 4), "Get Started should open")
        return window
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval) {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed,
                       "Element should disappear")
    }

    private func saveScreenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: url)
            print("SCREENSHOT: \(url.path)")
        } catch {
            print("SCREENSHOT FAILED: \(error)")
        }
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testQuickPanelTitleIsCenteredAndGearOpensSettings() throws {
        let app = launchWithQuickPanel()
        let quickPanel = requireQuickPanel(in: app)
        saveScreenshot("nfc-ui-quick-panel")

        let title = quickPanel.staticTexts.matching(identifier: "QuickPanelTitle").firstMatch
        XCTAssertTrue(title.exists)
        let close = quickPanel.buttons["_XCUI:CloseWindow"]
        XCTAssertTrue(close.exists)
        XCTAssertGreaterThanOrEqual(title.frame.minX, close.frame.maxX + 20,
                                    "The centered title must clear the window close button")
        XCTAssertEqual(title.frame.midX, quickPanel.frame.midX, accuracy: 1.0,
                       "The title should be centered in the top bar")

        let gear = quickPanel.buttons["QuickPanelPreferencesButton"]
        XCTAssertTrue(gear.exists)
        gear.click()

        XCTAssertFalse(quickPanel.exists, "The gear should close the quick panel")
        let settings = app.windows["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "Gear should open Settings")
        saveScreenshot("nfc-ui-settings")

        let closeSettings = settings.buttons["_XCUI:CloseWindow"]
        if closeSettings.exists {
            closeSettings.click()
        } else {
            app.typeKey("w", modifierFlags: .command)
        }
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5) ||
                      app.state == .runningForeground,
                      "Closing Settings must not quit the app")
    }

    func testQuickPanelAppIconOpensGetStartedAndInspectorAside() throws {
        let app = launchWithQuickPanel()
        let quickPanel = requireQuickPanel(in: app)

        let getStarted = quickPanel.buttons["QuickPanelGetStartedButton"]
        XCTAssertTrue(getStarted.exists, "The app icon should open Get Started")
        XCTAssertEqual(getStarted.label, "Get Started")
        getStarted.click()

        waitForDisappearance(quickPanel, timeout: 4)
        let welcome = requireWelcome(in: app)
        XCTAssertTrue(welcome.staticTexts["Welcome to New File Creation 2"].exists)
        XCTAssertTrue(welcome.buttons["WelcomeGetStartedButton"].exists)
        XCTAssertTrue(welcome.buttons["WelcomeSettingsButton"].exists)

        let inspector = welcome.buttons["WelcomeInspectorButton"]
        XCTAssertTrue(inspector.exists)
        XCTAssertFalse(welcome.staticTexts["At a glance"].exists, "The aside starts hidden")
        let widthBefore = welcome.frame.width

        inspector.click()
        XCTAssertTrue(welcome.staticTexts["At a glance"].waitForExistence(timeout: 3))
        XCTAssertGreaterThan(welcome.frame.width, widthBefore,
                             "Opening the aside should widen the window instead of overlapping content")

        inspector.click()
        waitForDisappearance(welcome.staticTexts["At a glance"], timeout: 3)
        XCTAssertEqual(welcome.frame.width, widthBefore, accuracy: 1.0)
        saveScreenshot("nfc-ui-get-started")
    }

    func testSettingsHelpTabResizesWindowAndOpensGetStarted() throws {
        let app = launchWithQuickPanel()
        let quickPanel = requireQuickPanel(in: app)

        quickPanel.buttons["QuickPanelPreferencesButton"].click()
        let settings = app.windows["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        let generalSize = settings.frame.size

        let helpTab = settings.buttons["Help"]
        XCTAssertTrue(helpTab.exists, "Settings should expose the Help tab")
        helpTab.click()

        XCTAssertTrue(settings.staticTexts["Help and getting started"].waitForExistence(timeout: 4))
        XCTAssertTrue(settings.buttons["HelpShowGetStartedButton"].exists)
        XCTAssertTrue(settings.buttons["HelpOpenTemplatesButton"].exists)
        let helpSize = settings.frame.size
        XCTAssertTrue(generalSize.width != helpSize.width || generalSize.height != helpSize.height,
                      "The Settings window should resize for the selected pane")
        saveScreenshot("nfc-ui-settings-help")

        settings.buttons["HelpShowGetStartedButton"].click()
        waitForDisappearance(settings, timeout: 4)
        let welcome = requireWelcome(in: app)
        XCTAssertTrue(welcome.staticTexts["Welcome to New File Creation 2"].exists)
    }
}
