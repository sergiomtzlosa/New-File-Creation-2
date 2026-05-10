import AppKit
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
        launch(opening: "NFC_UI_TEST_OPEN_QUICK_PANEL", mainScreen: true)
    }

    private func launch(opening environmentVariable: String, mainScreen: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NFC_SUPPORT_DIR"] = support.path
        app.launchEnvironment[environmentVariable] = "1"
        if mainScreen {
            app.launchEnvironment["NFC_UI_TEST_MAIN_SCREEN"] = "1"
        }
        app.launch()
        return app
    }

    private func useReadmeConfiguration() throws {
        let configURL = support.appendingPathComponent("config.json")
        let data = try Data(contentsOf: configURL)
        guard var config = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var settings = config["settings"] as? [String: Any] else {
            return
        }
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) }
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        settings["defaultDirectory"] = URL(fileURLWithPath: home, isDirectory: true)
            .appendingPathComponent("Desktop", isDirectory: true).path
        config["settings"] = settings
        let updated = try JSONSerialization.data(withJSONObject: config,
                                                 options: [.prettyPrinted, .sortedKeys])
        try updated.write(to: configURL)
    }

    private func requireQuickPanel(in app: XCUIApplication) -> XCUIElement {
        let quickPanel = app.dialogs["Quick New File"]
        XCTAssertTrue(quickPanel.waitForExistence(timeout: 10), "Quick panel should open")
        return quickPanel
    }

    private func requireFloatingWindow(in app: XCUIApplication, title: String) -> XCUIElement {
        let dialog = app.dialogs[title]
        if dialog.waitForExistence(timeout: 5) {
            return dialog
        }
        let window = app.windows[title]
        XCTAssertTrue(window.waitForExistence(timeout: 5), "\(title) should open")
        return window
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

    private func saveElementScreenshot(_ element: XCUIElement, _ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        guard let screen = NSScreen.main,
              let image = screenshot.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("ELEMENT SCREENSHOT FAILED: no screenshot image")
            return
        }
        let scale = CGFloat(image.width) / screen.frame.width
        let frame = element.frame
        var crop = CGRect(x: frame.minX * scale,
                          y: frame.minY * scale,
                          width: frame.width * scale,
                          height: frame.height * scale)
        crop = crop.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard !crop.isNull, !crop.isEmpty, let cropped = image.cropping(to: crop) else {
            print("ELEMENT SCREENSHOT FAILED: crop outside the main screen: \(frame)")
            return
        }
        let representation = NSBitmapImageRep(cgImage: cropped)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            print("ELEMENT SCREENSHOT FAILED: PNG encoding")
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).png")
        do {
            try data.write(to: url)
            print("ELEMENT SCREENSHOT: \(url.path) frame=\(frame)")
        } catch {
            print("ELEMENT SCREENSHOT FAILED: \(error)")
        }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureReadmeScreenshots() throws {
        try useReadmeConfiguration()

        // Pin every window to the primary display so the captures always come
        // from XCUIScreen.main, regardless of where the pointer is.
        let quickApp = launch(opening: "NFC_UI_TEST_OPEN_QUICK_PANEL", mainScreen: true)
        let quickPanel = requireQuickPanel(in: quickApp)
        quickApp.activate()
        let quickTitle = quickPanel.staticTexts.matching(identifier: "QuickPanelTitle").firstMatch
        XCTAssertTrue(quickTitle.exists, "Quick panel title should be accessible")
        quickTitle.click()
        Thread.sleep(forTimeInterval: 0.8)
        saveElementScreenshot(quickPanel, "nfc-readme-quick-panel")
        quickApp.terminate()

        let libraryApp = launch(opening: "NFC_UI_TEST_OPEN_LIBRARY", mainScreen: true)
        let library = requireFloatingWindow(in: libraryApp, title: "New File Creation 2")
        libraryApp.activate()
        let template = library.staticTexts["ePub"].firstMatch
        if template.waitForExistence(timeout: 3) {
            template.click()
        }
        Thread.sleep(forTimeInterval: 0.8)
        saveElementScreenshot(library, "nfc-readme-library")
        libraryApp.terminate()

        let settingsApp = launch(opening: "NFC_UI_TEST_OPEN_SETTINGS", mainScreen: true)
        let settings = requireFloatingWindow(in: settingsApp, title: "Settings")
        settingsApp.activate()
        Thread.sleep(forTimeInterval: 0.8)
        saveElementScreenshot(settings, "nfc-readme-settings")
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
