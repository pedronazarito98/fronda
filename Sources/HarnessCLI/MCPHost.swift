import Foundation
import HarnessDomain
import HarnessIPC
import HarnessInfrastructure

enum MCPHost {
    static func serve(client: CoordinatorClient, runID: String) async throws {
        while let line = readLine() {
            guard line.utf8.count < 2_000_000, let data = line.data(using: .utf8),
                let message = try? Coding.decode(JSONValue.self, from: data), let id = message.object["id"]
            else { continue }
            var reply = ["jsonrpc": JSONValue.string("2.0"), "id": id]
            do {
                let result: JSONValue
                switch message["method"].string {
                case "initialize":
                    let requested = message["params"]["protocolVersion"].string
                    result = .object([
                        "protocolVersion": .string(
                            ["2024-11-05", "2025-03-26", "2025-06-18"].contains(requested) ? requested : "2025-06-18"),
                        "capabilities": .object(["tools": .object([:])]),
                        "serverInfo": .object(["name": .string("Fronda"), "version": .string("1.0.0")]),
                    ])
                case "ping": result = .object([:])
                case "tools/list":
                    result = .object([
                        "tools": .array(
                            HarnessTools.definitions.map {
                                var definition = $0.object
                                definition.removeValue(forKey: "type")
                                return .object(definition)
                            })
                    ])
                case "tools/call":
                    let params = message["params"]
                    var request = RPCRequest("tool.call")
                    request.id = runID
                    request.text = params["name"].string
                    request.payload = params["arguments"]
                    let response = try await client.send(request)
                    if response.error == nil,
                        ["harness_evidence_read", "harness_extension_call"].contains(request.text),
                        let structured = try? Coding.decode(JSONValue.self, from: Data(response.text.utf8)),
                        structured.object["content"] != nil
                    {
                        result = structured
                    } else {
                        result = .object([
                            "content": .array([
                                .object(["type": .string("text"), "text": .string(response.error ?? response.text)])
                            ]),
                            "isError": .bool(response.error != nil || response.text.hasPrefix("ERROR")),
                        ])
                    }
                default: throw HarnessError("Método MCP não suportado.")
                }
                reply["result"] = result
            } catch {
                reply["error"] = .object([
                    "code": .number(-32603), "message": .string(ContextFirewall.redact(error.localizedDescription)),
                ])
            }
            print(try Coding.string(JSONValue.object(reply)))
            fflush(stdout)
        }
    }
}
