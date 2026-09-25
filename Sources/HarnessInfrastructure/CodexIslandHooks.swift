import Foundation
import HarnessDomain

public enum CodexIslandHooks {
    private static let marker = "Harness session status"

    /// Edits only the dedicated hooks file, preserving unrelated registrations.
    public static func configure(executable: String, root: URL?, enabled: Bool) throws {
        let home =
            ProcessInfo.processInfo.environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        let url = home.appendingPathComponent("hooks.json")
        let manager = FileManager.default
        var document = [String: JSONValue]()
        if manager.fileExists(atPath: url.path) {
            let info = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
            guard info.isSymbolicLink != true, info.isRegularFile == true, (info.fileSize ?? 0) <= 2_097_152 else {
                throw HarnessError(
                    "hooks.json não é um arquivo regular compatível. Configure a integração manualmente.")
            }
            let value = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url))
            guard case .object(let object) = value else { throw HarnessError("Formato de hooks.json não reconhecido.") }
            document = object
        } else if !enabled {
            return
        }
        if let existing = document["hooks"], case .object = existing {
        } else if document["hooks"] != nil {
            throw HarnessError("Formato de hooks.json não reconhecido.")
        }
        var hooks = document["hooks"]?.object ?? [:]
        let command = ExternalSessionBridge.hookCommand(executable: executable, provider: .codex, root: root)
        for event in ExternalSessionBridge.events(for: .codex) {
            if let existing = hooks[event], case .array = existing {
            } else if hooks[event] != nil {
                throw HarnessError("Registro de hook não reconhecido. Nenhuma alteração foi salva.")
            }
            var entries = (hooks[event]?.array ?? []).compactMap { entry -> JSONValue? in
                guard case .array(let handlers) = entry["hooks"] else { return entry }
                let remaining = handlers.filter { $0["statusMessage"].string != marker }
                guard remaining.count != handlers.count else { return entry }
                guard !remaining.isEmpty else { return nil }
                var result = entry.object
                result["hooks"] = .array(remaining)
                return .object(result)
            }
            if enabled {
                entries.append(
                    .object([
                        "hooks": .array([
                            .object([
                                "type": .string("command"), "command": .string(command), "timeout": .number(2),
                                "statusMessage": .string(marker),
                            ])
                        ])
                    ]))
            }
            if entries.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = .array(entries) }
        }
        document["hooks"] = .object(hooks)
        try manager.createDirectory(at: home, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try Coding.encode(JSONValue.object(document)).write(to: url, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
