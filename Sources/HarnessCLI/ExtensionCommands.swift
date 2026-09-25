import Foundation
import HarnessDomain
import HarnessIPC
import HarnessInfrastructure

enum ExtensionCommands {
    static func run(_ args: [String], client: CoordinatorClient) async throws {
        func arg(_ index: Int) throws -> String {
            guard args.indices.contains(index) else {
                throw HarnessError("Argumentos insuficientes. Consulte harness help.")
            }
            return args[index]
        }
        var request = RPCRequest("snapshot")
        switch args[0] {
        case "extensions":
            switch args.dropFirst().first ?? "list" {
            case "list":
                let response = try await client.send(request)
                if let error = response.error { throw HarnessError(error) }
                print(try Coding.string(response.snapshot?.preferences.extensions ?? []))
                return
            case "add":
                let file = URL(fileURLWithPath: try arg(2))
                let data = try Data(contentsOf: file)
                guard data.count <= 256_000 else { throw HarnessError("Manifesto JSON excede 256 KB.") }
                let supplied = try Coding.decode(JSONValue.self, from: data)
                guard case .object = supplied else { throw HarnessError("Manifesto precisa ser um objeto JSON.") }
                let defaults = try Coding.decode(JSONValue.self, from: Coding.encode(HarnessExtension())).object
                var merged = defaults.merging(supplied.object) { _, supplied in supplied }
                if let suppliedTools = supplied.object["tools"] {
                    let defaults = try Coding.decode(JSONValue.self, from: Coding.encode(ExtensionTool())).object
                    merged["tools"] = .array(
                        suppliedTools.array.map { .object(defaults.merging($0.object) { _, supplied in supplied }) })
                }
                request = RPCRequest("extension.save")
                request.extensionConfiguration = try Coding.decode(
                    HarnessExtension.self, from: Coding.encode(JSONValue.object(merged)))
            case "skill":
                var item = HarnessExtension()
                item.name = try arg(2)
                item.skillPath = try arg(3)
                item.kind = .skill
                request = RPCRequest("extension.save")
                request.extensionConfiguration = item
            case "discover":
                request = RPCRequest("extension.discover")
                request.id = try arg(2)
            default:
                throw HarnessError("Use extensions list|add <manifest.json>|skill <nome> <SKILL.md>|discover <id>.")
            }
        case "extension-call":
            request = RPCRequest("extension.call")
            request.id = try arg(1)
            request.payload = .object([
                "extensionID": .string(try arg(2)), "tool": .string(try arg(3)),
                "arguments": try Coding.decode(JSONValue.self, from: FileHandle.standardInput.readDataToEndOfFile()),
            ])
        case "evidence":
            let operation = try arg(1)
            let runID = try arg(2)
            if operation == "list" {
                request = RPCRequest("run.get")
                request.id = runID
                let response = try await client.send(request)
                if let error = response.error { throw HarnessError(error) }
                print(try Coding.string(response.run?.evidenceArtifacts ?? []))
                return
            }
            if operation == "show" {
                request = RPCRequest("evidence.file")
                request.id = runID
                request.relatedID = try arg(3)
            } else if operation == "add" {
                let path = try arg(3)
                func option(_ name: String) throws -> String {
                    guard let index = args.firstIndex(of: name), args.indices.contains(index + 1) else {
                        throw HarnessError("Informe \(name).")
                    }
                    return args[index + 1]
                }
                request = RPCRequest("evidence.register")
                request.id = runID
                request.payload = .object([
                    "path": .string(URL(fileURLWithPath: path).standardizedFileURL.path),
                    "title": .string(try option("--title")),
                    "revision": .string(try option("--revision")),
                    "criterionIDs": .array(try option("--criteria").split(separator: ",").map { .string(String($0)) }),
                    "providerReadable": .bool(args.contains("--share")),
                ])
            } else {
                throw HarnessError("Use evidence list|show|add.")
            }
        default: throw HarnessError("Comando de extensão desconhecido.")
        }
        let response = try await client.send(request)
        if let error = response.error { throw HarnessError(error) }
        print(try Coding.string(response))
    }
}
