import Foundation
import HarnessDomain
import HarnessInfrastructure

public enum ProviderGateway {
    public static func probe(overrides: [String: String]) async -> [ProviderInfo] {
        var result = [ProviderInfo]()
        for kind in ProviderKind.allCases {
            var info = ProviderInfo(kind: kind)
            let name = kind == .codex ? "codex" : "claude"
            guard let path = ProcessRunner.resolve(overrides[kind.rawValue] ?? name) else {
                info.detail = "Instale \(kind.rawValue) pelo fluxo oficial e informe o caminho nas preferências."
                result.append(info)
                continue
            }
            info.path = path
            do {
                let version = try await ProcessRunner.run(path, ["--version"], cwd: NSTemporaryDirectory(), timeout: 15)
                info.version = version.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                guard version.exitCode == 0 else { throw HarnessError("Não foi possível consultar a versão.") }
                if kind == .claude {
                    let help = try await ProcessRunner.run(path, ["--help"], cwd: NSTemporaryDirectory(), timeout: 15)
                    info.controlledTools =
                        help.stdout.contains("--restricted") && help.stdout.contains("--strict-mcp-config")
                    if !info.controlledTools {
                        info.state = "VERSION_UNSUPPORTED"
                        info.detail =
                            "Esta instalação não oferece --restricted. O perfil controlado exige Claude Code 2.1.248+ com essa capacidade."
                        result.append(info)
                        continue
                    }
                    // Authentication is delegated to the official CLI, never read from its private files.
                    let auth = try await ProcessRunner.run(
                        path, ["auth", "status"], cwd: NSTemporaryDirectory(), timeout: 15)
                    info.state = auth.exitCode == 0 ? "AVAILABLE" : "AUTH_REQUIRED"
                    info.detail =
                        auth.exitCode == 0
                        ? "Modo restrito e ferramentas mediadas disponíveis."
                        : "Autentique pelo comando claude auth login."
                    info.resume = false
                } else {
                    let auth = try await ProcessRunner.run(
                        path, ["login", "status"], cwd: NSTemporaryDirectory(), timeout: 15)
                    info.state = auth.exitCode == 0 ? "AVAILABLE" : "AUTH_REQUIRED"
                    info.detail =
                        auth.exitCode == 0
                        ? "App Server · streaming · steering · ferramentas mediadas."
                        : "Autentique pelo comando codex login."
                    info.liveSteer = true
                    info.resume = false
                    info.controlledTools = true
                }
            } catch {
                info.state = "UNAVAILABLE"
                info.detail = ContextFirewall.redact(error.localizedDescription)
            }
            result.append(info)
        }
        return result
    }
}

public struct AgentOutcome: Sendable {
    public var sessionID: String
    public var text: String
    public var status: String
    public var usage: TokenRecord?
    public init(sessionID: String = "", text: String = "", status: String = "completed", usage: TokenRecord? = nil) {
        self.sessionID = sessionID
        self.text = text
        self.status = status
        self.usage = usage
    }
}

public typealias AgentEventHandler = @Sendable (String, JSONValue) async -> Void
public typealias AgentToolHandler = @Sendable (String, JSONValue) async -> String
