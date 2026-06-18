import Foundation

// Keep in sync with CashFlow/Shared/Widgets/WidgetSnapshotStore.swift (read paths only).

enum WidgetSnapshotStore {
    private static let fileName = "widget-snapshot.json"
    private static let preferencesPlistName = "\(WidgetAppGroup.identifier).plist"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetAppGroup.identifier)
    }

    private static var fileURLs: [URL] {
        candidateContainerURLs().flatMap { root in
            [
                root.appendingPathComponent("Library/Application Support/\(fileName)"),
                root.appendingPathComponent(fileName)
            ]
        }
    }

    private static var displayFileURLs: [URL] {
        candidateContainerURLs().flatMap { root in
            [
                root.appendingPathComponent("Library/Application Support/\(WidgetAppGroup.displayFileName)"),
                root.appendingPathComponent(WidgetAppGroup.displayFileName)
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

        guard let snapshot = load(), snapshot.hasData else { return nil }
        return WidgetDisplayPayload.make(from: snapshot)
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

    private static func loadFlatFromDefaults() -> WidgetSnapshot? {
        guard let defaults,
              defaults.bool(forKey: WidgetAppGroup.FlatKey.hasData)
        else { return nil }
        return snapshot(from: defaults)
    }

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
