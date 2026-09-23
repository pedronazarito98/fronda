import AppKit
import HarnessDomain
import HarnessInfrastructure
import SwiftUI

struct IntegrationSettingsView: View {
    var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var account = IntegrationAccount()
    @State private var method = "OAuth"
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var token = ""
    @State private var deviceCode = ""
    @State private var error: String?
    @State private var saving = false
    @State private var operation: Task<Void, Never>?
    @State private var browser = OAuthBrowserSession()
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Conectar integração").font(.title2.weight(.semibold))
            Form {
                Picker("Serviço", selection: $account.kind) {
                    Text("GitHub").tag("GitHub")
                    Text("Jira").tag("Jira")
                }
                TextField("Nome da conexão", text: $account.name)
                TextField("Endpoint HTTPS da API", text: $account.endpoint)
                Picker("Autorização", selection: $method) {
                    Text("OAuth no navegador").tag("OAuth")
                    Text("Token autorizado").tag("Token")
                }
                if method == "OAuth" {
                    TextField(
                        account.kind == "GitHub" ? "Client ID do GitHub App" : "Client ID do App Atlassian",
                        text: $clientID)
                    if account.kind == "Jira" {
                        SecureField("Client secret do seu App", text: $clientSecret)
                        Text("Callback registrado: \(OAuthBrowserSession.redirect)").font(.caption.monospaced())
                            .textSelection(.enabled)
                        Text("Informe o Cloud ID no endpoint. A conta e os escopos serão confirmados no navegador.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(
                            "O GitHub App deve ter Device Flow habilitado e acesso apenas aos repositórios necessários."
                        ).font(.caption).foregroundStyle(.secondary)
                    }
                    if !deviceCode.isEmpty {
                        LabeledContent("Código para autorizar", value: deviceCode).font(.title3.monospaced())
                            .textSelection(.enabled)
                    }
                } else {
                    SecureField("Token de acesso autorizado", text: $token)
                }
                Text("Autorizações e refresh tokens ficam somente no Keychain deste Mac.").font(.caption)
                    .foregroundStyle(.secondary)
            }.disabled(saving)
            if let error { Text(error).foregroundStyle(.red).font(.caption) }
            HStack {
                Button("Cancelar") {
                    operation?.cancel()
                    dismiss()
                }
                Spacer()
                Button(
                    saving
                        ? "Aguardando autorização…"
                        : method == "OAuth" ? "Autorizar no navegador" : "Verificar e conectar"
                ) { connect() }.disabled(
                    account.name.isEmpty || saving || (method == "OAuth" ? clientID.isEmpty : token.isEmpty)
                ).buttonStyle(.borderedProminent)
            }
        }.padding(28).frame(width: 690)
            .onChange(of: account.kind) { _, kind in
                account.endpoint =
                    kind == "GitHub"
                    ? "https://api.github.com" : "https://api.atlassian.com/ex/jira/SEU-CLOUD-ID/rest/api/3"
            }
            .onDisappear {
                operation?.cancel()
                token = ""
                clientSecret = ""
            }
    }
    private func connect() {
        saving = true
        error = nil
        operation = Task {
            do {
                let authorization: String
                if method == "Token" {
                    authorization = token
                } else if account.kind == "GitHub" {
                    guard let endpoint = URL(string: account.endpoint), endpoint.scheme == "https",
                        let apiHost = endpoint.host
                    else { throw HarnessError("Endpoint inválido.") }
                    let host = apiHost == "api.github.com" ? "github.com" : apiHost
                    let device = try await OAuthClient.githubDevice(clientID: clientID, host: host)
                    deviceCode = device.userCode
                    NSWorkspace.shared.open(device.verificationURL)
                    authorization = try await OAuthClient.githubToken(
                        clientID: clientID, authorization: device, host: host)
                } else {
                    guard !clientSecret.isEmpty else {
                        throw HarnessError("Informe o segredo do App Atlassian configurado para este Mac.")
                    }
                    let code = try await browser.authorize(clientID: clientID)
                    authorization = try await OAuthClient.jiraToken(
                        clientID: clientID, clientSecret: clientSecret, code: code,
                        redirect: OAuthBrowserSession.redirect)
                }
                var request = RPCRequest("integration.save")
                var prefs = AppPreferences()
                prefs.integrationAccounts = [account]
                request.preferences = prefs
                request.text = authorization
                _ = try await store.send(request)
                token = ""
                clientSecret = ""
                await store.refresh()
                dismiss()
            } catch { self.error = error.localizedDescription }
            saving = false
        }
    }
}
