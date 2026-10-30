import Foundation
import HarnessDomain

public enum ProviderContextScanner {
    public static func scan(provider: ProviderKind, project: Project? = nil) -> ProviderImportPreview {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let environment = ProcessInfo.processInfo.environment
        let override = environment[provider == .codex ? "CODEX_HOME" : "CLAUDE_CONFIG_DIR"]
        let root =
            override.map { URL(fileURLWithPath: $0) }
            ?? home.appendingPathComponent(provider == .codex ? ".codex" : ".claude")
        var result = ProviderImportPreview(provider: provider)
        result.projectID = project?.id
        scanRoot(root, provider: provider, scope: "Este usuário", into: &result)
        if provider == .codex {
            addDocuments(
                home.appendingPathComponent(".agents/skills"), filename: "SKILL.md", kind: .skill,
                scope: "Este usuário", into: &result)
        }
        // Only known capability directories in installed packages; no broad scan of provider data.
        let plugins = root.appendingPathComponent("plugins/cache")
        let pluginDocuments = ProviderImportFiles.documents(in: plugins, filename: "SKILL.md", depth: 8)
        reportLimit(pluginDocuments, scope: "Plugins instalados", into: &result)
        for url in pluginDocuments
        where url.pathComponents.contains("skills") {
            addDocument(url, kind: .skill, scope: "Plugin instalado", into: &result)
        }
        if let project {
            let projectRoot = URL(fileURLWithPath: project.path)
            scanRoot(
                projectRoot.appendingPathComponent(provider == .codex ? ".codex" : ".claude"),
                provider: provider, scope: project.name, into: &result)
            let rules = provider == .codex ? ["AGENTS.md", "AGENTS.override.md"] : ["CLAUDE.md", "CLAUDE.local.md"]
            for name in rules {
                addDocument(projectRoot.appendingPathComponent(name), kind: .rule, scope: project.name, into: &result)
            }
            if provider == .codex {
                addDocuments(
                    projectRoot.appendingPathComponent(".agents/skills"), filename: "SKILL.md", kind: .skill,
                    scope: project.name, into: &result)
            } else {
                addJSON(projectRoot.appendingPathComponent(".mcp.json"), scope: project.name, into: &result)
            }
        }
        if provider == .claude {
            result.warnings.append(
                "MCPs privados em ~/.claude.json precisam ser cadastrados em Extensões ou exportados para .mcp.json do projeto. Esse arquivo mistura dados privados e não é aberto."
            )
        }
        result.warnings.append(
            "Hooks, permissões, credenciais, sessões e históricos não são importados. Instruções de agentes e comandos entram como texto; scripts não são executados."
        )
        var seen = Set<String>()
        result.items = result.items.filter { seen.insert($0.id).inserted }.sorted {
            $0.kind.rawValue == $1.kind.rawValue
                ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                : $0.kind.rawValue < $1.kind.rawValue
        }
        return result
    }

    private static func scanRoot(
        _ root: URL, provider: ProviderKind, scope: String,
        into result: inout ProviderImportPreview
    ) {
        addDocuments(
            root.appendingPathComponent("skills"), filename: "SKILL.md", kind: .skill, scope: scope, into: &result)
        addDocuments(root.appendingPathComponent("rules"), kind: .rule, scope: scope, into: &result)
        addDocuments(root.appendingPathComponent("commands"), kind: .prompt, scope: scope, into: &result)
        addDocuments(root.appendingPathComponent("agents"), kind: .agent, scope: scope, into: &result)
        for name in provider == .codex ? ["AGENTS.md", "AGENTS.override.md"] : ["CLAUDE.md"] {
            addDocument(root.appendingPathComponent(name), kind: .rule, scope: scope, into: &result)
        }
        if provider == .codex {
            let url = root.appendingPathComponent("config.toml")
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            do {
                let (execution, servers, unsupported) = ProviderConfigReader.codex(try ProviderImportFiles.read(url))
                addSettings(execution, source: url, scope: scope, into: &result)
                for (name, fields) in servers {
                    var item = ProviderConfigReader.mcp(name: name, fields: fields, source: url)
                    item.scope = scope
                    result.items.append(item)
                }
                if unsupported { result.warnings.append("Alguns valores TOML de \(scope) exigem configuração manual.") }
            } catch {
                result.warnings.append("Não foi possível ler config.toml de \(scope): \(error.localizedDescription)")
            }
        } else {
            addJSON(root.appendingPathComponent("settings.json"), scope: scope, into: &result)
            addJSON(root.appendingPathComponent("settings.local.json"), scope: scope, into: &result)
        }
    }

    private static func addJSON(_ url: URL, scope: String, into result: inout ProviderImportPreview) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let fields = try Coding.decode(JSONValue.self, from: Data(ProviderImportFiles.read(url).utf8))
            addSettings(
                ExecutionConfiguration(
                    model: fields.object["model"]?.string,
                    effort: fields.object["effortLevel"]?.string),
                source: url, scope: scope, into: &result)
            for (name, value) in fields["mcpServers"].object {
                var item = ProviderConfigReader.mcp(name: name, fields: value, source: url)
                item.scope = scope
                result.items.append(item)
            }
        } catch { result.warnings.append("Não foi possível ler \(url.lastPathComponent) de \(scope).") }
    }

    private static func addSettings(
        _ execution: ExecutionConfiguration, source: URL, scope: String,
        into result: inout ProviderImportPreview
    ) {
        guard execution.model != nil || execution.effort != nil else { return }
        var item = ProviderImportItem()
        item.id = Coding.hash(source.path + "#settings")
        item.kind = .settings
        item.name = "Padrão de execução · \(scope)"
        item.source = source.path
        item.scope = scope
        item.execution = try? execution.validated()
        item.preview = ProviderImportFiles.sanitized(execution.summary)
        item.selectable = item.execution != nil && item.preview == execution.summary
        if !item.selectable { item.execution = nil }
        item.fingerprint = Coding.hash(item.preview)
        item.detail = "Aplicar como padrão para novas tarefas deste provider."
        result.items.append(item)
    }

    private static func addDocuments(
        _ root: URL, filename: String? = nil, kind: ProviderImportKind, scope: String,
        into result: inout ProviderImportPreview
    ) {
        let documents = ProviderImportFiles.documents(in: root, filename: filename)
        reportLimit(documents, scope: "\(scope) / \(root.lastPathComponent)", into: &result)
        for url in documents {
            addDocument(url, kind: kind, scope: scope, into: &result)
        }
    }

    private static func reportLimit(_ documents: [URL], scope: String, into result: inout ProviderImportPreview) {
        if documents.count >= 500 {
            result.warnings.append("\(scope): limite de 500 documentos atingido; a lista pode estar incompleta.")
        }
    }

    private static func addDocument(
        _ url: URL, kind: ProviderImportKind, scope: String,
        into result: inout ProviderImportPreview
    ) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var item = ProviderImportItem()
        item.id = Coding.hash(url.path)
        item.kind = kind
        item.source = url.path
        item.scope = scope
        item.name =
            kind == .skill
            ? url.deletingLastPathComponent().lastPathComponent : url.deletingPathExtension().lastPathComponent
        item.name = ProviderImportFiles.sanitized(item.name)
        do {
            let raw = try ProviderImportFiles.read(url)
            let text = ProviderImportFiles.sanitized(raw)
            var configuration = HarnessExtension()
            configuration.kind = kind == .skill ? .skill : .instructions
            configuration.name = item.name
            configuration.skillPath = url.path
            configuration.skillContent = text
            configuration.skillHash = Coding.hash(raw)
            configuration.summary = "\(kind.label) · \(scope)"
            configuration.importedKind = kind
            item.configuration = configuration
            item.fingerprint = Coding.hash(text)
            item.preview = String(text.prefix(8000))
            item.detail =
                kind == .rule
                ? "Regras incluídas no contexto das tarefas selecionadas."
                : "Instruções disponíveis sob demanda. Permissões e execução permanecem sob controle do Fronda."
        } catch {
            item.selectable = false
            item.detail = error.localizedDescription
        }
        result.items.append(item)
    }
}
