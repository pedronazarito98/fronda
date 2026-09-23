import Foundation

public struct SourceIntent: Codable, Sendable {
    public var kind = SourceKind.text
    public var text = ""
    public var sourceURL = ""
    public var attachments = [String]()
    public var revision = ""
    public var capturedAt = Date()
    public init() {}
}

public struct SourcePreview: Codable, Sendable {
    public var intent = SourceIntent()
    public var criteria = [String]()
    public var attachments = [RemoteAttachment]()
    public init() {}
}

public struct RemoteAttachment: Codable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var size: Int
    public init(id: String, name: String, size: Int) {
        self.id = id
        self.name = name
        self.size = size
    }
}

public struct Criterion: Codable, Identifiable, Sendable {
    public var id = makeID()
    public var text = ""
    public var state = "UNVERIFIED"
    public var evidence = [String]()
    public init(text: String = "") { self.text = text }
}

public struct Run: Codable, Identifiable, Sendable {
    public var id = makeID()
    public var projectID = ""
    public var title = ""
    public var source = SourceIntent()
    public var runbook = Runbook()
    public var provider = ProviderKind.codex
    public var mode = AutonomyMode.guided
    public var state = RunState.draft
    public var reason = ""
    public var baseSHA = ""
    public var workspace = ""
    public var branch = ""
    public var revision = ""
    public var scope = ["**"]
    public var lockedPaths = [String]()
    public var pins = [String]()
    public var exclusions = [String]()
    public var criteria = [Criterion]()
    public var plan = [RunbookStep]()
    public var planRevision = 1
    public var planApproved = false
    public var contextApproved = false
    public var pack: ContextPack?
    public var attempts = [Attempt]()
    public var validations = [ValidationResult]()
    public var findings = [ReviewFinding]()
    public var approvals = [Approval]()
    public var tokens = [TokenRecord]()
    public var changedFiles = [ChangedFile]()
    public var diff = ""
    public var report = ""
    public var reviewRevision = ""
    public var humanReviewRevision = ""
    public var budget = 32000
    public var priority = 0
    public var sequence = 0
    public var forkOf: String?
    public var createdAt = Date()
    public var updatedAt = Date()
    public init() {}
    public var reportedTokens: Int { tokens.reduce(0) { $0 + ($1.input ?? 0) + ($1.output ?? 0) } }
    public var completedSteps: Int { plan.filter { $0.status == .pass }.count }
}

public struct Attempt: Codable, Identifiable, Sendable {
    public var id = makeID()
    public var provider = ProviderKind.codex
    public var sessionID = ""
    public var turnID = ""
    public var stepID = ""
    public var packID = ""
    public var promptHash: String?
    public var status = "RUNNING"
    public var startedAt = Date()
    public var finishedAt: Date?
    public init() {}
}

public struct ChangedFile: Codable, Identifiable, Sendable {
    public var id: String { path }
    public var path: String
    public var status: String
    public var additions: Int
    public var deletions: Int
    public var linkedCriteria = [String]()
    public init(path: String, status: String, additions: Int = 0, deletions: Int = 0) {
        self.path = path
        self.status = status
        self.additions = additions
        self.deletions = deletions
    }
}
