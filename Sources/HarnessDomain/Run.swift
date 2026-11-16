import Foundation

public struct SourceIntent: Codable, Sendable {
    public var kind = SourceKind.text
    public var text = ""
    public var sourceURL = ""
    public var issueKey: String?
    public var issueType: String?
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

    /// Legacy defaults describe the review process rather than an observable outcome.
    public var isGenericPlaceholder: Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value == "Objetivo atendido e revisado com evidência no snapshot vigente."
            || value == "A alteração solicitada neste turno foi revisada e validada na worktree."
    }
}

public enum RunGuidanceStatus: String, Codable, Sendable {
    case queued, delivered, uncertain, dismissed
}

public struct RunGuidance: Codable, Identifiable, Sendable {
    public let id: String
    public let text: String
    public let conversationTurnID: String?
    public let createdAt: Date
    public var status: RunGuidanceStatus
    public var attemptID: String?
    public var includedInPrompt: Bool?
    /// Immutable, redacted text snapshots; nil preserves orientations saved before attachments existed.
    public var attachments: [ConversationAttachment]?
    /// A missing or damaged snapshot requires an explicit decision before further work.
    public var attachmentError: String?
    public var continueWithoutAttachments: Bool?

    public init(id: String, text: String, conversationTurnID: String?, attachments: [ConversationAttachment] = []) {
        self.id = id
        self.text = text
        self.conversationTurnID = conversationTurnID
        self.createdAt = Date()
        self.status = .queued
        self.attachments = attachments.isEmpty ? nil : attachments
    }
}

public enum PauseStatus: String, Codable, Sendable {
    case requested, confirmed, uncertain, acknowledged
}

public struct Run: Codable, Identifiable, Sendable {
    public var id = makeID()
    public var projectID = ""
    public var conversationTurnID: String?
    public var conversationContextHash: String?
    public var title = ""
    public var source = SourceIntent()
    public var workflow: CardWorkflow?
    public var extensionInvocations: [ExtensionInvocation]?
    public var extensionBindings: [ExtensionBinding]?
    public var extensionOverrides: [String: Bool]?
    public var evidenceArtifacts: [EvidenceArtifact]?
    /// Messages sent while a conversation's project run is active.
    public var guidance: [RunGuidance]?
    public var loopExecution: LoopExecution?
    public var loopHistory: [LoopExecution]?
    /// New chat work may enable its default cycle once approved checks become available.
    /// Nil on older runs; false preserves a person's explicit choice to remove the cycle.
    public var chatLoopAutoEligible: Bool?
    public var runbook = Runbook()
    public var provider = ProviderKind.codex
    public var execution: ExecutionConfiguration?
    public var mode = AutonomyMode.guided
    public var state = RunState.draft
    /// Confirmation concerns processes tracked by this coordinator, not remote effects.
    public var pauseStatus: PauseStatus?
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
    /// Original limit of a budget-blocked task, retained while its limit is being adjusted.
    public var budgetAtLastBlock: Int?
    public var priority = 0
    public var sequence = 0
    public var forkOf: String?
    public var createdAt = Date()
    public var updatedAt = Date()
    public init() {}
    public var reportedTokens: Int { tokens.reduce(0) { $0 + ($1.input ?? 0) + ($1.output ?? 0) } }
    public var pauseNeedsConfirmation: Bool {
        if state == .paused { return pauseStatus != .confirmed && pauseStatus != .acknowledged }
        return state == .recovering && (pauseStatus == .requested || pauseStatus == .uncertain)
    }
    public var needsBudgetRecheck: Bool {
        state == .blocked && reason.localizedCaseInsensitiveContains("orçamento")
            && budgetAtLastBlock.map { budget > $0 && budget > reportedTokens } == true
    }
    public var completedSteps: Int { plan.filter { $0.status == .pass }.count }
    public var hasUnresolvedExternalOperations: Bool {
        approvals.contains { ["PREPARED", "APPROVED", "SENDING", "UNKNOWN"].contains($0.state) }
            || extensionInvocations?.contains { ["RUNNING", "UNKNOWN"].contains($0.state) } == true
    }
}

public struct Attempt: Codable, Identifiable, Sendable {
    public var id = makeID()
    public var provider = ProviderKind.codex
    public var model: String?
    public var effort: String?
    public var sessionID = ""
    public var turnID = ""
    public var stepID = ""
    public var packID = ""
    public var promptHash: String?
    public var loopIterationID: String?
    public var status = "RUNNING"
    public var startedAt = Date()
    public var finishedAt: Date?
    public init() {}
}

public enum CriterionLinkOrigin: String, Codable, Sendable {
    case agent, human
}

public struct ChangedFile: Codable, Identifiable, Sendable {
    public var id: String { path }
    public var path: String
    public var status: String
    public var additions: Int
    public var deletions: Int
    public var linkedCriteria = [String]()
    /// Missing entries are preserved legacy associations with unknown origin.
    public var criterionLinkOrigins: [String: CriterionLinkOrigin]?
    public init(path: String, status: String, additions: Int = 0, deletions: Int = 0) {
        self.path = path
        self.status = status
        self.additions = additions
        self.deletions = deletions
    }
}
