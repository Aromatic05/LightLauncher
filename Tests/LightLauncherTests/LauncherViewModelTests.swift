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
