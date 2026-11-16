import HarnessDomain

struct ChatComposerDraft: Equatable {
    var prompt = ""
    var attachments = [String]()
    var provider: ProviderKind = .codex
    var execution = ExecutionConfiguration()
    var projectID: String?
    var autonomy: AutonomyMode = .auto
    var adjustingRunID: String?
    var requestID = makeID()

    init(
        lastTurn: ConversationTurn? = nil, preferences: AppPreferences = AppPreferences(),
        providers: [ProviderInfo] = []
    ) {
        provider =
            lastTurn?.provider ?? ProviderKind.allCases.first { kind in
                providers.contains { $0.kind == kind && $0.state == "AVAILABLE" }
            } ?? .codex
        autonomy = lastTurn?.autonomy ?? .auto
        execution = lastTurn?.execution ?? preferences.providerDefaults?[provider.rawValue] ?? ExecutionConfiguration()
    }

    mutating func clearSentContent() {
        prompt = ""
        attachments.removeAll()
        projectID = nil
        adjustingRunID = nil
        requestID = makeID()
    }

    mutating func clearSentGuidance() {
        prompt = ""
        attachments.removeAll()
        requestID = makeID()
    }
}
