import Foundation

// MARK: - Tool schema (provider-facing)

struct AIToolParameterDefinition: Hashable {
    let name: String
    let type: String
    let description: String
    let required: Bool
    let enumValues: [String]?

    init(
        name: String,
        type: String = "string",
        description: String,
        required: Bool = false,
        enumValues: [String]? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.required = required
        self.enumValues = enumValues
    }
}

struct AIToolDefinition: Hashable, Identifiable {
    var id: String { name }
    let name: String
    let description: String
    let parameters: [AIToolParameterDefinition]
    let isWrite: Bool

    init(name: String, description: String, parameters: [AIToolParameterDefinition] = [], isWrite: Bool = false) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.isWrite = isWrite
    }
}

// MARK: - Tool calls & results

struct AIToolCall: Hashable, Identifiable {
    let id: String
    let name: String
    let argumentsJSON: String

    var arguments: [String: Any] {
        guard let data = argumentsJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }
}

enum AIToolExecutionStatus: String, Codable {
    case success
    case error
    case pendingConfirmation = "pending_confirmation"
}

struct AIToolResultPayload: Codable {
    let ok: Bool
    let status: AIToolExecutionStatus?
    let data: AIToolJSONValue?
    let error: String?
    let summary: String?
    let actionID: String?

    enum CodingKeys: String, CodingKey {
        case ok, status, data, error, summary
        case actionID = "action_id"
    }

    static func success(_ data: AIToolJSONValue?) -> AIToolResultPayload {
        AIToolResultPayload(ok: true, status: .success, data: data, error: nil, summary: nil, actionID: nil)
    }

    static func failure(_ message: String) -> AIToolResultPayload {
        AIToolResultPayload(ok: false, status: .error, data: nil, error: message, summary: nil, actionID: nil)
    }

    static func pending(summary: String, actionID: UUID) -> AIToolResultPayload {
        AIToolResultPayload(
            ok: true,
            status: .pendingConfirmation,
            data: nil,
            error: nil,
            summary: summary,
            actionID: actionID.uuidString
        )
    }
}

// MARK: - JSON helpers

enum AIToolJSONValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AIToolJSONValue])
    case object([String: AIToolJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AIToolJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AIToolJSONValue].self) {
            self = .object(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    static func from(_ value: Any) -> AIToolJSONValue {
        switch value {
        case let value as String: return .string(value)
        case let value as Int: return .int(value)
        case let value as Double: return .double(value)
        case let value as Decimal:
            return .double(NSDecimalNumber(decimal: value).doubleValue)
        case let value as Bool: return .bool(value)
        case let value as UUID: return .string(value.uuidString)
        case let value as Date:
            return .string(ISO8601DateFormatter().string(from: value))
        case let value as [Any]: return .array(value.map { from($0) })
        case let value as [String: Any]:
            return .object(value.mapValues { from($0) })
        case Optional<Any>.none: return .null
        default: return .string(String(describing: value))
        }
    }
}

enum AIToolJSON {
    static let maxResultCharacters = 8_000

    static func encodeString(_ payload: AIToolResultPayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(payload),
              var string = String(data: data, encoding: .utf8) else {
            return #"{"ok":false,"error":"Falha ao serializar resultado"}"#
        }
        if string.count > maxResultCharacters {
            string = String(string.prefix(maxResultCharacters - 24)) + #"…","truncated":true}"#
        }
        return string
    }

    static func string(_ args: [String: Any], key: String) -> String? {
        guard let value = args[key] else { return nil }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    static func bool(_ args: [String: Any], key: String) -> Bool? {
        guard let value = args[key] else { return nil }
        if let bool = value as? Bool { return bool }
        if let string = value as? String {
            switch string.lowercased() {
            case "true", "1", "yes", "sim": return true
            case "false", "0", "no", "não", "nao": return false
            default: return nil
            }
        }
        if let number = value as? NSNumber { return number.boolValue }
        return nil
    }

    static func int(_ args: [String: Any], key: String) -> Int? {
        guard let value = args[key] else { return nil }
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String { return Int(string) }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }

    static func decimal(_ args: [String: Any], key: String) -> Decimal? {
        guard let value = args[key] else { return nil }
        if let decimal = value as? Decimal { return decimal }
        if let double = value as? Double { return Decimal(double) }
        if let int = value as? Int { return Decimal(int) }
        if let string = value as? String {
            let normalized = string
                .replacingOccurrences(of: "R$", with: "")
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return Decimal(string: normalized)
        }
        if let number = value as? NSNumber { return number.decimalValue }
        return nil
    }

    static func uuid(_ args: [String: Any], key: String) -> UUID? {
        guard let raw = string(args, key: key) else { return nil }
        return UUID(uuidString: raw)
    }

    static func date(_ args: [String: Any], key: String, calendar: Calendar = .current) -> Date? {
        guard let raw = string(args, key: key) else { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: raw) { return calendar.startOfDay(for: date) }
        let formats = ["yyyy-MM-dd", "dd/MM/yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return calendar.startOfDay(for: date)
            }
        }
        return nil
    }
}
