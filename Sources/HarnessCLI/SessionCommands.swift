import Darwin
import Foundation
import HarnessDomain
import HarnessInfrastructure

enum SessionCommands {
    static func handle(_ args: [String], root: URL?) throws -> Bool {
        guard let command = args.first, ["session-event", "watch", "connect", "disconnect"].contains(command) else {
            return false
        }
        guard args.count >= 2, ["codex", "claude"].contains(args[1]) else {
            throw HarnessError("Uso: fronda watch codex|claude [argumentos do provider]")
        }
        let provider: ProviderKind = args[1] == "codex" ? .codex : .claude
        if command == "session-event" {
            // Hooks are observational: no stdout, permission decisions, or blocking errors.
            var data = Data()
            while data.count <= 1_048_576 {
                guard let chunk = try? FileHandle.standardInput.read(upToCount: 8192), !chunk.isEmpty else { break }
                data.append(chunk)
            }
            try? ExternalSessionBridge(root: root).receive(data, provider: provider)
            return true
        }
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().path
        if ["connect", "disconnect"].contains(command) {
            guard provider == .codex else { throw HarnessError("Para Claude Code, use fronda watch claude.") }
            try CodexIslandHooks.configure(executable: executable, root: root, enabled: command == "connect")
            print(
                command == "connect"
                    ? "Hooks do Fronda configurados. Revise e autorize em /hooks no Codex; depois inicie ou retome a sessão."
                    : "Hooks do Fronda removidos; os demais foram preservados.")
            return true
        }
        let hook = ExternalSessionBridge.hookCommand(executable: executable, provider: provider, root: root)
        let events = ExternalSessionBridge.events(for: provider)
        var arguments = [args[1]]
        if provider == .codex {
            try CodexIslandHooks.configure(executable: executable, root: root, enabled: true)
        } else {
            let handler: JSONValue = .object([
                "hooks": .array([
                    .object([
                        "type": .string("command"), "command": .string(hook), "timeout": .number(2),
                    ])
                ])
            ])
            let hooks = Dictionary(uniqueKeysWithValues: events.map { ($0, JSONValue.array([handler])) })
            arguments += ["--settings", try Coding.string(JSONValue.object(["hooks": .object(hooks)]))]
        }
        var forwarded = Array(args.dropFirst(2))
        if forwarded.first == "--" { forwarded.removeFirst() }
        arguments += forwarded
        // Replace the wrapper to preserve the interactive terminal and signal handling.
        let pointers = (["/usr/bin/env"] + arguments).map { strdup($0) } + [nil]
        defer { for pointer in pointers { free(pointer) } }
        pointers.withUnsafeBufferPointer { _ = execv("/usr/bin/env", $0.baseAddress!) }
        throw HarnessError("Não foi possível abrir \(provider.rawValue). Verifique a instalação do CLI.")
    }
}
