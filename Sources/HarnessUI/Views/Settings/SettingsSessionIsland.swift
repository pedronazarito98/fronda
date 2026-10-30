import SwiftUI

struct SettingsSessionIsland: View {
    @Bindable var island: SessionIslandController
    @State private var showSetup = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Suas sessões, por perto").font(.headline)
                    Text("Acompanhe o trabalho pelo topo da tela, mesmo em outro app.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Toggle("Mostrar ilha no topo da tela", isOn: $island.enabled)
                    .labelsHidden().toggleStyle(.switch)
                    .accessibilityIdentifier("settings.island-enabled")
            }
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "leaf.fill").foregroundStyle(FrondaTheme.sage)
                        Text("Fronda").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                        Circle().fill(island.enabled ? FrondaTheme.sage : .gray).frame(width: 5, height: 5)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(.black.opacity(0.9), in: Capsule())
                    Text(island.enabled ? "Ativa neste Mac" : "Desativada")
                        .font(.caption2).foregroundStyle(.secondary)
                }.frame(width: 165).padding(.vertical, 8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Central de sessões: " + (island.enabled ? "ativada" : "desativada"))
                VStack(alignment: .leading, spacing: 11) {
                    Toggle("Expandir ao passar o mouse", isOn: $island.expandOnHover)
                        .toggleStyle(.checkbox).disabled(!island.enabled)
                    HStack(spacing: 10) {
                        Button(island.enabled ? "Visualizar central" : "Ativar e visualizar") {
                            island.enabled = true
                            island.expand(focus: true)
                        }.accessibilityIdentifier("settings.preview-island")
                        Button("Conectar sessões…") { showSetup = true }
                            .buttonStyle(.link).accessibilityIdentifier("settings.connect-sessions")
                    }
                }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(.vertical, 8)
            .sheet(isPresented: $showSetup) { SettingsSessionConnectionSheet() }
    }
}

private struct SettingsSessionConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Conectar sessões").font(.system(size: 23, weight: .semibold))
                    Text("Traga o estado do seu executor para a central da Fronda.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain).accessibilityLabel("Fechar conexão de sessões")
            }.padding(24)
            Divider()
            ScrollView { ExternalSessionSetupView().padding(24) }
            Divider()
            HStack {
                Label("Somente estado, projeto e horário", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Concluir") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(20)
        }
        .frame(width: 630, height: 610)
        .background(FrondaTheme.canvas).tint(FrondaTheme.accent)
    }
}
