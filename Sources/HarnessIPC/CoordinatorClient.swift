import Foundation
import HarnessDomain
import HarnessInfrastructure

public actor CoordinatorClient {
    private let paths: StoragePaths
    private var connection: NSXPCConnection?
    public init(root: URL? = nil) throws { paths = try StoragePaths(root: root) }
    public func send(_ request: RPCRequest) async throws -> RPCResponse {
        do { return try await exchange(request) } catch {
            connection?.invalidate()
            connection = nil
            try await launchService()
            for _ in 0..<30 {
                try await Task.sleep(for: .milliseconds(200))
                if let result = try? await exchange(request) { return result }
                connection?.invalidate()
                connection = nil
            }
            throw HarnessError(
                "Não foi possível conectar ao coordenador local. Reabra o Fronda ou execute o build novamente. \(error.localizedDescription)"
            )
        }
    }
    private func exchange(_ request: RPCRequest) async throws -> RPCResponse {
        if connection == nil {
            let client = NSXPCConnection(machServiceName: paths.serviceName, options: [])
            client.remoteObjectInterface = NSXPCInterface(with: CoordinatorProtocol.self)
            client.resume()
            connection = client
        }
        guard let connection else { throw HarnessError("Coordenador indisponível.") }
        let data = try Coding.encode(request)
        let response: Data = try await withCheckedThrowingContinuation { continuation in
            let reply = ReplyOnce(continuation)
            guard
                let proxy = connection.remoteObjectProxyWithErrorHandler({ error in reply.finish(.failure(error)) })
                    as? CoordinatorProtocol
            else {
                reply.finish(.failure(HarnessError("Interface XPC indisponível.")))
                return
            }
            proxy.handle(data) { output in reply.finish(.success(output)) }
            DispatchQueue.global().asyncAfter(deadline: .now() + 120) {
                reply.finish(
                    .failure(
                        HarnessError(
                            "Tempo limite do coordenador. A operação pode continuar; consulte a run antes de repetir."))
                )
            }
        }
        return try Coding.decode(RPCResponse.self, from: response)
    }
    private func launchService() async throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
            .deletingLastPathComponent()
        let binary =
            directory.lastPathComponent == "Helpers"
            ? directory.deletingLastPathComponent().appendingPathComponent("MacOS/HarnessService")
            : directory.appendingPathComponent("HarnessService")
        guard FileManager.default.isExecutableFile(atPath: binary.path) else {
            throw HarnessError("HarnessService não encontrado ao lado do app/CLI.")
        }
        let configuration: [String: Any] = [
            "Label": paths.serviceName, "ProgramArguments": [binary.path, "--root", paths.root.path],
            "MachServices": [paths.serviceName: true], "RunAtLoad": false, "ProcessType": "Background",
        ]
        let file = paths.root.appendingPathComponent("coordinator.plist")
        let data = try PropertyListSerialization.data(fromPropertyList: configuration, format: .xml, options: 0)
        try paths.atomicWrite(data, to: file)
        _ = try await ProcessRunner.run(
            "/bin/launchctl", ["bootstrap", "gui/\(getuid())", file.path], cwd: paths.root.path, timeout: 15)
    }
}

private final class ReplyOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, Error>?
    init(_ continuation: CheckedContinuation<Data, Error>) { self.continuation = continuation }
    func finish(_ result: Result<Data, Error>) {
        let value = lock.withLock {
            let value = continuation
            continuation = nil
            return value
        }
        value?.resume(with: result)
    }
}
