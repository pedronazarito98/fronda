import Foundation
import HarnessDomain

public enum ContextFirewall {
    private static let sensitiveComponents: Set<String> = [
        ".git", ".ssh", ".aws", ".azure", ".gnupg", ".codex", ".claude", "node_modules", ".build", "deriveddata",
        ".next", "dist", "build", "coverage", "sessions", "paste-cache", "auth", "credentials", "logs",
    ]
    public static func exclusion(_ path: String) -> String? {
        let components = path.split(separator: "/").map(String.init)
        let lower = path.lowercased()
        let name = components.last?.lowercased() ?? ""
        let sourceExtension = ["swift", "ts", "tsx", "js", "jsx", "py", "go", "rs", "c", "h", "cpp", "kt"].contains(
            URL(fileURLWithPath: name).pathExtension)
        if components.contains(where: { sensitiveComponents.contains($0.lowercased()) }) {
            return "Diretório privado ou gerado"
        }
        if name.hasPrefix(".env") || name.contains("auth.json")
            || (!sourceExtension && ["credential", "secret", "session", "token"].contains(where: name.contains))
        {
            return "Possível credencial ou sessão"
        }
        if [".sqlite", ".sqlite3", ".db", ".log", ".pem", ".p12", ".pfx", ".key", ".keystore", ".mobileprovision"]
            .contains(where: lower.hasSuffix)
        {
            return "Formato privado"
        }
        return nil
    }
    public static func redact(_ text: String) -> String {
        let patterns = [
            #"(?s)-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----"#,
            #"\b(?:sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{16,}|AKIA[A-Z0-9]{16})\b"#,
            #"(?i)(?:authorization\s*[:=]\s*[\"']?(?:bearer|basic)\s+)[A-Za-z0-9_./+=-]+"#,
            #"(?i)\b(?:api[_-]?key|access[_-]?token|password|client[_-]?secret)\s*[:=]\s*[\"'][^\"'\r\n]{4,}[\"']"#,
            #"https?://[^\s/@:]+:[^\s/@]+@"#,
        ]
        return patterns.reduce(text) { output, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return output }
            return regex.stringByReplacingMatches(
                in: output, range: NSRange(output.startIndex..., in: output), withTemplate: "[REDACTED]")
        }
    }
    public static func safeURL(_ url: String) -> String { redact(url) }
    public static func localFile(_ path: String) throws -> URL {
        guard path.hasPrefix("/") else { throw HarnessError("Informe um caminho absoluto.") }
        // Foundation abbreviates /private/tmp and /private/var. Expand only these system aliases;
        // containedPath still rejects symlinks in every user-controlled component.
        let expanded = path.hasPrefix("/tmp/") || path.hasPrefix("/var/") ? "/private" + path : path
        return try containedPath(String(expanded.dropFirst()), root: "/")
    }
    public static func containedPath(_ relative: String, root: String) throws -> URL {
        guard !relative.hasPrefix("/"), !relative.split(separator: "/").contains(".."), !relative.contains("\0") else {
            throw HarnessError("POLICY_DENIED: caminho fora do projeto.")
        }
        let base = URL(fileURLWithPath: root).resolvingSymlinksInPath().standardizedFileURL
        var componentURL = base
        for component in relative.split(separator: "/") {
            componentURL.appendPathComponent(String(component))
            if (try? FileManager.default.destinationOfSymbolicLink(atPath: componentURL.path)) != nil {
                throw HarnessError("POLICY_DENIED: use o arquivo original, sem links simbólicos.")
            }
        }
        let url = base.appendingPathComponent(relative).resolvingSymlinksInPath().standardizedFileURL
        let prefix = base.path.hasSuffix("/") ? base.path : base.path + "/"
        let resolvedRelative = String(url.path.dropFirst(prefix.count))
        guard url.path.hasPrefix(prefix), exclusion(relative) == nil, exclusion(resolvedRelative) == nil else {
            throw HarnessError("POLICY_DENIED: arquivo privado, link externo ou path excluído.")
        }
        return url
    }
    public static func matches(_ path: String, patterns: [String]) -> Bool {
        patterns.contains { pattern in
            if pattern == "**" { return true }
            if pattern.hasSuffix("/**") { return path.hasPrefix(String(pattern.dropLast(3)) + "/") }
            return path == pattern || (pattern.hasSuffix("/") && path.hasPrefix(pattern))
        }
    }
}
