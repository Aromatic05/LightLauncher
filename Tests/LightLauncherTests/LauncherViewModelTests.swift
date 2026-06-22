import XCTest
@testable import LightLauncher

@MainActor
final class LauncherViewModelTests: XCTestCase {
    private let viewModel = LauncherViewModel.shared

    override func setUp() async throws {
        try await super.setUp()
        resetViewModelState()
    }

    override func tearDown() async throws {
        resetViewModelState()
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

    private func resetViewModelState() {
        viewModel.searchText = ""
        viewModel.showCommandSuggestions = false
        viewModel.commandSuggestions = []
        viewModel.selectedIndex = 0
        viewModel.mode = .launch
    }
}
