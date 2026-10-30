import HarnessDomain
import SwiftUI

struct ProjectSettingsAccess: View {
    let project: Project
    let renewing: Bool
    let canRenew: Bool
    let renew: () -> Void
    let reveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Surface {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image(systemName: "folder.fill").font(.system(size: 30, weight: .light))
                            .foregroundStyle(FrondaTheme.accent)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(project.name).font(.headline)
                            Text(project.path).font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary).textSelection(.enabled)
                        }
                        Spacer(minLength: 0)
                    }
                    Divider()
                    HStack(spacing: 18) {
                        Label(
                            project.branch.isEmpty ? "Sem branch informada" : project.branch,
                            systemImage: "arrow.triangle.branch")
                        Label(
                            "\(project.indexedFiles.formatted()) arquivos no índice",
                            systemImage: "doc.text.magnifyingglass")
                    }.font(.caption).foregroundStyle(.secondary)
                    Button("Mostrar no Finder", systemImage: "folder", action: reveal)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Renovar acesso à pasta").font(.system(size: 14, weight: .semibold))
                Text(
                    "Selecione a pasta do repositório para atualizar sua autorização no macOS. As opções editadas neste painel continuam no rascunho."
                )
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(renewing ? "Renovando acesso…" : "Selecionar pasta e renovar acesso…", action: renew)
                    .disabled(!canRenew).accessibilityIdentifier("project.settings.renew-access")
                Text("A renovação é aplicada assim que você confirma a pasta.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 2)
        }
    }
}
