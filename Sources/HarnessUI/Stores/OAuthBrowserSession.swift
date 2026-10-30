import AppKit
import HarnessDomain
import Network

@MainActor
final class OAuthBrowserSession {
    static let redirect = "http://127.0.0.1:8765/oauth/callback"
    private var listener: NWListener?
    private var reply: CheckedContinuation<String, Error>?
    private var expectedState = ""

    func authorize(clientID: String) async throws -> String {
        expectedState = UUID().uuidString + UUID().uuidString
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: 8765)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        var components = URLComponents(string: "https://auth.atlassian.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "audience", value: "api.atlassian.com"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "scope", value: "read:jira-work read:jira-user write:jira-work offline_access"),
            URLQueryItem(name: "redirect_uri", value: Self.redirect), URLQueryItem(name: "state", value: expectedState),
            URLQueryItem(name: "response_type", value: "code"), URLQueryItem(name: "prompt", value: "consent"),
        ]
        guard let authorizationURL = components.url else { throw HarnessError("Configuração OAuth inválida.") }
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { data, _, _, _ in
                Task { @MainActor in self?.receive(data, connection: connection) }
            }
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                reply = continuation
                listener.stateUpdateHandler = { [weak self] state in
                    Task { @MainActor in
                        if case .ready = state { NSWorkspace.shared.open(authorizationURL) }
                        if case .failed = state {
                            self?.finish(.failure(HarnessError("Callback local indisponível na porta 8765.")))
                        }
                    }
                }
                listener.start(queue: .main)
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(300))
                    self?.finish(.failure(HarnessError("Autorização expirou.")))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(.failure(CancellationError())) }
        }
    }
    private func receive(_ data: Data?, connection: NWConnection) {
        guard let data, let request = String(data: data, encoding: .utf8),
            let target = request.components(separatedBy: " ").dropFirst().first,
            let url = URLComponents(string: "http://127.0.0.1:8765" + target), url.path == "/oauth/callback"
        else {
            connection.cancel()
            return
        }
        let query = Dictionary(
            (url.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
        guard query["state"] == expectedState, let code = query["code"], !code.isEmpty else {
            connection.cancel()
            return
        }
        let body = "Autorização recebida. Você pode voltar ao Fronda."
        let response =
            "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
        finish(.success(code))
    }
    private func finish(_ result: Result<String, Error>) {
        let continuation = reply
        reply = nil
        listener?.cancel()
        listener = nil
        continuation?.resume(with: result)
    }
}
