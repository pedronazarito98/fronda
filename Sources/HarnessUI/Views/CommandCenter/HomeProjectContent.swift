import HarnessDomain
import SwiftUI

struct HomeProjectContent: View {
    let store: AppStore
    let size: HomeCardSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.snapshot.projects.isEmpty {
                Spacer(minLength: 0)
                Image(systemName: "folder.badge.plus").font(.largeTitle.weight(.light)).foregroundStyle(
                    FrondaTheme.accent)
                Text("Seu trabalho começa com um projeto").font(.callout.weight(.medium))
                Text("Escolha um repositório deste Mac para preparar sua primeira tarefa.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button("Escolher repositório…", action: store.addProject)
                    .disabled(!store.connected || store.busy.contains("project.add"))
                    .accessibilityIdentifier("home.add-project")
            } else {
                ForEach(Array(store.snapshot.projects.prefix(size.rowLimit))) { project in
                    Button {
                        store.route = "project:" + project.id
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder").foregroundStyle(FrondaTheme.accent)
                                .frame(width: 34, height: 34)
                                .background(FrondaTheme.accent.opacity(0.08), in: .rect(cornerRadius: 9))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name).font(.callout.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                                Text(project.branch.isEmpty ? "Abrir projeto" : project.branch)
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("home.project." + project.id)
                }
                Spacer(minLength: 0)
                Button("Ver projetos", systemImage: "arrow.right") { store.route = "projects" }
                    .buttonStyle(.plain).font(.caption.weight(.medium)).foregroundStyle(FrondaTheme.accent)
            }
        }
    }
}
