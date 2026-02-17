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
                "keepQuickPanelOpenAfterDrop": false
            ],
            "templates": []
        ]
        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: support.appendingPathComponent("config.json"))
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
        let quickPanel = app.dialogs["Quick New File"]
        XCTAssertTrue(quickPanel.waitForExistence(timeout: 10), "Quick panel should open")
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
        print("SETTINGS HIERARCHY:\n\(settings.debugDescription)")

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
}
