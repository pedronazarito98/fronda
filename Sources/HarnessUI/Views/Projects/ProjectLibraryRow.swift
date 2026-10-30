import HarnessDomain
import SwiftUI

struct ProjectLibraryRow: View {
    let project: Project
    let runs: [Run]
    let open: () -> Void
    @State private var hovered = false

    private var approved: Int { project.validators.filter(\.approved).count }
    private var attentionCount: Int { runs.filter(RunDisplay.needsAttention).count }
    private var taskCountLabel: String { "\(runs.count) \(runs.count == 1 ? "tarefa" : "tarefas")" }
    private var attentionLabel: String {
        attentionCount == 1 ? "1 tarefa pede atenção" : "\(attentionCount) tarefas pedem atenção"
    }

    var body: some View {
        Button(action: open) {
            Surface(padding: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "folder").font(.system(size: 19, weight: .medium))
                        .foregroundStyle(FrondaTheme.accent).frame(width: 38, height: 38)
                        .background(FrondaTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 11) {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                                Text(project.path).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 5)
                            ProjectIndexBadge(state: project.indexState)
                        }
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 16) {
                                repositoryContext
                                counts
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                repositoryContext
                                counts
                            }
                        }
                    }
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                        .padding(.top, 12).accessibilityHidden(true)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: FrondaTheme.cornerRadius)
                    .strokeBorder(hovered ? FrondaTheme.accent.opacity(0.35) : .clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: FrondaTheme.cornerRadius))
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            "\(project.name), \(ProjectIndexStatus(rawValue: project.indexState).label), \(taskCountLabel)"
        )
        .accessibilityHint("Abrir contexto, validações e tarefas do projeto")
        .accessibilityIdentifier("projects.open." + project.id)
    }

    private var repositoryContext: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.branch").accessibilityHidden(true)
            Text(project.branch.isEmpty ? "Branch não informada" : project.branch).lineLimit(1)
            if project.dirty {
                Text("· Alterações locais").foregroundStyle(FrondaTheme.warning)
            }
        }.font(.caption).foregroundStyle(.secondary)
    }

    private var counts: some View {
        HStack(spacing: 14) {
            Text("\(project.indexedFiles.formatted()) \(project.indexedFiles == 1 ? "arquivo" : "arquivos")")
            Text(
                "\(approved)/\(project.validators.count) \(project.validators.count == 1 ? "comando aprovado" : "comandos aprovados")"
            )
            Text(attentionCount > 0 ? attentionLabel : taskCountLabel)
                .foregroundStyle(attentionCount > 0 ? FrondaTheme.warning : FrondaTheme.textMuted)
        }.font(.caption).foregroundStyle(.secondary)
    }
}
