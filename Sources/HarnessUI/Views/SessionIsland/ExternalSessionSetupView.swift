import AppKit
import HarnessInfrastructure
import SwiftUI

struct ExternalSessionSetupView: View {
    @State private var provider = "Codex"
    @State private var result = ""
    @State private var failed = false
    @State private var showManual = false
    @State private var copied = false

    private var helper: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/fronda").path
    }
    private var command: String {
        "'" + helper.replacingOccurrences(of: "'", with: "'\\''") + "' watch "
            + (provider == "Codex" ? "codex" : "claude")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                providerChoice("Codex", subtitle: "Integração por hooks")
                providerChoice("Claude Code", subtitle: "Iniciar pelo terminal")
            }
            if provider == "Codex" {
                instruction(1, "Prepare a integração", detail: "Adicione os hooks da Fronda à configuração do Codex.") {
                    Button("Configurar integração") { configureCodex(enabled: true) }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("settings.configure-codex-hooks")
                }
                instruction(
                    2, "Autorize no Codex",
                    detail: "Abra /hooks no Codex, confira os hooks da Fronda e autorize a integração."
                ) {
                    Text("A autorização acontece no próprio Codex.").font(.caption).foregroundStyle(.secondary)
                }
                instruction(
                    3, "Retome sua sessão",
                    detail: "Sessões já abertas precisam ser retomadas para aparecer na central."
                ) { EmptyView() }
                if !result.isEmpty {
                    Label(result, systemImage: failed ? "exclamationmark.circle" : "checkmark.circle")
                        .font(.callout).foregroundStyle(failed ? FrondaTheme.danger : FrondaTheme.success)
                        .textSelection(.enabled)
                }
                DisclosureGroup("Configuração manual e remoção", isExpanded: $showManual) {
                    VStack(alignment: .leading, spacing: 13) {
                        commandBlock
                        Button("Remover hooks da Fronda", role: .destructive) { configureCodex(enabled: false) }
                    }.padding(.top, 12)
                }.font(.caption)
            } else {
                instruction(
                    1, "Abra o terminal do projeto", detail: "Entre na pasta do repositório que você quer acompanhar."
                ) { EmptyView() }
                instruction(2, "Inicie pela Fronda", detail: "Copie e execute o comando abaixo no terminal do projeto.")
                { commandBlock }
                instruction(
                    3, "Acompanhe pela central", detail: "A sessão aparecerá na ilha quando informar sua atividade."
                ) { EmptyView() }
            }
            Text("Conversas e credenciais permanecem no executor. Aprovações e controles da sessão continuam nele.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: provider) { _, _ in
            result = ""
            copied = false
            showManual = false
        }
    }

    private func providerChoice(_ name: String, subtitle: String) -> some View {
        Button {
            provider = name
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(name).font(.callout.weight(.semibold))
                    Spacer()
                    Image(systemName: provider == name ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(FrondaTheme.accent)
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    provider == name ? FrondaTheme.accent.opacity(0.08) : FrondaTheme.surface,
                    in: RoundedRectangle(cornerRadius: 13)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13).strokeBorder(
                        provider == name ? FrondaTheme.accent : FrondaTheme.border, lineWidth: 1)
                }
        }.buttonStyle(.plain).accessibilityLabel(name)
            .accessibilityAddTraits(provider == name ? .isSelected : [])
    }

    private func instruction<Content: View>(
        _ number: Int, _ title: String, detail: String, @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(number.formatted()).font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(FrondaTheme.accent).frame(width: 26, height: 26)
                .background(FrondaTheme.accent.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 9) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                content()
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var commandBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(command).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                NSPasteboard.general.clearContents()
                copied = NSPasteboard.general.setString(command, forType: .string)
            } label: {
                Label(copied ? "Copiado" : "Copiar comando", systemImage: copied ? "checkmark" : "doc.on.doc")
            }.font(.caption)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(FrondaTheme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func configureCodex(enabled: Bool) {
        do {
            try CodexIslandHooks.configure(executable: helper, root: nil, enabled: enabled)
            failed = false
            result =
                enabled
                ? "Integração preparada. Agora autorize em /hooks e retome a sessão no Codex."
                : "Hooks da Fronda removidos."
        } catch {
            failed = true
            result = "Não foi possível alterar os hooks. Abra a configuração manual para usar o comando no terminal."
        }
    }
}
