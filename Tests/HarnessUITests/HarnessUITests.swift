import HarnessDomain
import HarnessInfrastructure
import XCTest

@MainActor
final class HarnessUITests: XCTestCase {
    private var app = XCUIApplication()
    private var fixtureRun: Run?

    private func launchFixture() throws {
        continueAfterFailure = false
        let manifestPath = try XCTUnwrap(ProcessInfo.processInfo.environment["HARNESS_UI_FIXTURE_MANIFEST"])
        let manifest = try Coding.decode(JSONValue.self, from: Data(contentsOf: URL(fileURLWithPath: manifestPath)))
        XCTAssertTrue(manifest["error"].string.isEmpty, manifest["error"].string)
        let method = name.components(separatedBy: " ").last?.replacingOccurrences(of: "]", with: "") ?? ""
        let fixture = manifest["cases"][method]
        XCTAssertFalse(fixture["runtime"].string.isEmpty, "Missing isolated fixture for " + method)
        if fixture["run"] != .null {
            fixtureRun = try Coding.decode(Run.self, from: Coding.encode(fixture["run"]))
        }
        app.launchArguments = ["--harness-data-root", fixture["runtime"].string, "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts["coordinator.status"].waitForExistence(timeout: 15))
        waitForLabel(app.staticTexts["coordinator.status"], containing: "conectado")
    }

    func testComposerRequiresObjectiveAndCreatesPreparedRun() throws {
        try launchFixture()
        defer { app.terminate() }
        app.typeKey("n", modifierFlags: .command)
        let create = app.buttons["composer.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        XCTAssertFalse(create.isEnabled)
        let title = app.descendants(matching: .any)["composer.objective"].firstMatch
        title.click()
        enterText("UI acceptance objective", into: title)
        XCTAssertEqual(title.value as? String, "UI acceptance objective")
        XCTAssertTrue(create.isEnabled)
        create.click()
        let state = app.descendants(matching: .any)["run.state"].firstMatch
        waitForLabel(state, containing: "WAITING_USER")
        XCTAssertTrue(app.buttons["run.approve"].exists)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "Composer result accessibility"
        tree.lifetime = .keepAlways
        add(tree)
        waitForLabel(app.descendants(matching: .any)["run.title"].firstMatch, containing: "UI acceptance objective")
        app.buttons["run.tab.Contexto"].click()
        XCTAssertTrue(app.buttons["run.approve"].exists)
    }

    func testGateStatesAndStaleEvidenceAreVisible() throws {
        try launchFixture()
        defer { app.terminate() }
        let run = try XCTUnwrap(fixtureRun)
        try openRun(run.title)
        app.buttons["run.tab.Validação"].click()
        let pass = app.descendants(matching: .any)["validation.status.qa-pass"].firstMatch
        waitForLabel(pass, containing: "NOT_RUN")
        for id in ["qa-pass", "qa-fail", "qa-blocked"] {
            let button = app.buttons["validation.execute." + id]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.click()
            waitForLabel(
                app.descendants(matching: .any)["validation.status." + id].firstMatch,
                containing: id == "qa-pass" ? "PASS" : id == "qa-fail" ? "FAIL" : "BLOCKED")
        }
        waitForLabel(pass, containing: "PASS")
        waitForLabel(app.descendants(matching: .any)["validation.status.qa-fail"].firstMatch, containing: "FAIL")
        waitForLabel(app.descendants(matching: .any)["validation.status.qa-blocked"].firstMatch, containing: "BLOCKED")
        let edit = app.buttons["validation.execute.qa-edit"]
        if !edit.isHittable {
            app.scrollViews.containing(.button, identifier: "validation.execute.qa-edit").firstMatch.swipeUp()
        }
        edit.click()
        waitForLabel(pass, containing: "STALE")
        XCTAssertFalse(app.descendants(matching: .any)["run.state"].firstMatch.label.contains("READY"))
    }

    func testPaletteNavigatesAndEscapeDismissesIt() throws {
        try launchFixture()
        defer { app.terminate() }
        let run = try XCTUnwrap(fixtureRun)
        try openRun(run.title)
        XCTAssertTrue(app.buttons["run.tab.Contexto"].exists)
        app.typeKey("k", modifierFlags: .command)
        let search = app.textFields["palette.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(search.waitForNonExistence(timeout: 5))
    }

    func testProjectsAndRunsSurviveApplicationRestart() throws {
        try launchFixture()
        defer { app.terminate() }
        let run = try XCTUnwrap(fixtureRun)
        app.terminate()
        app.launch()
        waitForLabel(app.staticTexts["coordinator.status"], containing: "conectado")
        try openRun(run.title)
        waitForLabel(app.descendants(matching: .any)["run.state"].firstMatch, containing: "WAITING_USER")
        waitForLabel(app.descendants(matching: .any)["run.title"].firstMatch, containing: "Persistent QA run")
    }

    func testSecondRunWindowCanCloseWithoutClosingMainWindow() throws {
        try launchFixture()
        defer { app.terminate() }
        let run = try XCTUnwrap(fixtureRun)
        try openRun(run.title)
        let count = app.windows.count
        app.buttons["run.open-window"].click()
        let expanded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > %d", count), object: app.windows)
        XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 10), .completed)
        app.typeKey("w", modifierFlags: .command)
        XCTAssertGreaterThanOrEqual(app.windows.count, 1)
        XCTAssertTrue(app.buttons["toolbar.new-run"].exists)
    }

    func testAppearanceSettingPersists() throws {
        try launchFixture()
        defer { app.terminate() }
        app.typeKey(",", modifierFlags: .command)
        let appearance = app.popUpButtons["settings.appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        for theme in ["Escuro", "Claro", "Sistema"] {
            appearance.click()
            app.menuItems[theme].click()
            XCTAssertEqual(appearance.value as? String, theme)
            if theme == "Escuro" {
                app.terminate()
                app.launch()
                waitForLabel(app.staticTexts["coordinator.status"], containing: "conectado")
                app.typeKey(",", modifierFlags: .command)
                XCTAssertTrue(appearance.waitForExistence(timeout: 5))
                XCTAssertEqual(appearance.value as? String, "Escuro")
            }
            let settingsWindow = app.windows.containing(.popUpButton, identifier: "settings.appearance").firstMatch
            let attachment = XCTAttachment(screenshot: settingsWindow.screenshot())
            attachment.name = "Appearance-" + theme
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func enterText(_ text: String, into element: XCUIElement) {
        // Use explicit key modifiers to keep native text entry deterministic.
        for character in text {
            let key = String(character)
            element.typeKey(
                XCUIKeyboardKey(rawValue: key.lowercased()), modifierFlags: key == key.lowercased() ? [] : .shift)
        }
    }

    private func openRun(_ title: String) throws {
        app.typeKey("k", modifierFlags: .command)
        let search = app.textFields["palette.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.click()
        enterText(title, into: search)
        XCTAssertEqual(search.value as? String, title)
        let row = app.buttons[title]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.click()
        XCTAssertTrue(app.buttons["run.tab.Validação"].waitForExistence(timeout: 5))
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND (label CONTAINS %@ OR value CONTAINS %@)", text, text),
            object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 20), .completed, "Expected \(text), observed \(element.label)")
    }

}
