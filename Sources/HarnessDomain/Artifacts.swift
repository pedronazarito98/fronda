import Foundation

public struct EvidenceExportOptions: Codable, Sendable {
    public var includeDiff = true
    public var includeEvents = true
    public var includeText = true
    public init() {}
}

public struct ContextItem: Codable, Identifiable, Sendable {
    public var id: String { path }
    public var path = ""
    public var hash = ""
    public var content = ""
    public var reason = ""
    public var score = 0
    public var estimatedTokens = 0
    public var included = false
    public var symbols = [String]()
    public var imports = [String]()
    public var classification = "source"
    public var references: [String]?
    public var associatedTests: [String]?
    public var gitHistory: [String]?
    public var parserRevision: String?
    public init() {}
}

public struct ContextPack: Codable, Identifiable, Sendable {
    public var id = makeID()
    public var version = 1
    public var provider = ProviderKind.codex
    public var revision = ""
    public var payload = ""
    public var hash = ""
    public var items = [ContextItem]()
    public var estimatedTokens = 0
    public var baselineTokens = 0
    public var estimateMethod = "UTF-8 / 4, arredondado para cima; não é tokenizer do provider"
    public var createdAt = Date()
    public init() {}
}

public struct ValidationResult: Codable, Identifiable, Sendable {
    public var id = makeID()
    public var validator = Validator()
    public var status = GateStatus.notRun
    public var revision = ""
    public var output = ""
    public var artifactHash = ""
    public var exitCode: Int32?
    public var duration: Double = 0
    public var environment = [String: String]()
    public var createdAt = Date()
    public init() {}
}

public struct ReviewFinding: Codable, Identifiable, Sendable {
    public var id = makeID()
    public var severity = "P2"
    public var title = ""
    public var path = ""
    public var evidence = ""
    public var author = "Scope Guard"
    public var state = "OPEN"
    public var resolution = ""
    public var revision = ""
    public init() {}
}

public struct Approval: Codable, Identifiable, Sendable {
    public var id = makeID()
    public var kind = ""
    public var title = ""
    public var payload = ""
    public var payloadHash = ""
    public var revision = ""
    public var state = "PREPARED"
    public var destination = ""
    public var providerRequestID = ""
    public var accountID: String?
    public var endpoint: String?
    public var createdAt = Date()
    public var expiresAt = Date().addingTimeInterval(86400)
    public var result = ""
    public init() {}
}

public struct TokenRecord: Codable, Identifiable, Sendable {
    public var id = makeID()
    public var attemptID = ""
    public var provider = ProviderKind.codex
    public var model = "indisponível"
    public var step = ""
    public var input: Int?
    public var output: Int?
    public var cachedInput: Int?
    public var estimatedPackInput = 0
    public var cost: Double?
    public var costSource = "indisponível"
    public var source = "estimated"
    public var createdAt = Date()
    public init() {}
}

public struct RunEvent: Codable, Identifiable, Sendable {
    public var id = makeID()
    public var runID = ""
    public var sequence = 0
    public var kind = ""
    public var actor = "Harness"
    public var message = ""
    public var revision = ""
    public var artifactHash = ""
    public var occurredAt = Date()
    public init() {}
}
