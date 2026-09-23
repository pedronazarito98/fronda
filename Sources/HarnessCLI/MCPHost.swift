import Foundation
import HarnessDomain
import HarnessIPC
import HarnessInfrastructure

enum MCPHost {
    static func serve(client: CoordinatorClient, runID: String) async throws {
        while let line = readLine() {
            guard let data = line.data(using: .utf8),
                let message = try? JSONDecoder().decode(JSONValue.self, from: data), let id = message.object["id"]
            else { continue }
            let result: JSONValue
            switch message["method"].string {
            case "initialize":
                result = .object([
                    "protocolVersion": .string("2024-11-05"), "capabilities": .object(["tools": .object([:])]),
                    "serverInfo": .object(["name": .string("Harness"), "version": .string("1.0.0")]),
                ])
            case "tools/list":
                let names = [
                    ("harness_read_file", ["path"]), ("harness_search", ["query"]),
                    ("harness_write_file", ["path", "content", "expectedHash"]), ("harness_validate", ["validatorID"]),
                ]
                result = .object([
                    "tools": .array(
                        names.map { name, fields in
                            .object([
                                "name": .string(name), "description": .string("Policy-mediated Harness operation"),
                                "inputSchema": .object([
                                    "type": .string("object"),
                                    "properties": .object(
                                        Dictionary(
                                            uniqueKeysWithValues: fields.map {
                                                ($0, JSONValue.object(["type": .string("string")]))
                                            })), "required": .array(fields.map(JSONValue.string)),
                                ]),
                            ])
                        })
                ])
            case "tools/call":
                let params = message["params"]
                let args = params["arguments"]
                var request = RPCRequest("tool.call")
                request.id = runID
                request.text = params["name"].string
                request.path = args["path"].string.isEmpty ? args["query"].string : args["path"].string
                request.relatedID = args["validatorID"].string
                request.arguments = [args["content"].string, args["expectedHash"].string]
                let response = try await client.send(request)
                result = .object([
                    "content": .array([
                        .object(["type": .string("text"), "text": .string(response.error ?? response.text)])
                    ]), "isError": .bool(response.error != nil || response.text.hasPrefix("ERROR")),
                ])
            default: result = .object([:])
            }
            print(try Coding.string(JSONValue.object(["jsonrpc": .string("2.0"), "id": id, "result": result])))
            fflush(stdout)
        }
    }
}
