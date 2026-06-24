import Foundation
import XCTest

final class PrefixBucketBenchmarkTests: XCTestCase {

    struct TestItem {
        let id: Int
        let url: String
        let title: String
        let visitCount: Int
    }

    private let prefixKeyLength = 3
    private let shortQueryThreshold = 2
    private let topKResults = 100

    private struct LegacyIndex {
        let items: [TestItem]
        let buckets: [String: [Int]]
    }

    private struct ImprovedIndex {
        let items: [TestItem]
        let buckets: [String: [Int]]
    }

    private func searchableUrl(for url: String) -> String {
        guard let components = URLComponents(string: url) else {
            return url.lowercased()
        }

        let host = components.host ?? ""
        let path = components.path
        return (host + path).lowercased()
    }

    private func score(_ item: TestItem, query: String) -> Double? {
        let searchable = searchableUrl(for: item.url)
        let title = item.title.lowercased()
        var queryScore = 0.0

        if searchable.hasPrefix(query) {
            queryScore += 18.0
        }
        if title.hasPrefix(query) {
            queryScore += 6.0
        }

        guard queryScore > 0 else { return nil }
        return log(Double(item.visitCount + 1)) + queryScore + 5.0
    }

    private func legacyBuckets(for items: [TestItem]) -> [String: [Int]] {
        var buckets: [String: [Int]] = [:]
        for (index, item) in items.enumerated() {
            let key = String(searchableUrl(for: item.url).prefix(prefixKeyLength))
            buckets[key, default: []].append(index)
        }
        return buckets
    }

    private func improvedBuckets(for items: [TestItem]) -> [String: [Int]] {
        var buckets: [String: [Int]] = [:]

        for (index, item) in items.enumerated() {
            var keys = Set<String>()

            for text in [searchableUrl(for: item.url), item.title.lowercased()] {
                guard !text.isEmpty else { continue }
                let maxLength = min(prefixKeyLength, text.count)
                for length in 1...maxLength {
                    keys.insert(String(text.prefix(length)))
                }
            }

            for key in keys {
                buckets[key, default: []].append(index)
            }
        }

        return buckets
    }

    private func makeLegacyIndex(items: [TestItem]) -> LegacyIndex {
        LegacyIndex(items: items, buckets: legacyBuckets(for: items))
    }

    private func makeImprovedIndex(items: [TestItem]) -> ImprovedIndex {
        ImprovedIndex(items: items, buckets: improvedBuckets(for: items))
    }

    private func searchLegacy(_ index: LegacyIndex, query: String) -> [TestItem] {
        let q = query.lowercased()
        guard !q.isEmpty else { return [] }

        if q.count <= shortQueryThreshold {
            let key = String(q.prefix(prefixKeyLength))
            guard let indices = index.buckets[key], !indices.isEmpty else {
                return linearShortPrefixSearch(index.items, query: q)
            }

            return indices
                .compactMap { itemIndex -> (TestItem, Double)? in
                    guard let score = score(index.items[itemIndex], query: q) else { return nil }
                    return (index.items[itemIndex], score)
                }
                .sorted { $0.1 > $1.1 }
                .prefix(topKResults)
                .map(\.0)
        }

        return []
    }

    private func searchImproved(_ index: ImprovedIndex, query: String) -> [TestItem] {
        let q = query.lowercased()
        guard !q.isEmpty else { return [] }

        if q.count <= shortQueryThreshold {
            guard let indices = index.buckets[q], !indices.isEmpty else { return [] }

            return indices
                .compactMap { itemIndex -> (TestItem, Double)? in
                    guard let score = score(index.items[itemIndex], query: q) else { return nil }
                    return (index.items[itemIndex], score)
                }
                .sorted { $0.1 > $1.1 }
                .prefix(topKResults)
                .map(\.0)
        }

        return []
    }

    private func linearShortPrefixSearch(_ items: [TestItem], query: String) -> [TestItem] {
        items
            .compactMap { item -> (TestItem, Double)? in
                guard let score = score(item, query: query) else { return nil }
                return (item, score)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    private func makeItems(count: Int) -> [TestItem] {
        let hosts = (1...200).map { "host\($0).example.com" }
        let titlePrefixes = [
            "alpha docs", "beta wiki", "gamma notes", "delta board", "go links", "git repo",
        ]

        var items: [TestItem] = []
        items.reserveCapacity(count)

        for i in 0..<count {
            let host = hosts[i % hosts.count]
            let path = "/path/segment/\(i)"
            let url = "https://\(host)\(path)"
            let titlePrefix = titlePrefixes[i % titlePrefixes.count]
            let title = "\(titlePrefix) \(i)"
            let visitCount = (i * 13) % 500
            items.append(TestItem(id: i, url: url, title: title, visitCount: visitCount))
        }

        return items
    }

    private func measureMillis(_ block: () -> Void) -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        block()
        return (CFAbsoluteTimeGetCurrent() - start) * 1000.0
    }

    func testLegacyIndexFallsBackForTwoCharacterHostPrefix() {
        let items = [
            TestItem(id: 1, url: "https://google.com/search", title: "Search", visitCount: 20)
        ]

        let legacy = legacyBuckets(for: items)
        let improved = improvedBuckets(for: items)

        XCTAssertNil(legacy["go"], "Legacy 3-char URL-only buckets should miss a 2-char query key")
        XCTAssertEqual(improved["go"]?.count, 1)
    }

    func testImprovedIndexCapturesTitlePrefixesWithoutLinearFallback() {
        let items = [
            TestItem(id: 1, url: "https://example.com/page", title: "Go Links", visitCount: 10)
        ]

        let legacy = legacyBuckets(for: items)
        let improved = improvedBuckets(for: items)
        let improvedIndex = makeImprovedIndex(items: items)

        XCTAssertNil(legacy["go"], "Legacy buckets do not index title prefixes")
        XCTAssertEqual(improved["go"]?.count, 1)
        XCTAssertEqual(searchImproved(improvedIndex, query: "go").first?.title, "Go Links")
    }

    func testPrefixBucketBenchmark() {
        let sizes = [1_000, 10_000, 50_000]
        let queries = ["go", "gi", "ho"]

        for size in sizes {
            let items = makeItems(count: size)

            let buildLegacy = measureMillis {
                _ = makeLegacyIndex(items: items)
            }
            let buildImproved = measureMillis {
                _ = makeImprovedIndex(items: items)
            }

            let legacyIndex = makeLegacyIndex(items: items)
            let improvedIndex = makeImprovedIndex(items: items)

            _ = searchLegacy(legacyIndex, query: "go")
            _ = searchImproved(improvedIndex, query: "go")

            var legacyTimes: [Double] = []
            var improvedTimes: [Double] = []

            for query in queries {
                legacyTimes.append(measureMillis {
                    _ = searchLegacy(legacyIndex, query: query)
                })
                improvedTimes.append(measureMillis {
                    _ = searchImproved(improvedIndex, query: query)
                })
            }

            let legacyAverage = legacyTimes.reduce(0, +) / Double(legacyTimes.count)
            let improvedAverage = improvedTimes.reduce(0, +) / Double(improvedTimes.count)

            print(
                """
                \nPrefix bucket benchmark size=\(size)
                  legacy build(ms)=\(String(format: "%.3f", buildLegacy))
                  improved build(ms)=\(String(format: "%.3f", buildImproved))
                  legacy avg(ms)=\(String(format: "%.3f", legacyAverage))
                  improved avg(ms)=\(String(format: "%.3f", improvedAverage))
                """
            )
        }

        XCTAssertTrue(true)
    }
}
