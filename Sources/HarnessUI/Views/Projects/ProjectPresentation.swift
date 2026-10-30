import HarnessDomain
import SwiftUI

enum ProjectLibraryFilter: String, CaseIterable, Identifiable {
    case all = "Todos"
    case indexPending = "Índice pendente"
    case withTasks = "Com tarefas"

    var id: String { rawValue }

    func includes(_ project: Project, runs: [Run]) -> Bool {
        switch self {
        case .all: true
        case .indexPending: project.indexState != "READY"
        case .withTasks: runs.contains { $0.projectID == project.id }
        }
    }
}

struct ProjectIndexStatus {
    let rawValue: String

    var label: String {
        switch rawValue {
        case "READY": "Índice disponível"
        case "INDEXING": "Indexando"
        case "STALE": "Índice desatualizado"
        case "DEGRADED": "Índice parcial"
        case "ERROR": "Falha no índice"
        case "NOT_INDEXED": "Ainda não indexado"
        default: "Estado do índice indisponível"
        }
    }

    var symbol: String {
        switch rawValue {
        case "READY": "checkmark.circle"
        case "INDEXING": "circle.dotted"
        case "ERROR": "exclamationmark.circle"
        case "STALE", "DEGRADED": "arrow.triangle.2.circlepath"
        default: "circle.dashed"
        }
    }

    var color: Color {
        switch rawValue {
        case "READY": FrondaTheme.success
        case "INDEXING": FrondaTheme.accent
        case "STALE", "DEGRADED": FrondaTheme.warning
        case "ERROR": FrondaTheme.danger
        default: FrondaTheme.textMuted
        }
    }

    var explanation: String {
        switch rawValue {
        case "READY": "Busque no código que já está indexado neste Mac."
        case "INDEXING": "O Fronda está atualizando o contexto deste repositório."
        case "STALE": "Atualize o índice para consultar o contexto mais recente."
        case "DEGRADED": "Parte do repositório foi indexada. Consulte os detalhes antes de atualizar."
        case "ERROR": "A indexação não foi concluída. Consulte os detalhes e tente novamente."
        case "NOT_INDEXED": "Crie o índice para encontrar arquivos e símbolos deste projeto."
        default: "Consulte os detalhes ou atualize o índice deste projeto."
        }
    }
}

struct ProjectIndexBadge: View {
    let state: String
    private var status: ProjectIndexStatus { ProjectIndexStatus(rawValue: state) }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.symbol).accessibilityHidden(true)
            Text(status.label)
        }
        .font(.system(size: 11, weight: .medium)).foregroundStyle(status.color)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(status.color.opacity(0.08), in: Capsule())
        .accessibilityElement(children: .ignore).accessibilityLabel(status.label)
    }
}

struct ProjectEmptyState<Actions: View>: View {
    let symbol: String
    let title: String
    let detail: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 27, weight: .light))
                .foregroundStyle(FrondaTheme.accent).accessibilityHidden(true)
            Text(title).font(.system(size: 17, weight: .semibold))
            Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 530, alignment: .leading)
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 24)
    }
}
