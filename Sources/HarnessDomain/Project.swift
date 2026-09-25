import Foundation

public struct Project: Codable, Identifiable, Sendable, Hashable {
    public var id = makeID()
    public var name = ""
    public var path = ""
    public var bookmark: Data?
    public var branch = ""
    public var head = ""
    public var dirty = false
    public var remote = ""
    public var indexState = "NOT_INDEXED"
    public var indexedFiles = 0
    public var indexMessage = ""
    public var indexedAt: Date?
    public var exclusions = [String]()
    public var validators = [Validator]()
    public var allowedPaths = ["**"]
    public var lockedPaths = [String]()
    public var requireStrongIsolation = false
    public var allowNetwork = false
    public var providerLimit = 2
    public var disabledProviders: [ProviderKind]?
    public var contextWeights: [String: Int]?
    public var jiraAcceptanceField: String?
    public var createdAt = Date()
    public init() {}
}

public struct Validator: Codable, Identifiable, Sendable, Hashable {
    public var id = makeID()
    public var name = ""
    public var executable = ""
    public var arguments = [String]()
    public var timeoutSeconds = 300
    public var required = true
    public var approved = false
    public var readOnly = false
    public init() {}
    public var displayCommand: String {
        ([executable] + arguments).map { $0.contains(" ") ? "\"\($0)\"" : $0 }.joined(separator: " ")
    }
}

public struct ProviderInfo: Codable, Identifiable, Sendable {
    public var id: String { kind.rawValue }
    public var kind: ProviderKind
    public var path = ""
    public var version = ""
    public var state = "UNAVAILABLE"
    public var detail = "Verificando instalação…"
    public var liveSteer = false
    public var resume = false
    public var controlledTools = false
    public init(kind: ProviderKind) { self.kind = kind }
}

public struct AppPreferences: Codable, Sendable {
    public var extensions: [HarnessExtension]?
    public var concurrency = 2
    public var perProjectConcurrency = 2
    public var perProviderConcurrency = 2
    public var queuePaused = false
    public var tokenBudget = 32000
    public var contextBudget = 12000
    public var notifications = false
    public var appearance = "Sistema"
    public var providers = [String: String]()
    public var integrationAccounts = [IntegrationAccount]()
    public init() {}
}

public struct IntegrationAccount: Codable, Identifiable, Sendable, Hashable {
    public var id = makeID()
    public var name = ""
    public var kind = "GitHub"
    public var endpoint = "https://api.github.com"
    public var clientID = ""
    public var keychainReference = ""
    public var connected = false
    public init() {}
}
