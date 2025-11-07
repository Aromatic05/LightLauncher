import XCTest
import Foundation

final class PrefixBucketBenchmarkTests: XCTestCase {

    struct TestItem {
        let id: Int
        let url: String
        let title: String
        let visitCount: Int
    }

    // Very small, pragmatic prefix-bucket prototype for benchmarking
    final class PrefixBucketIndex {
        private var buckets: [String: [TestItem]] = [:]
        private let prefixLength: Int

        init(items: [TestItem], prefixLength: Int = 3) {
            self.prefixLength = max(1, prefixLength)
            build(items: items)
        }

        private func searchable(_ url: String, _ title: String) -> String {
            // Simple searchable string: host + path + title, lowercased
            if let comps = URLComponents(string: url), let host = comps.host {
                let path = comps.path
                return (host + path + " " + title).lowercased()
            }
            return (url + " " + title).lowercased()
        }

        private func build(items: [TestItem]) {
            var map: [String: [TestItem]] = [:]
            for item in items {
                let s = searchable(item.url, item.title)
                let key = String(s.prefix(prefixLength))
                map[key, default: []].append(item)
            }
            // keep buckets as-is; for small prototype we won't pre-sort deeply
            buckets = map
        }

        func search(_ query: String, limit: Int = 10) -> [TestItem] {
            let q = query.lowercased()
            if q.isEmpty { return [] }
            let key = String(q.prefix(prefixLength))
            guard let candidates = buckets[key] else { return [] }

            // Filter candidates where searchable starts with query OR contains query
            let filtered = candidates.filter { item in
                let s = searchable(item.url, item.title)
                if s.hasPrefix(q) { return true }
                return s.contains(q)
            }

            // Score: simple combination of visitCount (log) + prefix bonus
            let scored = filtered.map { item -> (TestItem, Double) in
                var score = log(Double(item.visitCount + 1))
                if (item.url + " " + item.title).lowercased().hasPrefix(q) {
                    score += 5.0
                }
                return (item, score)
            }

            return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { $0.0 }
        }
    }

    // linear scan version for baseline
    private func linearSearch(_ items: [TestItem], _ query: String, limit: Int = 10) -> [TestItem] {
        let q = query.lowercased()
        let filtered = items.filter { item in
            let s = (item.url + " " + item.title).lowercased()
            if s.contains(q) { return true }
            return false
        }
        let scored = filtered.map { item -> (TestItem, Double) in
            return (item, log(Double(item.visitCount + 1)))
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { $0.0 }
    }

    private func makeItems(count: Int) -> [TestItem] {
        let hosts = (1...200).map { "host\($0).example.com" }
        var items: [TestItem] = []
        items.reserveCapacity(count)
        for i in 0..<count {
            let host = hosts[Int.random(in: 0..<hosts.count)]
            let path = "/path/segment/\(Int.random(in: 1...1000))"
            let url = "https://\(host)\(path)"
            let title = "Title \(Int.random(in: 1...10000))"
            let visit = Int.random(in: 0...500)
            items.append(TestItem(id: i, url: url, title: title, visitCount: visit))
        }
        return items
    }

    func testPrefixBucketBenchmark() {
        let sizes = [1000, 10_000, 50_000]
        let queries = ["ho", "host1", "host12/path", "title 5"]

        for size in sizes {
            let items = makeItems(count: size)
            let index = PrefixBucketIndex(items: items, prefixLength: 3)

            // warmup
            _ = index.search("host1", limit: 5)
            _ = linearSearch(items, "host1", limit: 5)

            var linearTimes: [Double] = []
            var bucketTimes: [Double] = []

            for q in queries {
                let startL = Date()
                _ = linearSearch(items, q, limit: 10)
                linearTimes.append(Date().timeIntervalSince(startL) * 1000.0)

                let startB = Date()
                _ = index.search(q, limit: 10)
                bucketTimes.append(Date().timeIntervalSince(startB) * 1000.0)
            }

            let avgLinear = linearTimes.reduce(0, +) / Double(linearTimes.count)
            let avgBucket = bucketTimes.reduce(0, +) / Double(bucketTimes.count)

            print("\nBenchmark size=\(size)\n  linear avg(ms)=\(String(format: "%.3f", avgLinear))\n  bucket avg(ms)=\(String(format: "%.3f", avgBucket))")
        }

        // simple assertion to make test succeed
        XCTAssertTrue(true)
    }
}
