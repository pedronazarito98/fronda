import AppKit
import Foundation
import HarnessDomain
import HarnessIPC
import HarnessInfrastructure

@main
struct CLIMain {
    static func main() async {
        do {
            var args = Array(CommandLine.arguments.dropFirst())
            if args.first == "watch", try SessionCommands.handle(args, root: nil) { return }
            let json = args.contains("--json")
            args.removeAll { $0 == "--json" }
            var root: URL?
            if let i = args.firstIndex(of: "--root"), i + 1 < args.count {
                root = URL(fileURLWithPath: args[i + 1])
                args.removeSubrange(i...i + 1)
            }
            if try SessionCommands.handle(args, root: root) { return }
            let client = try CoordinatorClient(root: root)
            if args.first == "mcp" {
                try await MCPHost.serve(client: client, runID: args.last ?? "")
                return
            }
            guard let command = args.first, command != "help", command != "--help" else {
                print(usage)
                return
            }
            if ["extensions", "extension-call", "evidence"].contains(command) {
                try await ExtensionCommands.run(args, client: client)
                return
            }
            func argument(_ index: Int) throws -> String {
                guard args.indices.contains(index) else { throw HarnessError(usage) }
                return args[index]
            }
            var request = RPCRequest("snapshot")
            switch command {
            case "status", "projects", "runs", "runbooks": break
            case "project":
                if try argument(1) == "add" {
                    request = RPCRequest("project.add")
                    request.path = try argument(2)
                } else if try argument(1) == "index" {
                    request = RPCRequest("project.index")
                    request.id = try argument(2)
                } else {
                    throw HarnessError(usage)
                }
            case "create":
                func option(_ name: String) throws -> String? {
                    guard let index = args.firstIndex(of: name) else { return nil }
                    guard args.indices.contains(index + 1) else { throw HarnessError("Valor ausente para \(name)") }
                    let value = args[index + 1]
                    args.removeSubrange(index...index + 1)
                    return value
                }
                let bookName = try option("--runbook") ?? "Explorar código"
                let providerName = try option("--provider")
                let modeName = try option("--mode")
                let budget = try option("--budget")
                let scope = try option("--scope")
                var criteria = [String]()
                while let criterion = try option("--criterion") { criteria.append(criterion) }
                let projectID = try argument(1)
                let text = args.dropFirst(2).joined(separator: " ")
                let snapshot = try await client.send(RPCRequest("snapshot"))
                guard
                    let project = snapshot.snapshot?.projects.first(where: {
                        $0.id.hasPrefix(projectID) || $0.name == projectID
                    }),
                    let book = snapshot.snapshot?.runbooks.first(where: { $0.name == bookName || $0.id == bookName })
                else { throw HarnessError("Projeto ou runbook não encontrado.") }
                var run = Run()
                run.projectID = project.id
                run.title = text
                run.source.text = text
                run.runbook = book
                run.mode = book.mode
                run.provider = book.provider
                run.budget = book.budget
                if let providerName {
                    guard let provider = ProviderKind(rawValue: providerName) else {
                        throw HarnessError("Provider inválido.")
                    }
                    run.provider = provider
                }
                if let modeName {
                    guard let mode = AutonomyMode(rawValue: modeName) else { throw HarnessError("Modo inválido.") }
                    run.mode = mode
                }
                if let budget {
                    guard let limit = Int(budget), limit >= 1000, limit <= 500000 else {
                        throw HarnessError("Orçamento inválido.")
                    }
                    run.budget = limit
                }
                if let scope { run.scope = scope.split(separator: ",").map(String.init) }
                run.criteria = criteria.map { Criterion(text: $0) }
                request = RPCRequest("run.create")
                request.run = run
            case "start", "resume", "pause", "cancel", "archive", "reconcile":
                request = RPCRequest("run." + command)
                request.id = try argument(1)
            case "approve-plan":
                request = RPCRequest("run.approve")
                request.id = try argument(1)
                request.expectedSequence = Int(try argument(2))
            case "validate":
                request = RPCRequest("validation.run")
                request.id = try argument(1)
            case "retry":
                request = RPCRequest("step.retry")
                request.id = try argument(1)
                request.relatedID = try argument(2)
            case "fork":
                request = RPCRequest("run.fork")
                request.id = try argument(1)
                request.text = args.dropFirst(2).joined(separator: " ")
            case "budget":
                request = RPCRequest("run.budget")
                request.id = try argument(1)
                request.number = Int(try argument(2)) ?? 0
            case "export":
                request = RPCRequest("evidence.export")
                request.id = try argument(1)
            case "tokens":
                request = RPCRequest("tokens.export")
                request.id = try argument(1)
            case "events":
                request = RPCRequest("events")
                request.id = try argument(1)
            case "inspect":
                request = RPCRequest("run.get")
                request.id = try argument(1)
            case "search":
                request = RPCRequest("search")
                request.id = try argument(1)
                request.text = args.dropFirst(2).joined(separator: " ")
            case "steer":
                request = RPCRequest("run.steer")
                request.id = try argument(1)
                request.text = args.dropFirst(2).joined(separator: " ")
            case "probe": request = RPCRequest("providers.probe")
            case "diagnostics": request = RPCRequest("diagnostics")
            case "shutdown": request = RPCRequest("service.shutdown")
            case "open":
                let id = args.dropFirst().first ?? ""
                await MainActor.run { if let url = URL(string: "fronda://run/\(id)") { NSWorkspace.shared.open(url) } }
                return
            case "rpc":
                let data = FileHandle.standardInput.readDataToEndOfFile()
                request = try Coding.decode(RPCRequest.self, from: data)
            default: throw HarnessError(usage)
            }
            let response = try await client.send(request)
            if let error = response.error { throw HarnessError(error) }
            if json || command == "rpc" {
                print(try Coding.string(response))
                return
            }
            if let snapshot = response.snapshot {
                if command == "projects" {
                    for project in snapshot.projects {
                        print("\(project.id)  \(project.name)  \(project.indexState)  \(project.path)")
                    }
                } else if command == "runbooks" {
                    for book in snapshot.runbooks { print("\(book.id)  \(book.name)  v\(book.version)") }
                } else {
                    print(
                        "Fronda · \(snapshot.projects.count) projetos · \(snapshot.runs.count) runs · fila \(snapshot.preferences.queuePaused ? "pausada" : "ativa")"
                    )
                    for run in snapshot.runs { print("\(run.id)  \(run.state.rawValue)  \(run.title)") }
                    if command == "probe" {
                        for provider in snapshot.providers {
                            print(
                                "\(provider.kind.rawValue): \(provider.state) · \(provider.version) · \(provider.detail)"
                            )
                        }
                    }
                }
            }
            if let run = response.run { print(try Coding.string(run)) }
            if let events = response.events {
                for event in events { print("\(event.sequence)  \(event.kind)  \(event.message)") }
            }
            if let items = response.items {
                for item in items { print("\(item.path) · \(item.symbols.joined(separator: ", "))") }
            }
            if !response.id.isEmpty { print(response.id) }
            if !response.path.isEmpty { print(response.path) }
            if !response.text.isEmpty { print(response.text) }
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }
    static let usage = """
        Fronda CLI — mesmo coordenador e políticas do app
        fronda status | projects | runs | runbooks | probe | diagnostics
        fronda project add <pasta> | project index <id>
        fronda create <projeto-id-ou-nome> <objetivo>
          [--runbook <nome-ou-id>] [--provider Codex|"Claude Code"]
          [--mode Explorar|Planejar|Guiado|Auto|Confiável] [--scope <paths>]
          [--budget <tokens>] [--criterion <critério>] (repetível)
        fronda inspect <run-id> | events <run-id>
        fronda approve-plan <run-id> <sequência-revisada>
        fronda start|resume|pause|cancel|archive|reconcile|validate|export|tokens <run-id>
        fronda steer <run-id> <orientação>
        fronda retry <run-id> <step-id> | fork <run-id> [título] | budget <run-id> <tokens>
        fronda search <projeto-id> <consulta>
        fronda open [run-id]
        fronda extensions list|add <manifest.json>|skill <nome> <SKILL.md>|discover <id>
        fronda extension-call <run-id> <extension-id> <tool> < arguments.json
        fronda evidence list <run-id>
        fronda evidence show <run-id> <artifact-id>
        fronda evidence add <run-id> <file> --title <title> --revision <snapshot> --criteria <id,id> [--share]
        fronda rpc < request.json
        fronda watch codex|claude [argumentos do provider]
          Inicia uma sessão externa com acompanhamento no notch (hooks de metadados).
        fronda connect|disconnect codex
          Configura/remove apenas os hooks do Fronda. Autorize os novos hooks em /hooks.
        Opções: --json; --root <diretório de dados isolado>
        """
}
