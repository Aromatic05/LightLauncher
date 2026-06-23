import Combine
import SwiftUI
import XCTest
@testable import LightLauncher

@MainActor
final class LauncherViewModelTests: XCTestCase {
    private let viewModel = LauncherViewModel.shared
    private let windowRouterSpy = WindowRouterSpy()

    override func setUp() async throws {
        try await super.setUp()
        resetViewModelState()
        viewModel.windowRouter = windowRouterSpy
    }

    override func tearDown() async throws {
        resetViewModelState()
        viewModel.windowRouter = NotificationCenterWindowRouter()
        try await super.tearDown()
    }

    func testSearchText_switchesNonFileCommandsImmediately() {
        viewModel.searchText = "/k finder"

        XCTAssertEqual(viewModel.mode, .kill)
    }

    func testSearchText_keepsFileModeDebounceBeforeProcessingOtherCommands() async {
        viewModel.mode = .file
        viewModel.searchText = "/k finder"

        XCTAssertEqual(viewModel.mode, .file)

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.mode, .kill)
    }

    func testUpdateQuery_preservesLongSearchText() {
        let longText = String(repeating: "very-long-query-", count: 10)

        viewModel.updateQuery(newQuery: longText)

        XCTAssertEqual(viewModel.searchText, longText)
    }

    func testEnterKey_appliesSelectedCommandSuggestion() async {
        let command = CommandRecord(
            prefix: "/s",
            mode: .search,
            displayName: "Web Search",
            iconName: "globe",
            description: "Search the web with your default engine",
            controller: SearchModeController.shared
        )

        viewModel.commandSuggestions = [command]
        viewModel.showCommandSuggestions = true
        viewModel.selectedIndex = 0

        KeyboardEventHandler.shared.keyEventPublisher.send(.enter)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.searchText, "/s ")
        XCTAssertFalse(viewModel.showCommandSuggestions)
        XCTAssertTrue(viewModel.commandSuggestions.isEmpty)
        XCTAssertTrue(windowRouterSpy.hideRequests.isEmpty)
    }

    func testEscapeKey_requestsWindowHideThroughRouter() async {
        KeyboardEventHandler.shared.keyEventPublisher.send(.escape)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(windowRouterSpy.hideRequests, [true])
    }

    func testCanInitializeIndependentInstanceWithInjectedDependencies() async {
        let registry = FakeCommandRegistry()
        let keyboardHandler = FakeKeyboardEventHandler()
        let settingsProvider = FakeSettingsProvider(showCommandSuggestionsEnabled: false)
        let routerSpy = WindowRouterSpy()
        let launchController = TestModeController(mode: .launch, prefix: nil)
        let killController = TestModeController(
            mode: .kill,
            prefix: "/k",
            interceptedKeys: [.numeric(1)]
        )

        let commandRecord = CommandRecord(
            prefix: "/k",
            mode: .kill,
            displayName: "Kill Process",
            iconName: "xmark.circle",
            description: "Kill a running process",
            controller: killController
        )
        registry.commandLookup["/k finder"] = (commandRecord, "finder")

        let independentViewModel = LauncherViewModel(
            controllers: [launchController, killController],
            commandRegistry: registry,
            keyboardEventHandler: keyboardHandler,
            settingsProvider: settingsProvider,
            windowRouter: routerSpy
        )

        XCTAssertEqual(registry.registeredControllers, [.launch, .kill])

        independentViewModel.searchText = "/k finder"
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(independentViewModel.mode, .kill)
        XCTAssertEqual(killController.lastInput, "finder")
        XCTAssertEqual(keyboardHandler.interceptionRulesHistory.last, [.numeric(1)])

        keyboardHandler.subject.send(.escape)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(routerSpy.hideRequests, [true])
    }

    private func resetViewModelState() {
        viewModel.searchText = ""
        viewModel.showCommandSuggestions = false
        viewModel.commandSuggestions = []
        viewModel.selectedIndex = 0
        viewModel.mode = .launch
        windowRouterSpy.hideRequests = []
    }
}

@MainActor
private final class WindowRouterSpy: LauncherWindowRouting {
    var hideRequests: [Bool] = []

    func hideMainWindow(shouldActivatePreviousApp: Bool) {
        hideRequests.append(shouldActivatePreviousApp)
    }
}

@MainActor
private final class FakeCommandRegistry: CommandRegistryManaging {
    var registeredControllers: [LauncherMode] = []
    var commandLookup: [String: (record: CommandRecord, arguments: String)] = [:]
    var suggestions: [CommandRecord] = []

    func register(_ controller: any ModeStateController) {
        registeredControllers.append(controller.mode)
    }

    func findCommand(for text: String) -> (record: CommandRecord, arguments: String)? {
        commandLookup[text]
    }

    func getCommandSuggestions() -> [CommandRecord] {
        suggestions
    }
}

@MainActor
private final class FakeKeyboardEventHandler: KeyboardEventManaging {
    let subject = PassthroughSubject<KeyEvent, Never>()
    var interceptionRulesHistory: [Set<KeyEvent>] = []

    var keyEvents: AnyPublisher<KeyEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    func updateInterceptionRules(for modeKeys: Set<KeyEvent>) {
        interceptionRulesHistory.append(modeKeys)
    }
}

@MainActor
private final class FakeSettingsProvider: CommandSuggestionSettingsProviding {
    let showCommandSuggestionsEnabled: Bool

    init(showCommandSuggestionsEnabled: Bool) {
        self.showCommandSuggestionsEnabled = showCommandSuggestionsEnabled
    }
}

@MainActor
private final class TestModeController: ModeStateController {
    static let shared = TestModeController(mode: .launch, prefix: nil)

    let mode: LauncherMode
    let prefix: String?
    let displayName: String
    let iconName: String
    let placeholder: String
    let modeDescription: String?
    let interceptedKeys: Set<KeyEvent>
    let dataDidChange = PassthroughSubject<Void, Never>()
    var displayableItems: [any DisplayableItem] = []
    private(set) var lastInput: String?

    init(
        mode: LauncherMode,
        prefix: String?,
        displayName: String = "Test Mode",
        iconName: String = "circle",
        placeholder: String = "Test placeholder",
        modeDescription: String? = "Test description",
        interceptedKeys: Set<KeyEvent> = []
    ) {
        self.mode = mode
        self.prefix = prefix
        self.displayName = displayName
        self.iconName = iconName
        self.placeholder = placeholder
        self.modeDescription = modeDescription
        self.interceptedKeys = interceptedKeys
    }

    func handleInput(arguments: String) {
        lastInput = arguments
    }

    func cleanup() {
        lastInput = nil
    }

    func makeContentView() -> AnyView {
        AnyView(EmptyView())
    }

    func getHelpText() -> [String] {
        []
    }
}
