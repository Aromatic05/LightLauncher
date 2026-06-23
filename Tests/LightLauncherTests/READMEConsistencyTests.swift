import Foundation
import XCTest
@testable import LightLauncher

final class READMEConsistencyTests: XCTestCase {
    func testReadmeUsesActualTerminalPrefix() throws {
        let readme = try loadREADME()

        XCTAssertTrue(readme.contains("### 🖥️ **终端执行** (`>`)"))
        XCTAssertTrue(readme.contains("- `>` + 命令 → 执行终端命令"))
        XCTAssertFalse(readme.contains("### 🖥️ **终端执行** (`/t`)"))
        XCTAssertFalse(readme.contains("- `/t` + 命令 → 执行终端命令"))
    }

    func testReadmeDoesNotClaimUnsupportedEncryptedStorage() throws {
        let readme = try loadREADME()

        XCTAssertFalse(readme.contains("数据加密"))
        XCTAssertTrue(readme.contains("- **本地存储**: 配置和历史记录默认保存在本地文件中"))
    }

    private func loadREADME() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let projectRoot = testsDirectory.deletingLastPathComponent().deletingLastPathComponent()
        let readmeURL = projectRoot.appendingPathComponent("README.md")

        return try String(contentsOf: readmeURL, encoding: .utf8)
    }
}
