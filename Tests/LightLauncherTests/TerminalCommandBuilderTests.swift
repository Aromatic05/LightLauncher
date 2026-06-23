import XCTest
@testable import LightLauncher

final class TerminalCommandBuilderTests: XCTestCase {
    func testInteractiveShellArguments_reopenLoginShellAfterCommand() {
        let arguments = ShellCommandBuilder.interactiveShellArguments(
            for: "echo hello",
            shellPath: "/bin/zsh"
        )

        XCTAssertEqual(arguments[0], "/bin/zsh")
        XCTAssertEqual(arguments[1], "-lc")
        XCTAssertEqual(arguments[2], "echo hello; exec '/bin/zsh' -l")
    }

    func testInteractiveShellArguments_escapeSingleQuotesInShellPath() {
        let arguments = ShellCommandBuilder.interactiveShellArguments(
            for: "pwd",
            shellPath: "/tmp/dev shell's/bin/zsh"
        )

        XCTAssertEqual(
            arguments[2],
            "pwd; exec '/tmp/dev shell'\\''s/bin/zsh' -l"
        )
    }

    func testGhosttyArguments_passExecutableAndArgumentsSeparately() {
        let arguments = ModernTerminalExecutor.GhosttyExecutor.arguments("ls -la")

        XCTAssertEqual(
            Array(arguments.prefix(3)),
            ["-e", ShellCommandBuilder.defaultShellPath(), "-lc"]
        )
        XCTAssertFalse(arguments[1].contains(" "))
        XCTAssertTrue(arguments[3].contains("ls -la; exec "))
    }

    func testKittyArguments_useHoldWithoutDeprecatedDashE() {
        let arguments = ModernTerminalExecutor.KittyExecutor.arguments("git status")

        XCTAssertEqual(arguments.first, "--hold")
        XCTAssertFalse(arguments.contains("-e"))
        XCTAssertEqual(arguments[1], ShellCommandBuilder.defaultShellPath())
        XCTAssertEqual(arguments[2], "-lc")
    }

    func testAlacrittyArguments_placeCommandAfterDashE() {
        let arguments = ModernTerminalExecutor.AlacrittyExecutor.arguments("swift test")

        XCTAssertEqual(Array(arguments.prefix(4)), ["--hold", "-e", ShellCommandBuilder.defaultShellPath(), "-lc"])
        XCTAssertTrue(arguments[4].contains("swift test; exec "))
    }

    func testWezTermArguments_useStartSubcommandAndProgramSeparator() {
        let arguments = ModernTerminalExecutor.WezTermExecutor.arguments("top")

        XCTAssertEqual(Array(arguments.prefix(4)), ["start", "--", ShellCommandBuilder.defaultShellPath(), "-lc"])
        XCTAssertTrue(arguments[4].contains("top; exec "))
    }
}
