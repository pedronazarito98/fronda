import Foundation
import HarnessDomain

/// Reads only portable fields; environment, auth and hooks are never returned as executable configuration.
enum ProviderConfigReader {
    static func codex(_ source: String) -> (ExecutionConfiguration, [String: JSONValue], Bool) {
        var section = ""
        var defaults = ExecutionConfiguration()
        var servers = [String: JSONValue]()
        var unsupported = false
        var pending = ""
        for raw in source.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("[") && pending.isEmpty {
                section = String(line.dropFirst().prefix { $0 != "]" })
                continue
            }
            let combined = pending + line
            guard let separator = combined.firstIndex(of: "=") else { continue }
            let key = combined[..<separator].trimmingCharacters(in: .whitespaces)
            let rawValue = combined[combined.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            let keys = ["model", "model_reasoning_effort", "command", "args", "url"]
            guard keys.contains(key) else {
                pending = ""
                continue
            }
            if rawValue.hasPrefix("[") && !rawValue.contains("]") {
                pending = combined
                continue
            }
            pending = ""
            guard let value = scalar(rawValue) else {
                unsupported = true
                continue
            }
            if section.isEmpty {
                if key == "model" { defaults.model = value.string }
                if key == "model_reasoning_effort" { defaults.effort = value.string }
            } else if section.hasPrefix("mcp_servers.") {
                let name = String(section.dropFirst("mcp_servers.".count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                // Nested env/header tables are intentionally excluded.
                guard !name.contains("."), !name.isEmpty else { continue }
                var fields = servers[name]?.object ?? [:]
                fields[key] = value
                servers[name] = .object(fields)
            }
        }
        return (defaults, servers, unsupported || !pending.isEmpty)
    }

    private static func scalar(_ raw: String) -> JSONValue? {
        if raw.hasPrefix("'") && raw.dropFirst().contains("'") {
            return .string(String(raw.dropFirst().prefix { $0 != "'" }))
        }
        // JSON strings/arrays cover the portable TOML forms; unsupported TOML is surfaced for manual review.
        var quoted = false
        var escaped = false
        var value = ""
        for character in raw {
            if character == "#" && !quoted { break }
            value.append(character)
            if character == "\"" && !escaped { quoted.toggle() }
            escaped = character == "\\" && !escaped
        }
        return try? Coding.decode(JSONValue.self, from: Data(value.trimmingCharacters(in: .whitespaces).utf8))
    }

    static func mcp(name: String, fields: JSONValue, source: URL) -> ProviderImportItem {
        var item = ProviderImportItem()
        item.id = Coding.hash(source.path + "#mcp:" + name)
        item.kind = .mcp
        item.name = ProviderImportFiles.sanitized(name)
        item.source = source.path
        var configuration = HarnessExtension()
        configuration.kind = .mcp
        configuration.name = item.name
        configuration.executable = fields["command"].string
        configuration.arguments = fields["args"].array.map(\.string)
        configuration.endpoint = fields["url"].string
        configuration.summary = "Importado. Descubra e autorize as ferramentas antes de usar."
        item.detail = "Conexão desativada até você revisar as ferramentas. Variáveis e autenticação não são copiadas."
        let connection = ([configuration.executable, configuration.endpoint] + configuration.arguments)
            .joined(separator: "\n")
        let unsafeArgument = configuration.arguments.contains {
            $0.range(
                of: #"(?i)(token|secret|password|api.key|authorization|bearer|\$\{|\$\(|`|[A-Z_]{3,}=)"#,
                options: .regularExpression) != nil
        }
        let endpoint = URL(string: configuration.endpoint)
        let safeScheme =
            endpoint?.scheme == "https"
            || (endpoint?.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(endpoint?.host ?? ""))
        let unsafeURL =
            !configuration.endpoint.isEmpty
            && (endpoint?.host == nil || endpoint?.user != nil || endpoint?.password != nil || endpoint?.query != nil
                || endpoint?.fragment != nil || !safeScheme)
        let missingConnection = configuration.endpoint.isEmpty && configuration.executable.isEmpty
        let unsupportedTransport = ["sse", "sdk"].contains(fields["type"].string)
        if unsafeArgument || unsafeURL || unsupportedTransport || missingConnection
            || ProviderImportFiles.sanitized(connection) != connection
        {
            item.selectable = false
            item.detail = "Conexão exige configuração manual: transporte, argumento ou URL não portável."
            item.preview = "Parâmetros omitidos para preservar dados privados."
        } else {
            item.configuration = configuration
            item.preview = connection
            item.fingerprint = Coding.hash(connection)
        }
        return item
    }
}
