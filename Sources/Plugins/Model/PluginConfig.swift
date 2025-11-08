import Foundation

struct PluginConfig: Codable {
    var settings: [String: ConfigValue]

    init(settings: [String: ConfigValue] = [:]) {
        self.settings = settings
    }
}

struct ConfigValue: Codable {
    var type: String
    var value: Any
    var description: String?

    enum CodingKeys: String, CodingKey {
        case type
        case value
        case description
    }

    init(type: String, value: Any, description: String? = nil) {
        self.type = type
        self.value = value
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        description = try container.decodeIfPresent(String.self, forKey: .description)

        // 根据类型解码值
        switch type {
        case "string":
            value = try container.decode(String.self, forKey: .value)
        case "number":
            value = try container.decode(Double.self, forKey: .value)
        case "boolean":
            value = try container.decode(Bool.self, forKey: .value)
        default:
            value = try container.decode(String.self, forKey: .value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(description, forKey: .description)

        // 根据类型编码值
        switch type {
        case "string":
            try container.encode(value as? String ?? "", forKey: .value)
        case "number":
            try container.encode(value as? Double ?? 0, forKey: .value)
        case "boolean":
            try container.encode(value as? Bool ?? false, forKey: .value)
        default:
            try container.encode(String(describing: value), forKey: .value)
        }
    }
}
