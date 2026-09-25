import Foundation

public struct Snapshot: Codable, Sendable {
    public var projects = [Project]()
    public var runs = [Run]()
    public var runbooks = [Runbook]()
    public var providers = [ProviderInfo]()
    public var preferences = AppPreferences()
    public var serviceVersion = "1.0.0"
    public var storageBytes: Int64 = 0
    public init() {}
}

public struct RPCRequest: Codable, Sendable {
    public var requestID = makeID()
    public var action: String
    public var id = ""
    public var relatedID = ""
    public var text = ""
    public var path = ""
    public var arguments = [String]()
    public var flag = false
    public var number = 0
    public var expectedSequence: Int?
    public var run: Run?
    public var project: Project?
    public var runbook: Runbook?
    public var preferences: AppPreferences?
    public var approval: Approval?
    public var exportOptions: EvidenceExportOptions?
    public var observation: ScenarioEvidence?
    public var extensionConfiguration: HarnessExtension?
    public var payload: JSONValue?
    public init(_ action: String) { self.action = action }
}

public struct RPCResponse: Codable, Sendable {
    public var payload: JSONValue?
    public var error: String?
    public var snapshot: Snapshot?
    public var run: Run?
    public var events: [RunEvent]?
    public var items: [ContextItem]?
    public var sourcePreview: SourcePreview?
    public var text = ""
    public var path = ""
    public var id = ""
    public init() {}
}

public enum JSONValue: Codable, Sendable, Equatable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() {
            self = .null
        } else if let object = try? value.decode([String: JSONValue].self) {
            self = .object(object)
        } else if let array = try? value.decode([JSONValue].self) {
            self = .array(array)
        } else if let string = try? value.decode(String.self) {
            self = .string(string)
        } else if let bool = try? value.decode(Bool.self) {
            self = .bool(bool)
        } else {
            self = .number(try value.decode(Double.self))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
    public subscript(_ key: String) -> JSONValue {
        if case .object(let v) = self { return v[key] ?? .null }
        return .null
    }
    public var string: String {
        if case .string(let v) = self { return v }
        return ""
    }
    public var int: Int? {
        if case .number(let v) = self { return Int(exactly: v) }
        return nil
    }
    public var double: Double? {
        if case .number(let v) = self { return v }
        return nil
    }
    public var array: [JSONValue] {
        if case .array(let v) = self { return v }
        return []
    }
    public var object: [String: JSONValue] {
        if case .object(let v) = self { return v }
        return [:]
    }
    public var bool: Bool {
        if case .bool(let v) = self { return v }
        return false
    }
}
