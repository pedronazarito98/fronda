import Foundation

public enum ExtensionKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case skill, mcp, command
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .skill: "Skill"
        case .mcp: "MCP"
        case .command: "Comando"
        }
    }
}

public struct ExtensionTool: Codable, Sendable, Identifiable {
    public var id: String { name }
    public var name = ""
    public var description = ""
    public var inputSchema = JSONValue.object(["type": .string("object")])
    public var enabled = false
    /// Granted by the user, never inferred from an MCP annotation.
    public var readOnly = false
    public init() {}
}

public struct HarnessExtension: Codable, Sendable, Identifiable {
    public var id = makeID()
    public var name = ""
    public var summary = ""
    public var kind = ExtensionKind.skill
    public var enabled = false
    public var projectIDs = [String]()
    public var stages = ["investigation", "plan", "implementation", "reproduction", "verification", "review"]
    public var keywords = [String]()
    public var executable = ""
    public var arguments = [String]()
    public var endpoint = ""
    public var authorizationReference: String?
    public var skillPath = ""
    public var skillContent = ""
    public var skillHash = ""
    public var tools = [ExtensionTool]()
    public var timeoutSeconds = 120
    public var version = 1
    public var status = "NOT_CHECKED"
    public var detail = ""
    public init() {}
}

public struct ExtensionBinding: Codable, Sendable, Identifiable {
    public var id: String { extensionID }
    public var extensionID: String
    public var version: Int
    public var name: String
    public var reason: String
    public var stages: [String]
    public init(_ item: HarnessExtension, reason: String) {
        extensionID = item.id
        version = item.version
        name = item.name
        self.reason = reason
        stages = item.stages
    }
}

/// An artifact is a recorded output, not an automatic assertion that a criterion passed.
public struct EvidenceArtifact: Codable, Sendable, Identifiable {
    public var id = makeID()
    public var title = ""
    public var hash = ""
    public var fileExtension = ""
    public var mimeType = ""
    public var byteCount = 0
    public var revision = ""
    public var criterionIDs = [String]()
    public var source = "CLI"
    public var attemptID: String?
    public var providerReadable = false
    public var createdAt = Date()
    public init() {}
}

public struct ExtensionInvocation: Codable, Sendable, Identifiable {
    public var id = makeID()
    public var extensionID = ""
    public var tool = ""
    public var argumentHash = ""
    public var state = "RUNNING"
    public var revision = ""
    public var resultHash: String?
    public init() {}
}
