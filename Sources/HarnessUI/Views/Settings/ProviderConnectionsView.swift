import HarnessDomain
import SwiftUI

struct ProviderConnectionsView: View {
    let store: AppStore
    @State private var paths = [String: String]()
    @State private var importing: ProviderKind?
    @State private var connecting: ProviderKind?
    @State private var error: String?

    var body: some View {
        Group {
            Section {
                Label("Seu contexto, desde o primeiro dia", systemImage: "leaf")
                    .font(.title3.weight(.semibold)).foregroundStyle(FrondaTheme.accent)
                Text(
                    "Conecte a instalação deste Mac. Depois escolha as skills, regras e ferramentas que quer trazer para o Fronda."
                )
                .foregroundStyle(.secondary)
            }
            ForEach(ProviderKind.allCases) { kind in
                let provider = store.snapshot.providers.first { $0.kind == kind }
                Section(kind.rawValue) {
                    HStack {
                        Label(kind == .codex ? "Codex App Server" : "Claude Code", systemImage: "terminal")
                            .font(.headline)
                        Spacer()
                        StatusBadge(text: provider?.state ?? "UNAVAILABLE")
                    }
                    Text(provider?.detail ?? "Verifique a instalação local para começar.")
                        .font(.callout).foregroundStyle(.secondary)
                    TextField(
                        "Executável",
                        text: Binding(
                            get: {
                                paths[kind.rawValue] ?? store.snapshot.preferences.providers[kind.rawValue] ?? provider?
                                    .path ?? ""
                            },
                            set: { paths[kind.rawValue] = $0 })
                    )
                    .textFieldStyle(.roundedBorder)
                    if provider?.state == "AUTH_REQUIRED" {
                        Text(kind == .codex ? "No Terminal: codex login" : "No Terminal: claude auth login")
                            .font(.caption.monospaced()).textSelection(.enabled)
                    }
                    HStack {
                        Button(connecting == kind ? "Verificando…" : "Conectar e escolher contexto") { connect(kind) }
                            .buttonStyle(.borderedProminent).disabled(connecting != nil || !store.connected)
                            .accessibilityIdentifier("provider.connect." + kind.rawValue)
                        Button("Revisar importação…") { importing = kind }.disabled(!store.connected)
                        Button("Consultar modelos") { store.perform("provider.models") { $0.text = kind.rawValue } }
                            .disabled(provider?.path.isEmpty != false || store.busy.contains("provider.models"))
                    }
                    if let detail = provider?.modelDiscoveryDetail {
                        Text(detail).font(.caption).foregroundStyle(.secondary)
                    }
                    if let models = provider?.models, !models.isEmpty {
                        Text(models.map(\.name).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Text(
                    "A autenticação permanece nos CLIs oficiais. A importação só acontece após você revisar e confirmar a seleção."
                )
                .font(.caption).foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(FrondaTheme.danger) }
            }
        }.sheet(item: $importing) { ProviderImportView(store: store, provider: $0) }
    }

    private func connect(_ kind: ProviderKind) {
        connecting = kind
        error = nil
        Task {
            do {
                var preferences = store.snapshot.preferences
                if let path = paths[kind.rawValue] {
                    let cleaned = path.trimmingCharacters(in: .whitespacesAndNewlines)
                    preferences.providers[kind.rawValue] = cleaned.isEmpty ? nil : cleaned
                }
                var request = RPCRequest("preferences.save")
                request.preferences = preferences
                _ = try await store.send(request)
                _ = try await store.send(RPCRequest("providers.probe"))
                await store.refresh()
                importing = kind
            } catch { self.error = error.localizedDescription }
            connecting = nil
        }
    }
}
