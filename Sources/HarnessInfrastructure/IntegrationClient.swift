import Foundation
import HarnessDomain
import Security

public enum HarnessKeychain {
    public static func save(_ secret: String, reference: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.harness.integrations",
            kSecAttrAccount as String: reference,
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(secret.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
            throw HarnessError("Não foi possível guardar a autorização no Keychain.")
        }
    }
    public static func token(reference: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.harness.integrations",
            kSecAttrAccount as String: reference, kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess, let data = value as? Data,
            let token = String(data: data, encoding: .utf8)
        else { throw HarnessError("AUTH_REQUIRED: reconecte a integração no Harness.") }
        return token
    }
}

public enum IntegrationClient {
    public static func request(account: IntegrationAccount, path: String, method: String = "GET", body: String? = nil)
        async throws -> (JSONValue, String)
    {
        guard let base = URL(string: account.endpoint), base.scheme == "https", base.user == nil, base.password == nil,
            base.host != nil,
            !path.contains(".."), !path.contains("://"),
            let url = URL(
                string: account.endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/"
                    + path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        else { throw HarnessError("Endpoint HTTPS inválido.") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Bearer " + (try await OAuthClient.accessToken(reference: account.keychainReference)),
            forHTTPHeaderField: "Authorization")
        request.httpBody = body.map { Data($0.utf8) }
        let session = URLSession(
            configuration: .ephemeral, delegate: RedirectGuard(host: base.host ?? ""), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard data.count < 8_000_000 else { throw HarnessError("Resposta excede o limite local de 8 MB.") }
        guard let http = response as? HTTPURLResponse else { throw HarnessError("Resposta HTTP inválida.") }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw HarnessError("AUTH_REQUIRED: conexão sem autorização para esta operação.")
        }
        if http.statusCode == 429 { throw HarnessError("RATE_LIMITED: aguarde o intervalo informado pelo serviço.") }
        guard (200..<300).contains(http.statusCode) else {
            throw HarnessError(
                "HTTP \(http.statusCode): \(ContextFirewall.redact(String(decoding: data.prefix(2000), as: UTF8.self)))"
            )
        }
        let value = data.isEmpty ? JSONValue.null : (try JSONDecoder().decode(JSONValue.self, from: data))
        return (value, http.value(forHTTPHeaderField: "ETag") ?? "")
    }

    public static func jiraAttachment(account: IntegrationAccount, id: String, expectedSize: Int) async throws -> Data {
        guard account.kind == "Jira", id.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil,
            (0...10_000_000).contains(expectedSize), let base = URL(string: account.endpoint),
            base.scheme == "https", base.user == nil, base.password == nil, let host = base.host,
            let url = URL(
                string: account.endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    + "/attachment/content/\(id)?redirect=false")
        else { throw HarnessError("Anexo Jira inválido ou maior que 10 MB.") }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue(
            "Bearer " + (try await OAuthClient.accessToken(reference: account.keychainReference)),
            forHTTPHeaderField: "Authorization")
        let session = URLSession(configuration: .ephemeral, delegate: RedirectGuard(host: host), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw HarnessError("Resposta HTTP inválida.") }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw HarnessError("AUTH_REQUIRED: sem acesso ao anexo Jira escolhido.")
        }
        guard http.statusCode == 200 else {
            throw HarnessError("Download Jira não concluído: HTTP \(http.statusCode).")
        }
        guard response.expectedContentLength <= 10_000_000 else { throw HarnessError("Anexo maior que 10 MB.") }
        var data = Data()
        data.reserveCapacity(expectedSize)
        for try await byte in bytes {
            guard data.count < 10_000_000 else { throw HarnessError("Anexo excedeu 10 MB durante o download.") }
            data.append(byte)
        }
        guard data.count == expectedSize else {
            throw HarnessError("O tamanho do anexo mudou. Leia a fonte novamente.")
        }
        return data
    }
}

private final class RedirectGuard: NSObject, URLSessionTaskDelegate, Sendable {
    let host: String
    init(host: String) { self.host = host }
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(request.url?.host == host && request.url?.scheme == "https" ? request : nil)
    }
}
