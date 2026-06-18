import Foundation

enum WidgetSnapshotStore {
    private static let fileName = "widget-snapshot.json"
    private static let preferencesPlistName = "\(WidgetAppGroup.identifier).plist"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetAppGroup.identifier)
    }

    private static var containerURL: URL? {
        WidgetAppGroupContainer.resolvedURL()
    }

    private static var fileURLs: [URL] {
        candidateContainerURLs().flatMap { root in
            [
                root.appendingPathComponent("Library/Application Support/\(fileName)"),
                root.appendingPathComponent(fileName)
            ]
        }
    }

    private static var preferencesPlistURLs: [URL] {
        candidateContainerURLs().map {
            $0.appendingPathComponent("Library/Preferences/\(preferencesPlistName)")
        }
    }

    private static func candidateContainerURLs() -> [URL] {
        let urls = WidgetAppGroupContainer.candidateContainerURLs()
        return urls.isEmpty ? [WidgetAppGroupContainer.resolvedURL()].compactMap { $0 } : urls
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        return encoder
    }

    @discardableResult
    static func save(_ snapshot: WidgetSnapshot) -> Bool {
        let display = WidgetDisplayPayload.make(from: snapshot)
        var saved = false

        // Files first — macOS App Group UserDefaults is unreliable (CFPrefsPlistSource errors).
        if saveDisplay(display) {
            saved = true
        }

        #if os(macOS)
        if WidgetKeychainStore.saveDisplay(display) {
            saved = true
        }
        #endif

        if let data = try? encoder().encode(snapshot) {
            for fileURL in fileURLs {
                if write(data, to: fileURL) {
                    saved = true
                }
            }
        }

        #if os(macOS)
        if saveFlatToPlistFile(snapshot, display: display) {
            saved = true
        }
        #else
        if saveFlat(snapshot) {
            saved = true
        }

        if let data = try? encoder().encode(snapshot), let defaults {
            defaults.set(data, forKey: WidgetAppGroup.snapshotKey)
            saved = true
        }
        #endif

        #if DEBUG
        logSave(snapshot: snapshot, display: display, saved: saved)
        #endif

        return saved
    }

    static func load() -> WidgetSnapshot? {
        for fileURL in fileURLs {
            guard let data = try? Data(contentsOf: fileURL),
                  let snapshot = try? decoder().decode(WidgetSnapshot.self, from: data)
            else { continue }
            return snapshot
        }

        if let flat = loadFlatFromPreferencesPlist() {
            return flat
        }

        #if !os(macOS)
        if let flat = loadFlatFromDefaults() {
            return flat
        }

        if let defaults,
           let data = defaults.data(forKey: WidgetAppGroup.snapshotKey),
           let snapshot = try? decoder().decode(WidgetSnapshot.self, from: data) {
            return snapshot
        }
        #endif

        return nil
    }

    static func loadDisplay() -> WidgetDisplayPayload? {
        #if os(macOS)
        if let display = WidgetKeychainStore.loadDisplay() {
            return display
        }
        #endif

        if let display = loadDisplayFromPlist() {
            return display
        }

        for fileURL in displayFileURLs {
            guard let data = try? Data(contentsOf: fileURL),
                  let display = try? decoder().decode(WidgetDisplayPayload.self, from: data),
                  display.hasContent
            else { continue }
            return display
        }
        return nil
    }

    private static func loadDisplayFromPlist() -> WidgetDisplayPayload? {
        for preferencesPlistURL in preferencesPlistURLs {
            guard let dict = NSDictionary(contentsOf: preferencesPlistURL) as? [String: Any],
                  let hasData = boolValue(dict[WidgetAppGroup.FlatKey.hasData]), hasData,
                  let netWorth = dict[WidgetAppGroup.FlatKey.netWorthDisplay] as? String,
                  !netWorth.isEmpty
            else { continue }

            let updatedAt = Date(timeIntervalSinceReferenceDate: doubleValue(dict[WidgetAppGroup.FlatKey.updatedAt]))
            let liquid = dict[WidgetAppGroup.FlatKey.liquidDisplay] as? String ?? ""
            let invested = dict[WidgetAppGroup.FlatKey.investedDisplay] as? String ?? ""
            let nextBillName = dict[WidgetAppGroup.FlatKey.nextBillName] as? String
            let nextBillAmount = dict[WidgetAppGroup.FlatKey.nextBillAmountDisplay] as? String
            let nextBillDue = dict[WidgetAppGroup.FlatKey.nextBillDueDisplay] as? String

            return WidgetDisplayPayload(
                updatedAt: updatedAt,
                netWorth: netWorth,
                liquid: liquid,
                invested: invested,
                nextBillName: nextBillName?.isEmpty == true ? nil : nextBillName,
                nextBillAmount: nextBillAmount?.isEmpty == true ? nil : nextBillAmount,
                nextBillDue: nextBillDue?.isEmpty == true ? nil : nextBillDue,
                netWorthCompact: netWorth,
                liquidCompact: liquid,
                valuesHidden: boolValue(dict[WidgetAppGroup.FlatKey.valuesHidden]) ?? false
            )
        }
        return nil
    }

    private static var displayFileURLs: [URL] {
        candidateContainerURLs().flatMap { root in
            [
                root.appendingPathComponent("Library/Application Support/\(WidgetAppGroup.displayFileName)"),
                root.appendingPathComponent(WidgetAppGroup.displayFileName)
            ]
        }
    }

    @discardableResult
    private static func saveDisplay(_ display: WidgetDisplayPayload) -> Bool {
        guard let data = try? encoder().encode(display) else { return false }
        var saved = false

        for fileURL in displayFileURLs where write(data, to: fileURL) {
            saved = true
        }

        return saved
    }

    @discardableResult
    private static func write(_ data: Data, to fileURL: URL) -> Bool {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    private static func saveFlatToPlistFile(_ snapshot: WidgetSnapshot, display: WidgetDisplayPayload) -> Bool {
        guard !preferencesPlistURLs.isEmpty else { return false }

        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: flatDictionary(from: snapshot, display: display),
                format: .binary,
                options: 0
            )
            return preferencesPlistURLs.contains { write(data, to: $0) }
        } catch {
            return false
        }
    }

    private static func flatDictionary(from snapshot: WidgetSnapshot, display: WidgetDisplayPayload) -> [String: Any] {
        [
            WidgetAppGroup.FlatKey.hasData: true,
            WidgetAppGroup.FlatKey.updatedAt: snapshot.updatedAt.timeIntervalSinceReferenceDate,
            WidgetAppGroup.FlatKey.netWorthMinorUnits: NSNumber(value: snapshot.netWorthMinorUnits),
            WidgetAppGroup.FlatKey.liquidBalanceMinorUnits: NSNumber(value: snapshot.liquidBalanceMinorUnits),
            WidgetAppGroup.FlatKey.totalInvestedMinorUnits: NSNumber(value: snapshot.totalInvestedMinorUnits),
            WidgetAppGroup.FlatKey.pendingBillsTotalMinorUnits: NSNumber(value: snapshot.pendingBillsTotalMinorUnits),
            WidgetAppGroup.FlatKey.overdueBillsCount: snapshot.overdueBillsCount,
            WidgetAppGroup.FlatKey.nextBillName: snapshot.nextBillName ?? "",
            WidgetAppGroup.FlatKey.nextBillAmountMinorUnits: NSNumber(value: snapshot.nextBillAmountMinorUnits ?? 0),
            WidgetAppGroup.FlatKey.nextBillDueDate: snapshot.nextBillDueDate?.timeIntervalSinceReferenceDate ?? 0,
            WidgetAppGroup.FlatKey.nextBillIsOverdue: snapshot.nextBillIsOverdue,
            WidgetAppGroup.FlatKey.valuesHidden: snapshot.valuesHidden,
            WidgetAppGroup.FlatKey.netWorthDisplay: display.netWorth,
            WidgetAppGroup.FlatKey.liquidDisplay: display.liquid,
            WidgetAppGroup.FlatKey.investedDisplay: display.invested,
            WidgetAppGroup.FlatKey.nextBillAmountDisplay: display.nextBillAmount ?? "",
            WidgetAppGroup.FlatKey.nextBillDueDisplay: display.nextBillDue ?? ""
        ]
    }

    #if DEBUG
    private static func logSave(snapshot: WidgetSnapshot, display: WidgetDisplayPayload, saved: Bool) {
        let container = containerURL?.path ?? "(no container)"
        #if os(macOS)
        let keychainSaved = WidgetKeychainStore.loadDisplay() != nil ? "yes" : "no"
        #else
        let keychainSaved = "n/a"
        #endif
        NSLog(
            "Widget snapshot saved=%@ container=%@ keychain=%@ netWorth=%lld display=%@",
            saved ? "yes" : "no",
            container,
            keychainSaved,
            snapshot.netWorthMinorUnits,
            display.netWorth
        )
    }
    #endif

    @discardableResult
    private static func saveFlat(_ snapshot: WidgetSnapshot) -> Bool {
        guard let defaults else { return false }

        defaults.set(true, forKey: WidgetAppGroup.FlatKey.hasData)
        defaults.set(snapshot.updatedAt.timeIntervalSinceReferenceDate, forKey: WidgetAppGroup.FlatKey.updatedAt)
        defaults.set(NSNumber(value: snapshot.netWorthMinorUnits), forKey: WidgetAppGroup.FlatKey.netWorthMinorUnits)
        defaults.set(NSNumber(value: snapshot.liquidBalanceMinorUnits), forKey: WidgetAppGroup.FlatKey.liquidBalanceMinorUnits)
        defaults.set(NSNumber(value: snapshot.totalInvestedMinorUnits), forKey: WidgetAppGroup.FlatKey.totalInvestedMinorUnits)
        defaults.set(NSNumber(value: snapshot.pendingBillsTotalMinorUnits), forKey: WidgetAppGroup.FlatKey.pendingBillsTotalMinorUnits)
        defaults.set(snapshot.overdueBillsCount, forKey: WidgetAppGroup.FlatKey.overdueBillsCount)
        defaults.set(snapshot.nextBillName, forKey: WidgetAppGroup.FlatKey.nextBillName)
        defaults.set(NSNumber(value: snapshot.nextBillAmountMinorUnits ?? 0), forKey: WidgetAppGroup.FlatKey.nextBillAmountMinorUnits)
        defaults.set(snapshot.nextBillDueDate?.timeIntervalSinceReferenceDate ?? 0, forKey: WidgetAppGroup.FlatKey.nextBillDueDate)
        defaults.set(snapshot.nextBillIsOverdue, forKey: WidgetAppGroup.FlatKey.nextBillIsOverdue)
        defaults.set(snapshot.valuesHidden, forKey: WidgetAppGroup.FlatKey.valuesHidden)
        return true
    }

    private static func loadFlatFromDefaults() -> WidgetSnapshot? {
        guard let defaults,
              defaults.bool(forKey: WidgetAppGroup.FlatKey.hasData)
        else { return nil }
        return snapshot(from: defaults)
    }

    /// macOS widget extensions sometimes fail to read the shared suite; the plist on disk still updates.
    private static func loadFlatFromPreferencesPlist() -> WidgetSnapshot? {
        for preferencesPlistURL in preferencesPlistURLs {
            guard let dict = NSDictionary(contentsOf: preferencesPlistURL) as? [String: Any],
                  let hasData = dict[WidgetAppGroup.FlatKey.hasData] as? Bool,
                  hasData
            else { continue }
            return snapshot(from: dict)
        }
        return nil
    }

    private static func snapshot(from defaults: UserDefaults) -> WidgetSnapshot? {
        snapshot(from: defaults.dictionaryRepresentation())
    }

    private static func snapshot(from dict: [String: Any]) -> WidgetSnapshot? {
        guard let hasData = boolValue(dict[WidgetAppGroup.FlatKey.hasData]), hasData else { return nil }

        let updatedAt = Date(timeIntervalSinceReferenceDate: doubleValue(dict[WidgetAppGroup.FlatKey.updatedAt]))
        let nextBillDueInterval = doubleValue(dict[WidgetAppGroup.FlatKey.nextBillDueDate])
        let nextBillName = dict[WidgetAppGroup.FlatKey.nextBillName] as? String

        return WidgetSnapshot(
            updatedAt: updatedAt,
            netWorthMinorUnits: int64Value(dict[WidgetAppGroup.FlatKey.netWorthMinorUnits]),
            liquidBalanceMinorUnits: int64Value(dict[WidgetAppGroup.FlatKey.liquidBalanceMinorUnits]),
            totalInvestedMinorUnits: int64Value(dict[WidgetAppGroup.FlatKey.totalInvestedMinorUnits]),
            pendingBillsTotalMinorUnits: int64Value(dict[WidgetAppGroup.FlatKey.pendingBillsTotalMinorUnits]),
            overdueBillsCount: Int(int64Value(dict[WidgetAppGroup.FlatKey.overdueBillsCount])),
            nextBillName: nextBillName?.isEmpty == true ? nil : nextBillName,
            nextBillAmountMinorUnits: int64Value(dict[WidgetAppGroup.FlatKey.nextBillAmountMinorUnits]),
            nextBillDueDate: nextBillDueInterval > 0 ? Date(timeIntervalSinceReferenceDate: nextBillDueInterval) : nil,
            nextBillIsOverdue: boolValue(dict[WidgetAppGroup.FlatKey.nextBillIsOverdue]) ?? false,
            valuesHidden: boolValue(dict[WidgetAppGroup.FlatKey.valuesHidden]) ?? false
        )
    }

    private static func int64Value(_ value: Any?) -> Int64 {
        switch value {
        case let number as NSNumber: return number.int64Value
        case let int as Int: return Int64(int)
        case let int64 as Int64: return int64
        case let string as String: return Int64(string) ?? 0
        default: return 0
        }
    }

    private static func doubleValue(_ value: Any?) -> Double {
        switch value {
        case let number as NSNumber: return number.doubleValue
        case let double as Double: return double
        case let string as String: return Double(string) ?? 0
        default: return 0
        }
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let number as NSNumber: return number.boolValue
        case let bool as Bool: return bool
        default: return nil
        }
    }
}
