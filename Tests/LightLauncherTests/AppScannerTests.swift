import XCTest
@testable import LightLauncher

@MainActor
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

    func testScanApplications_sortsByNameAndDeduplicatesAcrossDirectories() throws {
        let scanner = AppScanner()
        try createAppBundle(named: "Zeta.app", bundleName: "Zeta", in: testDirectory)
        try createAppBundle(named: "Alpha.app", bundleName: "Alpha", in: testDirectory)

        let applications = scanner.scanApplications(
            in: [testDirectory.path, testDirectory.path]
        )

        XCTAssertEqual(applications.map(\.name), ["Alpha", "Zeta"])
        XCTAssertEqual(Set(applications.map(\.url.path)).count, 2)
    }

    func testScanApplications_fallsBackToBundleDisplayNameAndFilename() throws {
        let scanner = AppScanner()
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

        let applications = scanner.scanApplications(in: [testDirectory.path])

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
