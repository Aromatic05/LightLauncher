import Foundation
import SQLite3

final class DatabaseService: @unchecked Sendable {
    static let shared = DatabaseService()

    private let fileAccess = FileAccessService.shared

    private init() {}

    func readRows<T>(
        at databaseURL: URL,
        query: String,
        copyToTemporary: Bool = false,
        rowMapper: @Sendable @escaping (OpaquePointer?) -> T?
    ) async -> [T] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(
                    returning: self.readRowsSync(
                        at: databaseURL,
                        query: query,
                        copyToTemporary: copyToTemporary,
                        rowMapper: rowMapper
                    )
                )
            }
        }
    }

    private func readRowsSync<T>(
        at databaseURL: URL,
        query: String,
        copyToTemporary: Bool,
        rowMapper: @Sendable (OpaquePointer?) -> T?
    ) -> [T] {
        let workingURL: URL
        let cleanupURL: URL?

        if copyToTemporary {
            let tempURL = fileAccess.temporaryFileURL(prefix: databaseURL.deletingPathExtension().lastPathComponent, pathExtension: databaseURL.pathExtension)
            do {
                try fileAccess.copyItem(at: databaseURL, to: tempURL)
                workingURL = tempURL
                cleanupURL = tempURL
            } catch {
                Logger.shared.error("Failed to create temporary database copy: \(error)")
                return []
            }
        } else {
            workingURL = databaseURL
            cleanupURL = nil
        }

        defer {
            if let cleanupURL {
                try? fileAccess.removeItemIfExists(at: cleanupURL)
            }
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(workingURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(database)
            return []
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return []
        }
        defer { sqlite3_finalize(statement) }

        var rows: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let row = rowMapper(statement) {
                rows.append(row)
            }
        }
        return rows
    }

    func string(from statement: OpaquePointer?, at index: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: cString)
    }

    func int(from statement: OpaquePointer?, at index: Int32) -> Int {
        Int(sqlite3_column_int(statement, index))
    }

    func int64(from statement: OpaquePointer?, at index: Int32) -> Int64 {
        sqlite3_column_int64(statement, index)
    }

    func double(from statement: OpaquePointer?, at index: Int32) -> Double {
        sqlite3_column_double(statement, index)
    }
}
