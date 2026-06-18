import Foundation
#if os(macOS)
import Security
#endif

enum WidgetAppGroupContainer {
    static func candidateContainerURLs(fileManager: FileManager = .default) -> [URL] {
        var urls: [URL] = []

        if let url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: WidgetAppGroup.identifier) {
            urls.append(url)
        }

        #if os(macOS)
        let groupID = WidgetAppGroup.identifier
        let home = "/Users/\(NSUserName())"
        let paths = [
            "\(home)/Library/Group Containers/\(groupID)",
            "\(home)/Library/Group Containers/\(teamIdentifier()).\(groupID)"
        ]

        for path in paths {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if fileManager.fileExists(atPath: url.path) {
                urls.append(url)
            }
        }
        #endif

        var seen = Set<String>()
        return urls.filter { seen.insert($0.path).inserted }
    }

    static func resolvedURL(fileManager: FileManager = .default) -> URL? {
        candidateContainerURLs(fileManager: fileManager).first
    }

    #if os(macOS)
    private static func teamIdentifier() -> String {
        if let task = SecTaskCreateFromSelf(nil),
           let team = SecTaskCopyValueForEntitlement(task, "com.apple.developer.team-identifier" as CFString, nil) as? String {
            return team
        }
        return "DTL6JV77RD"
    }
    #endif
}
