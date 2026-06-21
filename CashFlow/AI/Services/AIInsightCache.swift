import Foundation

enum AIInsightCache {
    /// Regenerates cached Gio summaries after this interval.
    static let staleInterval: TimeInterval = 2 * 60 * 60

    static func isStale(cachedAt: Date?, now: Date = .now) -> Bool {
        guard let cachedAt else { return true }
        return now.timeIntervalSince(cachedAt) >= staleInterval
    }

    static func freshnessLabel(cachedAt: Date?, now: Date = .now) -> String? {
        guard let cachedAt else { return nil }
        let seconds = Int(now.timeIntervalSince(cachedAt))
        switch seconds {
        case ..<60: return "agora mesmo"
        case 60..<3600:
            let minutes = seconds / 60
            return "há \(minutes) min"
        case 3600..<86400:
            let hours = seconds / 3600
            return "há \(hours)h"
        default:
            let days = seconds / 86400
            return "há \(days)d"
        }
    }
}
