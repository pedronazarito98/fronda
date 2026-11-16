import Foundation

public enum ConversationTurnStatus: String, Codable, Sendable {
    case pending, completed, failed, cancelled
}

public struct ConversationAttachment: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let contentHash: String

    public init(name: String, contentHash: String) {
        self.id = makeID()
        self.name = name
        self.contentHash = contentHash
    }
}

public struct ConversationTurn: Codable, Identifiable, Sendable {
    public let id: String
    public var prompt: String
    public var reply = ""
    public var status = ConversationTurnStatus.pending
    public var provider: ProviderKind
    public var execution: ExecutionConfiguration
    public var autonomy: AutonomyMode?
    public var attachments = [ConversationAttachment]()
    public var runID: String?
    public var projectID: String?
    /// Pins the observed result when a later turn continues the same worktree.
    public var runSnapshotSequence: Int?
    public var createdAt = Date()

    public init(id: String, prompt: String, provider: ProviderKind, execution: ExecutionConfiguration) {
        self.id = id
        self.prompt = prompt
        self.provider = provider
        self.execution = execution
    }
}

public struct Conversation: Codable, Identifiable, Sendable {
    public let id: String
    public var title: String
    public var updatedAt = Date()
    public var archivedAt: Date?
    public var turns = [ConversationTurn]()
    /// Messages waiting for the current response; nil for conversations saved before queues existed.
    public var queuedTurns: [ConversationTurn]?

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}
