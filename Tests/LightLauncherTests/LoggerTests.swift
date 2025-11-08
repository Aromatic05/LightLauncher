import XCTest
@testable import LightLauncher

final class LoggerTests: XCTestCase {
    override func setUpWithError() throws {
        // ensure fresh start for file logs
    }

    override func tearDownWithError() throws {
        // cleanup
    }

    func testFileLoggingWritesMessage() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("LightLauncherTestLogs", isDirectory: true)
        try? FileManager.default.removeItem(at: tmpDir)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let fileURL = tmpDir.appendingPathComponent("test.log")

        // configure logger to only write to file for test
        Logger.shared.configure(logToOSLog: false, printToTerminal: false, logToFile: true, consoleLevel: .debug, fileLevel: .debug, customFileURL: fileURL)

        let testMessage = "hello-logger-test-\(UUID().uuidString)"
        Logger.shared.info(testMessage, owner: self)

        let expect = expectation(description: "wait for log file to contain message")
        let deadline = Date().addingTimeInterval(3)

        DispatchQueue.global().async {
            while Date() < deadline {
                if let data = try? Data(contentsOf: fileURL), let s = String(data: data, encoding: .utf8), s.contains(testMessage) {
                    expect.fulfill()
                    return
                }
                usleep(100_000) // 0.1s
            }
        }

        wait(for: [expect], timeout: 4.0)

        // cleanup
        try? FileManager.default.removeItem(at: tmpDir)
    }
}
