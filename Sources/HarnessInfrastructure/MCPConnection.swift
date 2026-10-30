import Foundation
import HarnessDomain

/// One connection per extension/run keeps stateful browser and document tools usable across calls.
public actor MCPConnection {
    private let configuration: HarnessExtension
    private let process = RunningProcess()
    private var pending = [Int: CheckedContinuation<JSONValue, Error>]()
    private var reader: Task<Void, Never>?
    private var serial = 0
    private var sessionID: String?
    private var protocolVersion = "2025-06-18"
    private var started = false
    private let http: URLSession

    public init(configuration: HarnessExtension) {
        self.configuration = configuration
        let settings = URLSessionConfiguration.ephemeral
        settings.timeoutIntervalForRequest = Double(configuration.timeoutSeconds)
        settings.timeoutIntervalForResource = Double(configuration.timeoutSeconds)
        http = URLSession(configuration: settings, delegate: NoMCPRedirects(), delegateQueue: nil)
    }

    public func connect(cwd: String) async throws {
        guard !started else { return }
        if configuration.endpoint.isEmpty {
            guard let executable = ProcessRunner.resolve(configuration.executable) else {
                throw HarnessError("Executável MCP não encontrado.")
            }
            try process.start(
                executable: executable, arguments: configuration.arguments, cwd: cwd,
                timeout: 3600, interactive: true)
            reader = Task { [weak self, process] in
                for await line in process.lines {
                    guard line.utf8.count <= 16_000_000,
                        let data = line.data(using: .utf8),
                        let value = try? Coding.decode(JSONValue.self, from: data)
                    else { continue }
                    await self?.receive(value)
                }
                await self?.failPending("MCP desconectado; resultado de chamadas pendentes pode ser incerto.")
            }
        }
        let result = try await request(
            "initialize",
            .object([
                "protocolVersion": .string(protocolVersion), "capabilities": .object([:]),
                "clientInfo": .object(["name": .string("Fronda"), "version": .string("1.0.0")]),
            ]))
        guard ["2024-11-05", "2025-03-26", "2025-06-18"].contains(result["protocolVersion"].string) else {
            await close()
            throw HarnessError("Versão MCP não suportada pelo Fronda.")
        }
        protocolVersion = result["protocolVersion"].string
        try await notify("notifications/initialized")
        started = true
    }

    public func discover() async throws -> [ExtensionTool] {
        var tools = [ExtensionTool]()
        var cursor = ""
        var seen = Set<String>()
        repeat {
            let result = try await request(
                "tools/list", cursor.isEmpty ? .object([:]) : .object(["cursor": .string(cursor)]))
            for item in result["tools"].array {
                guard !item["name"].string.isEmpty, !tools.contains(where: { $0.name == item["name"].string }) else {
                    throw HarnessError("Catálogo MCP contém nomes inválidos ou duplicados.")
                }
                var tool = ExtensionTool()
                tool.name = item["name"].string
                tool.description = ContextFirewall.redact(String(item["description"].string.prefix(4000)))
                tool.inputSchema = item["inputSchema"]
                tools.append(tool)
            }
            cursor = result["nextCursor"].string
            guard tools.count <= 500, cursor.isEmpty || seen.insert(cursor).inserted else {
                throw HarnessError("Catálogo MCP excede o limite ou repete paginação.")
            }
        } while !cursor.isEmpty
        return tools
    }

    public func call(name: String, arguments: JSONValue) async throws -> JSONValue {
        try await request("tools/call", .object(["name": .string(name), "arguments": arguments]))
    }

    public func close() async {
        process.stop()
        reader?.cancel()
        failPending("Conexão MCP encerrada.")
        if let sessionID, let url = URL(string: configuration.endpoint) {
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.timeoutInterval = 3
            request.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id")
            if let reference = configuration.authorizationReference,
                let token = try? HarnessKeychain.token(reference: reference)
            {
                request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            }
            request.setValue(protocolVersion, forHTTPHeaderField: "MCP-Protocol-Version")
            _ = try? await http.data(for: request)
        }
        started = false
        http.invalidateAndCancel()
    }

    private func request(_ method: String, _ params: JSONValue) async throws -> JSONValue {
        try Task.checkCancellation()
        serial += 1
        let id = serial
        let value = JSONValue.object([
            "jsonrpc": .string("2.0"), "id": .number(Double(id)),
            "method": .string(method), "params": params,
        ])
        if !configuration.endpoint.isEmpty {
            return try await sendHTTP(value, id: id)
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[id] = continuation
                do { try process.send(Coding.string(value) + "\n") } catch {
                    pending.removeValue(forKey: id)?.resume(throwing: error)
                }
                Task { [weak self, configuration] in
                    try? await Task.sleep(for: .seconds(configuration.timeoutSeconds))
                    await self?.expire(id)
                }
            }
        } onCancel: { [weak self] in
            Task { await self?.expire(id) }
        }
    }

    private func notify(_ method: String) async throws {
        let value = JSONValue.object(["jsonrpc": .string("2.0"), "method": .string(method)])
        if configuration.endpoint.isEmpty {
            try process.send(Coding.string(value) + "\n")
        } else {
            _ = try await sendHTTP(value, id: nil)
        }
    }

    private func receive(_ value: JSONValue) {
        if !value["method"].string.isEmpty {
            // Sampling, elicitation and server-initiated execution are not granted by connecting a server.
            if let id = value.object["id"] {
                try? process.send(
                    Coding.string(
                        JSONValue.object([
                            "jsonrpc": .string("2.0"), "id": id,
                            "error": .object([
                                "code": .number(-32601), "message": .string("Client capability unavailable"),
                            ]),
                        ])) + "\n")
            }
            return
        }
        guard let id = value["id"].int, let continuation = pending.removeValue(forKey: id) else { return }
        do { continuation.resume(returning: try result(value)) } catch { continuation.resume(throwing: error) }
    }

    private func result(_ value: JSONValue) throws -> JSONValue {
        if value.object["error"] != nil {
            throw HarnessError("MCP: " + ContextFirewall.redact(value["error"]["message"].string))
        }
        guard let result = value.object["result"] else { throw HarnessError("Resposta MCP inválida.") }
        return result
    }

    private func expire(_ id: Int) {
        pending.removeValue(forKey: id)?.resume(
            throwing: HarnessError("MCP_TIMEOUT: resultado incerto; não repita uma escrita sem conferir o destino."))
    }
    private func failPending(_ message: String) {
        let waiting = pending.values
        pending.removeAll()
        for continuation in waiting { continuation.resume(throwing: HarnessError(message)) }
    }

    private func sendHTTP(_ value: JSONValue, id: Int?) async throws -> JSONValue {
        guard let url = URL(string: configuration.endpoint) else { throw HarnessError("Endpoint MCP inválido.") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try Coding.encode(value)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(protocolVersion, forHTTPHeaderField: "MCP-Protocol-Version")
        if let sessionID { request.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id") }
        if let reference = configuration.authorizationReference {
            request.setValue(
                "Bearer " + (try HarnessKeychain.token(reference: reference)), forHTTPHeaderField: "Authorization")
        }
        let (bytes, response) = try await http.bytes(for: request)
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
            throw HarnessError("MCP HTTP indisponível ou requer autenticação. Nenhuma chamada foi repetida.")
        }
        if let session = response.value(forHTTPHeaderField: "Mcp-Session-Id") { sessionID = session }
        guard let id else { return .null }
        if response.value(forHTTPHeaderField: "Content-Type")?.contains("text/event-stream") == true {
            var event = ""
            var received = 0
            var lineBytes = Data()
            for try await byte in bytes {
                received += 1
                guard received <= 16_000_000 else { throw HarnessError("Resposta MCP grande demais.") }
                if byte != 10 {
                    lineBytes.append(byte)
                    continue
                }
                let line = String(decoding: lineBytes, as: UTF8.self).trimmingCharacters(in: .newlines)
                lineBytes.removeAll(keepingCapacity: true)
                if line.isEmpty {
                    if let data = event.data(using: .utf8),
                        let message = try? Coding.decode(JSONValue.self, from: data), message["id"].int == id,
                        message["method"].string.isEmpty
                    {
                        return try result(message)
                    }
                    event = ""
                } else if line.hasPrefix("data:") {
                    let field = String(line.dropFirst(5))
                    event += (field.hasPrefix(" ") ? String(field.dropFirst()) : field) + "\n"
                }
            }
            throw HarnessError("Stream MCP encerrou sem resposta; resultado incerto.")
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 16_000_000 else { throw HarnessError("Resposta MCP grande demais.") }
            data.append(byte)
        }
        let message = try Coding.decode(JSONValue.self, from: data)
        guard message["id"].int == id else { throw HarnessError("Resposta MCP não corresponde à chamada.") }
        return try result(message)
    }
}

private final class NoMCPRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
