import Foundation
import HarnessDomain

public struct DeviceAuthorization: Sendable {
    public let deviceCode: String
    public let userCode: String
    public let verificationURL: URL
    public let interval: Int
    public let expiresAt: Date
}

public enum OAuthClient {
    public static func githubDevice(clientID: String, host: String = "github.com") async throws -> DeviceAuthorization {
        let value = try await post(url: "https://\(host)/login/device/code", fields: ["client_id": clientID])
        guard let url = URL(string: value["verification_uri"].string), url.scheme == "https", url.host == host,
            !value["device_code"].string.isEmpty
        else { throw HarnessError("O GitHub App precisa permitir Device Flow.") }
        return DeviceAuthorization(
            deviceCode: value["device_code"].string, userCode: value["user_code"].string, verificationURL: url,
            interval: max(5, value["interval"].int ?? 5),
            expiresAt: Date().addingTimeInterval(Double(value["expires_in"].int ?? 900)))
    }
    public static func githubToken(clientID: String, authorization: DeviceAuthorization, host: String = "github.com")
        async throws -> String
    {
        var interval = authorization.interval
        while Date() < authorization.expiresAt {
            try await Task.sleep(for: .seconds(interval))
            try Task.checkCancellation()
            let response = try await post(
                url: "https://\(host)/login/oauth/access_token",
                fields: [
                    "client_id": clientID, "device_code": authorization.deviceCode,
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                ])
            if !response["access_token"].string.isEmpty {
                return try credential(
                    response, clientID: clientID, clientSecret: "", endpoint: "https://\(host)/login/oauth/access_token"
                )
            }
            switch response["error"].string {
            case "authorization_pending": continue
            case "slow_down": interval += 5
            default: throw HarnessError("Autorização não concluída: \(response["error"].string).")
            }
        }
        throw HarnessError("O código expirou. Inicie uma nova conexão.")
    }
    public static func jiraToken(clientID: String, clientSecret: String, code: String, redirect: String) async throws
        -> String
    {
        let response = try await post(
            url: "https://auth.atlassian.com/oauth/token",
            fields: [
                "grant_type": "authorization_code", "client_id": clientID, "client_secret": clientSecret, "code": code,
                "redirect_uri": redirect,
            ])
        return try credential(
            response, clientID: clientID, clientSecret: clientSecret, endpoint: "https://auth.atlassian.com/oauth/token"
        )
    }
    public static func credential(_ response: JSONValue, clientID: String, clientSecret: String, endpoint: String)
        throws -> String
    {
        guard !response["access_token"].string.isEmpty else {
            throw HarnessError("OAuth não retornou autorização: \(response["error"].string).")
        }
        var value: [String: JSONValue] = [
            "access_token": response["access_token"], "refresh_token": response["refresh_token"],
            "client_id": .string(clientID), "client_secret": .string(clientSecret), "token_endpoint": .string(endpoint),
        ]
        if let seconds = response["expires_in"].int {
            value["expires_at"] = .number(Date().timeIntervalSince1970 + Double(seconds))
        }
        return try Coding.string(JSONValue.object(value))
    }
    public static func accessToken(reference: String) async throws -> String {
        let stored = try HarnessKeychain.token(reference: reference)
        guard let credential = try? JSONDecoder().decode(JSONValue.self, from: Data(stored.utf8)),
            !credential["access_token"].string.isEmpty
        else { return stored }
        guard let expiry = credential["expires_at"].double, expiry < Date().timeIntervalSince1970 + 60 else {
            return credential["access_token"].string
        }
        guard !credential["refresh_token"].string.isEmpty else {
            throw HarnessError("AUTH_REQUIRED: autorização expirada. Reconecte a conta.")
        }
        let endpoint = credential["token_endpoint"].string
        guard let url = URL(string: endpoint), url.scheme == "https", url.user == nil, url.password == nil else {
            throw HarnessError("Endpoint OAuth inválido.")
        }
        let response = try await post(
            url: endpoint,
            fields: [
                "grant_type": "refresh_token", "refresh_token": credential["refresh_token"].string,
                "client_id": credential["client_id"].string, "client_secret": credential["client_secret"].string,
            ])
        var refreshed = response.object
        if refreshed["refresh_token"] == nil { refreshed["refresh_token"] = credential["refresh_token"] }
        let encoded = try self.credential(
            .object(refreshed), clientID: credential["client_id"].string,
            clientSecret: credential["client_secret"].string, endpoint: endpoint)
        try HarnessKeychain.save(encoded, reference: reference)
        return response["access_token"].string
    }
    private static func post(url: String, fields: [String: String]) async throws -> JSONValue {
        guard let endpoint = URL(string: url), endpoint.scheme == "https", let host = endpoint.host else {
            throw HarnessError("Endpoint OAuth inválido.")
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: fields)
        let session = URLSession(
            configuration: .ephemeral, delegate: OAuthRedirectGuard(host: host), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count < 1_000_000
        else { throw HarnessError("OAuth recusado ou temporariamente indisponível. Confira a configuração do App.") }
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}

private final class OAuthRedirectGuard: NSObject, URLSessionTaskDelegate, Sendable {
    let host: String
    init(host: String) { self.host = host }
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(request.url?.host == host && request.url?.scheme == "https" ? request : nil)
    }
}
