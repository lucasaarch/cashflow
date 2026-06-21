import Foundation

enum SpotlightSearch {
    static func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func matches(_ haystack: String, query: String) -> Bool {
        let q = normalized(query)
        guard !q.isEmpty else { return true }
        return normalized(haystack).contains(q)
    }

    static func matchesAny(_ query: String, _ values: String...) -> Bool {
        values.contains { matches($0, query: query) }
    }

    static func results<T>(
        in source: [T],
        query: String,
        limit: Int,
        where predicate: (T) -> Bool
    ) -> [T] {
        let q = normalized(query)
        guard !q.isEmpty else { return [] }
        return Array(source.filter(predicate).prefix(limit))
    }

    static func resultsNamed<T>(
        in source: [T],
        query: String,
        limit: Int,
        name: KeyPath<T, String>
    ) -> [T] {
        results(in: source, query: query, limit: limit) { matches($0[keyPath: name], query: query) }
    }

    static func resultsMatchingAny<T>(
        in source: [T],
        query: String,
        limit: Int,
        fields: (T) -> [String]
    ) -> [T] {
        results(in: source, query: query, limit: limit) { item in
            fields(item).contains { matches($0, query: query) }
        }
    }
}
