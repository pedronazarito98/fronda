import HarnessDomain
import SwiftUI

struct WorkspaceEnvironment: View {
    var store: AppStore
    @State private var expanded = false
    @State private var refreshing = false
    @State private var refreshError: String?

    private var availableCount: Int { store.snapshot.providers.filter { $0.state == "AVAILABLE" }.count }
    private var summary: String {
        if store.loading { return "Verificando seu ambiente…" }
        if !store.connected { return "Ambiente desconectado" }
        if availableCount == 0 { return "Nenhum executor disponível" }
        return "\(availableCount) \(availableCount == 1 ? "executor pronto" : "executores prontos") neste Mac"
    }

    var body: some View {
        VStack(spacing: 13) {
            Divider()
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(store.connected ? "Coordenador conectado" : "Aguardando conexão com o coordenador")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        SettingsLink { Label("Configurar", systemImage: "slider.horizontal.3") }
                            .buttonStyle(.plain).foregroundStyle(FrondaTheme.accent)
                        Button {
                            refreshing = true
                            refreshError = nil
                            Task {
                                do {
                                    _ = try await store.send(RPCRequest("providers.probe"))
                                    await store.refresh()
                                } catch {
                                    refreshError = error.localizedDescription
                                }
                                refreshing = false
                            }
                        } label: {
                            Label(refreshing ? "Atualizando…" : "Atualizar", systemImage: "arrow.clockwise")
                        }.buttonStyle(.plain).disabled(refreshing || store.loading)
                    }.font(.caption)
                    if let refreshError {
                        Label(refreshError, systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(FrondaTheme.danger)
                    }
                    ForEach(store.snapshot.providers) { provider in
                        ProviderEnvironmentRow(provider: provider)
                    }
                    if store.snapshot.providers.isEmpty {
                        Text(
                            store.loading
                                ? "Verificando os executores instalados…"
                                : "Nenhum executor informado pelo coordenador."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.top, 14).padding(.leading, 4)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "desktopcomputer").foregroundStyle(FrondaTheme.accent)
                        .accessibilityHidden(true)
                    Text(summary).font(.caption.weight(.medium))
                    Spacer()
                    Text(expanded ? "Ocultar detalhes" : "Ver ambiente")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ProviderEnvironmentRow: View {
    let provider: ProviderInfo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "terminal").foregroundStyle(.secondary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(provider.kind.rawValue).font(.system(size: 12, weight: .medium))
                if !provider.version.isEmpty {
                    Text(provider.version).font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
                if provider.state != "AVAILABLE", !provider.detail.isEmpty {
                    Text(provider.detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            StatusBadge(text: provider.state, compact: true)
        }
        .padding(12)
        .background(FrondaTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}
