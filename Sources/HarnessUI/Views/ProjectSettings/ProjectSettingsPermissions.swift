import HarnessDomain
import SwiftUI

struct ProjectSettingsPermissions: View {
    @Binding var draft: ProjectSettingsDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Surface {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Executores permitidos").font(.system(size: 14, weight: .semibold))
                    ForEach(ProviderKind.allCases) { provider in
                        Toggle(provider.rawValue, isOn: providerEnabled(provider)).toggleStyle(.switch)
                    }
                    Divider()
                    Toggle(isOn: $draft.requireStrongIsolation) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Exigir isolamento forte").font(.callout.weight(.medium))
                            Text(
                                "A tarefa fica bloqueada se o executor não comprovar isolamento. Suas permissões nativas continuam valendo."
                            )
                            .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .accessibilityLabel("Exigir isolamento forte")
                    .accessibilityHint("Bloqueia a tarefa se o executor não comprovar isolamento.")
                }
            }
            Surface {
                VStack(alignment: .leading, spacing: 18) {
                    ProjectSettingsPathsField(
                        title: "Caminhos permitidos",
                        hint: "Um caminho por linha. Use ** para permitir todo o projeto.",
                        placeholder: "**", text: $draft.allowedPaths)
                    Divider()
                    ProjectSettingsPathsField(
                        title: "Arquivos protegidos", hint: "Esses caminhos ficam fora do alcance das alterações.",
                        placeholder: "config/producao.json", text: $draft.lockedPaths)
                }
            }
            Label(
                "Mudanças de política podem exigir nova validação e revisão das tarefas existentes.",
                systemImage: "info.circle"
            )
            .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func providerEnabled(_ provider: ProviderKind) -> Binding<Bool> {
        Binding(
            get: { !draft.disabledProviders.contains(provider) },
            set: { enabled in
                var updated = draft
                if enabled {
                    updated.disabledProviders.remove(provider)
                } else {
                    updated.disabledProviders.insert(provider)
                }
                draft = updated
            })
    }
}

struct ProjectSettingsPathsField: View {
    let title: String
    let hint: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 12, weight: .semibold))
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.system(size: 12, design: .monospaced)).lineLimit(2...5)
                .textFieldStyle(.roundedBorder).accessibilityLabel(title)
            Text(hint).font(.caption).foregroundStyle(.secondary)
        }
    }
}
