import Foundation

enum MCPJSONSchema {
    static func build(from definition: AIToolDefinition) -> [String: Any] {
        var properties: [String: Any] = [:]
        var required: [String] = []

        for parameter in definition.parameters {
            var property: [String: Any] = [
                "type": jsonType(for: parameter.type),
                "description": parameter.description
            ]
            if let enumValues = parameter.enumValues, !enumValues.isEmpty {
                property["enum"] = enumValues
            }
            properties[parameter.name] = property
            if parameter.required {
                required.append(parameter.name)
            }
        }

        var schema: [String: Any] = [
            "type": "object",
            "properties": properties
        ]
        if !required.isEmpty {
            schema["required"] = required
        }
        if definition.name == "preview_write_action" {
            schema["additionalProperties"] = true
        }
        return schema
    }

    private static func jsonType(for parameterType: String) -> String {
        switch parameterType {
        case "integer": return "integer"
        case "boolean": return "boolean"
        case "number": return "number"
        default: return "string"
        }
    }
}
