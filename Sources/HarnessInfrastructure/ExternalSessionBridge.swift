import Foundation
import HarnessDomain

/// Receives lifecycle metadata only. Never opens transcript_path or provider storage.
public struct ExternalSessionBridge: Sendable {
    private let directory: URL

    public init(root: URL? = nil) {
        let base =
            root
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Harness", isDirectory: true)
        directory = base.appendingPathComponent("session-status", isDirectory: true)
    }

    private struct HookInput: Decodable {
        let sessionID: String
        let cwd: String
        let hookEventName: String
        let agentID: String?
        let source: String?
        enum CodingKeys: String, CodingKey {
            case sessionID = "session_id"
            case cwd
            case hookEventName = "hook_event_name"
            case agentID = "agent_id"
            case source
        }
    }

    public func receive(_ data: Data, provider: ProviderKind) throws {
        guard data.count <= 1_048_576 else { throw HarnessError("Evento de sessão grande demais.") }
        let input = try JSONDecoder().decode(HookInput.self, from: data)
        guard input.agentID == nil, !input.sessionID.isEmpty, input.sessionID.count <= 160,
            input.sessionID.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
        else { return }
        let state: ExternalSession.State
        switch input.hookEventName {
        case "SessionStart": state = input.source == "compact" ? .running : .idle
        case "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostCompact": state = .running
        case "PermissionRequest": state = .waiting
        case "Stop": state = .completed
        case "Interrupt", "StopFailure": state = .interrupted
        case "SessionEnd": state = .ended
        default: return
        }
        let project = String(URL(fileURLWithPath: input.cwd).lastPathComponent.prefix(100))
        let session = ExternalSession(
            sessionID: input.sessionID, provider: provider,
            project: project.isEmpty ? "Sessão externa" : project, state: state)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let url = directory.appendingPathComponent(Coding.hash(session.id) + ".json")
        try Coding.encode(session).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func sessions() throws -> [ExternalSession] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        let cutoff = Date.now.addingTimeInterval(-86400)
        return try files.compactMap { url -> ExternalSession? in
            guard url.pathExtension == "json" else { return nil }
            let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard info.isRegularFile == true, info.isSymbolicLink != true, (info.fileSize ?? 0) < 4096,
                let session = try? Coding.decode(ExternalSession.self, from: Data(contentsOf: url))
            else { return nil }
            guard session.updatedAt >= cutoff else { return nil }
            return session
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    public static func hookCommand(executable: String, provider: ProviderKind, root: URL?) -> String {
        func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        var command = quote(executable) + " session-event " + (provider == .codex ? "codex" : "claude")
        if let root { command += " --root " + quote(root.path) }
        return command
    }

    public static func events(for provider: ProviderKind) -> [String] {
        ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop", "SessionEnd"]
            + (provider == .codex ? ["Interrupt"] : ["StopFailure"])
    }
}
