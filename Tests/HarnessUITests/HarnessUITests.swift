import HarnessDomain
import HarnessInfrastructure
import XCTest

@MainActor
final class HarnessUITests: XCTestCase {
    private var app = XCUIApplication()
    private var fixtureRun: Run?
    private var fixtureChatID = ""
    private var fixtureProjectName = ""

    private func launchFixture() throws {
        continueAfterFailure = false
        let manifestPath = try XCTUnwrap(ProcessInfo.processInfo.environment["HARNESS_UI_FIXTURE_MANIFEST"])
        let manifest = try Coding.decode(JSONValue.self, from: Data(contentsOf: URL(fileURLWithPath: manifestPath)))
        XCTAssertTrue(manifest["error"].string.isEmpty, manifest["error"].string)
        let method = name.components(separatedBy: " ").last?.replacingOccurrences(of: "]", with: "") ?? ""
        let fixture = manifest["cases"][method]
        XCTAssertFalse(fixture["runtime"].string.isEmpty, "Missing isolated fixture for " + method)
        fixtureChatID = fixture["conversationID"].string
        fixtureProjectName = fixture["project"]["name"].string
        if fixture["run"] != .null {
            fixtureRun = try Coding.decode(Run.self, from: Coding.encode(fixture["run"]))
        }
        app.launchArguments = ["--harness-data-root", fixture["runtime"].string, "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        XCTAssertTrue(element("chat.new").waitForExistence(timeout: 15))
    }

    func testComposerRequiresObjectiveAndCreatesPreparedRun() throws {
        try launchFixture()
        defer { app.terminate() }
        app.typeKey("n", modifierFlags: .command)
        let field = element("chat.prompt")
        let send = element("chat.send")
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        XCTAssertFalse(send.isEnabled)
        let prompt = "UI acceptance objective"
        field.click()
        enterText(prompt, into: field)
        XCTAssertEqual(field.value as? String, prompt)
        waitForEnabled(send)
        element("chat.mode").click()
        let project = app.menuItems[fixtureProjectName]
        XCTAssertTrue(project.waitForExistence(timeout: 5))
        project.click()
        element("chat.autonomy").click()
        let guided = app.menuItems["Revisar antes"]
        XCTAssertTrue(guided.waitForExistence(timeout: 5))
        guided.click()
        send.click()
        XCTAssertTrue(message(prompt).waitForExistence(timeout: 15))
        XCTAssertTrue(element("chat.execution.graph").waitForExistence(timeout: 15))
        waitForEmptyPrompt(field)
        let review = element("Revisar contexto")
        XCTAssertTrue(review.waitForExistence(timeout: 20))
        review.click()
        XCTAssertTrue(element("Autorizar contexto").waitForExistence(timeout: 5))
    }

    func testGateStatesAndStaleEvidenceAreVisible() throws {
        try launchFixture()
        defer { app.terminate() }
        let run = try XCTUnwrap(fixtureRun)
        openFixtureChat()
        element("chat.execution.steps").click()
        let step = try XCTUnwrap(run.plan.first { $0.kind == "validation" })
        let stepButton = element("task.step." + step.id)
        XCTAssertTrue(stepButton.waitForExistence(timeout: 10))
        stepButton.click()
        let stage = element("journey.open-stage")
        XCTAssertTrue(stage.waitForExistence(timeout: 5))
        stage.click()
        let pass = element("validation.status.qa-pass")
        waitForLabel(pass, containing: "NOT_RUN")
        for id in ["qa-pass", "qa-fail", "qa-blocked"] {
            let button = element("validation.execute." + id)
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.click()
            waitForLabel(
                element("validation.status." + id),
                containing: id == "qa-pass" ? "PASS" : id == "qa-fail" ? "FAIL" : "BLOCKED")
        }
        waitForLabel(pass, containing: "PASS")
        waitForLabel(element("validation.status.qa-fail"), containing: "FAIL")
        waitForLabel(element("validation.status.qa-blocked"), containing: "BLOCKED")
        let edit = element("validation.execute.qa-edit")
        if !edit.isHittable {
            app.scrollViews.containing(.any, identifier: "validation.execute.qa-edit").firstMatch.swipeUp()
        }
        edit.click()
        waitForLabel(pass, containing: "STALE")
    }

    func testProjectsAndRunsSurviveApplicationRestart() throws {
        try launchFixture()
        defer { app.terminate() }
        let run = try XCTUnwrap(fixtureRun)
        openFixtureChat()
        let followup = "Explain the previous step"
        let field = element("chat.prompt")
        field.click()
        enterText(followup, into: field)
        let send = element("chat.send")
        waitForEnabled(send)
        send.click()
        XCTAssertTrue(message(followup).waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        openFixtureChat()
        XCTAssertTrue(message(run.title).waitForExistence(timeout: 10))
        XCTAssertTrue(message(followup).exists)
        XCTAssertTrue(element("chat.execution.graph").exists)
    }

    func testAppearanceSettingPersists() throws {
        try launchFixture()
        defer { app.terminate() }
        app.typeKey(",", modifierFlags: .command)
        let appearance = element("settings.appearance")
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        for theme in ["Escuro", "Claro", "Sistema"] {
            appearance.click()
            app.menuItems[theme].click()
            waitForLabel(appearance, containing: theme)
            if theme == "Escuro" {
                app.terminate()
                app.launch()
                XCTAssertTrue(element("chat.new").waitForExistence(timeout: 15))
                app.typeKey(",", modifierFlags: .command)
                waitForLabel(appearance, containing: "Escuro")
            }
            let settingsWindow = app.windows.containing(.any, identifier: "settings.appearance").firstMatch
            let attachment = XCTAttachment(screenshot: settingsWindow.screenshot())
            attachment.name = "Appearance-" + theme
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func enterText(_ text: String, into element: XCUIElement) {
        for character in text {
            let key = String(character)
            element.typeKey(
                XCUIKeyboardKey(rawValue: key.lowercased()), modifierFlags: key == key.lowercased() ? [] : .shift)
        }
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func openFixtureChat() {
        let title = element("chat.history." + fixtureChatID)
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        title.click()
        XCTAssertTrue(element("chat.execution.steps").waitForExistence(timeout: 10))
    }

    private func message(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)", "chat.user-message", text, text
            )
        ).firstMatch
    }

    private func waitForEnabled(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 15), .completed)
    }

    private func waitForEmptyPrompt(_ field: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in field.exists && (field.value as? String ?? "").isEmpty }, object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND (label CONTAINS %@ OR value CONTAINS %@)", text, text),
            object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 20), .completed, "Expected \(text), observed \(element.label)")
    }
}
