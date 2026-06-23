import XCTest
@testable import LightLauncher

final class AppScannerTests: XCTestCase {
    private var testDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("app_scanner_tests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: testDirectory)
        try super.tearDownWithError()
    }

    func testScanApplications_sortsByNameAndDeduplicatesAcrossDirectories() async throws {
        try createAppBundle(named: "Zeta.app", bundleName: "Zeta", in: testDirectory)
        try createAppBundle(named: "Alpha.app", bundleName: "Alpha", in: testDirectory)
        let directoryPath = testDirectory.path

        let applications = await MainActor.run {
            let scanner = AppScanner()
            return scanner.scanApplications(in: [directoryPath, directoryPath])
        }

        XCTAssertEqual(applications.map(\.name), ["Alpha", "Zeta"])
        XCTAssertEqual(Set(applications.map(\.url.path)).count, 2)
    }

    func testScanApplications_fallsBackToBundleDisplayNameAndFilename() async throws {
        let displayNameDirectory = testDirectory.appendingPathComponent("Nested")
        try FileManager.default.createDirectory(at: displayNameDirectory, withIntermediateDirectories: true)

        try createAppBundle(
            named: "DisplayOnly.app",
            bundleName: nil,
            bundleDisplayName: "Display App",
            in: displayNameDirectory
        )
        try createAppBundle(
            named: "FilenameFallback.app",
            bundleName: nil,
            bundleDisplayName: nil,
            in: displayNameDirectory
        )
        let directoryPath = testDirectory.path

        let applications = await MainActor.run {
            let scanner = AppScanner()
            return scanner.scanApplications(in: [directoryPath])
        }

        XCTAssertEqual(applications.map(\.name), ["Display App", "FilenameFallback"])
    }

    private func createAppBundle(
        named appName: String,
        bundleName: String?,
        bundleDisplayName: String? = nil,
        in directory: URL
    ) throws {
        let appURL = directory.appendingPathComponent(appName)
        let contentsURL = appURL.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)

        var plist: [String: Any] = [:]
        if let bundleName {
            plist["CFBundleName"] = bundleName
        }
        if let bundleDisplayName {
            plist["CFBundleDisplayName"] = bundleDisplayName
        }

        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL)
    }
}
