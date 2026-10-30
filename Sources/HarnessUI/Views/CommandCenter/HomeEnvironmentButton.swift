import SwiftUI

struct HomeEnvironmentButton: View {
    let store: AppStore
    @State private var showing = false
    private var ready: Int { store.snapshot.providers.filter { $0.state == "AVAILABLE" }.count }

    var body: some View {
        Button {
            showing.toggle()
        } label: {
            Label(title, systemImage: store.connected ? "desktopcomputer" : "wifi.exclamationmark")
                .font(.caption).foregroundStyle(store.connected ? FrondaTheme.accent : FrondaTheme.warning)
        }
        .buttonStyle(.plain).accessibilityIdentifier("home.environment")
        .popover(isPresented: $showing) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Seu ambiente").font(.headline)
                Label(
                    store.connected ? "Coordenador conectado" : "Coordenador desconectado",
                    systemImage: store.connected ? "checkmark.circle" : "wifi.slash"
                )
                .font(.callout)
                ForEach(store.snapshot.providers) { provider in
                    HStack {
                        Text(provider.kind.rawValue)
                        Spacer()
                        Label(
                            provider.state == "AVAILABLE" ? "Pronto" : "Verificar",
                            systemImage: provider.state == "AVAILABLE" ? "checkmark.circle" : "exclamationmark.circle"
                        )
                        .foregroundStyle(provider.state == "AVAILABLE" ? FrondaTheme.success : FrondaTheme.warning)
                    }.font(.caption)
                }
                Divider()
                HStack {
                    SettingsLink { Text("Configurar…") }
                    Spacer()
                    Button("Atualizar") { store.perform("providers.probe") }
                        .disabled(!store.connected || store.busy.contains("providers.probe"))
                }
                Text("Histórico e evidências permanecem neste Mac.").font(.caption).foregroundStyle(.secondary)
            }.padding(20).frame(width: 320)
        }
    }

    private var title: String {
        if store.loading { return "Conectando…" }
        if !store.connected { return "Sem conexão" }
        return ready > 0 ? "Ambiente pronto" : "Configurar ambiente"
    }
}
