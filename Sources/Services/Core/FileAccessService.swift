import Foundation

final class FileAccessService: @unchecked Sendable {
    static let shared = FileAccessService()

    private let fileManager = FileManager.default

    private init() {}

    var homeDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
    }

    var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? homeDirectory
    }

    var applicationSupportDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    func fileExists(atPath path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }

    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func directoryExists(atPath path: String) -> Bool {
        var isDirectory = ObjCBool(false)
        return itemExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func directoryExists(at url: URL) -> Bool {
        directoryExists(atPath: url.path)
    }

    func itemExists(atPath path: String, isDirectory: inout ObjCBool) -> Bool {
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
    }

    func isReadableFile(atPath path: String) -> Bool {
        fileManager.isReadableFile(atPath: path)
    }

    func ensureDirectory(_ url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func ensureParentDirectory(for url: URL) throws {
        try ensureDirectory(url.deletingLastPathComponent())
    }

    func readData(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func writeData(_ data: Data, to url: URL, options: Data.WritingOptions = []) throws {
        try ensureParentDirectory(for: url)
        try data.write(to: url, options: options)
    }

    func readString(from url: URL, encoding: String.Encoding = .utf8) throws -> String {
        try String(contentsOf: url, encoding: encoding)
    }

    func readPropertyList(from url: URL) -> [String: Any]? {
        guard let data = try? readData(from: url) else { return nil }
        guard
            let propertyList = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any]
        else {
            return nil
        }
        return propertyList
    }

    func writeString(
        _ content: String,
        to url: URL,
        atomically: Bool = true,
        encoding: String.Encoding = .utf8
    ) throws {
        try ensureParentDirectory(for: url)
        try content.write(to: url, atomically: atomically, encoding: encoding)
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }

    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options: FileManager.DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: options
        )
    }

    func contentsOfDirectory(atPath path: String) throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: path)
    }

    func enumeratedURLs(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]? = nil,
        options: FileManager.DirectoryEnumerationOptions = []
    ) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: options
        )
        else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }
    }

    func removeItem(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    func removeItemIfExists(at url: URL) throws {
        guard fileExists(at: url) else { return }
        try removeItem(at: url)
    }

    func clearDirectoryContents(at url: URL) throws {
        for item in try contentsOfDirectory(at: url) {
            try removeItem(at: item)
        }
    }

    func moveItem(at sourceURL: URL, to targetURL: URL) throws {
        try ensureParentDirectory(for: targetURL)
        try fileManager.moveItem(at: sourceURL, to: targetURL)
    }

    func copyItem(at sourceURL: URL, to targetURL: URL) throws {
        try ensureParentDirectory(for: targetURL)
        try fileManager.copyItem(at: sourceURL, to: targetURL)
    }

    func resolveSymlinks(for url: URL) -> URL {
        url.resolvingSymlinksInPath()
    }

    func temporaryFileURL(prefix: String, pathExtension: String = "tmp") -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(prefix)_\(UUID().uuidString)")
            .appendingPathExtension(pathExtension)
    }
}
