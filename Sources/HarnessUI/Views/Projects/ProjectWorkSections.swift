import HarnessDomain
import SwiftUI

struct ProjectValidationList: View {
    let project: Project
    let reviewCommands: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Comandos do projeto").font(.system(size: 16, weight: .semibold))
                    Text(
                        "As tarefas usam estes comandos para conferir as alterações. A aprovação autoriza seu uso; os resultados ficam em cada tarefa."
                    )
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button("Revisar comandos…", action: reviewCommands)
                    .accessibilityIdentifier("project.review-commands")
            }
            if project.validators.isEmpty {
                ProjectEmptyState(
                    symbol: "checkmark.shield", title: "Defina como conferir o trabalho",
                    detail:
                        "Cadastre os comandos de build, lint ou teste deste repositório. Você revisa cada comando antes de autorizar seu uso."
                ) { EmptyView() }
            } else {
                Surface(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(project.validators) { validator in
                            validatorRow(validator)
                            if validator.id != project.validators.last?.id { Divider().padding(.horizontal, 16) }
                        }
                    }
                }
            }
        }
    }

    private func validatorRow(_ validator: Validator) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: validator.approved ? "checkmark.shield" : "shield.lefthalf.filled")
                .foregroundStyle(validator.approved ? FrondaTheme.success : FrondaTheme.warning)
                .frame(width: 20).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(validator.name.isEmpty ? "Comando sem nome" : validator.name).font(.callout.weight(.medium))
                    Spacer(minLength: 12)
                    Text(validator.approved ? "Aprovado" : "Revisão necessária")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(validator.approved ? FrondaTheme.success : FrondaTheme.warning)
                }
                Text(validator.displayCommand).font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary).textSelection(.enabled).lineLimit(3)
                HStack(spacing: 12) {
                    Text(validator.required ? "Obrigatório" : "Opcional")
                    if validator.readOnly { Text("Somente leitura") }
                    Text("Limite: \(validator.timeoutSeconds)s")
                }.font(.caption2).foregroundStyle(.secondary)
            }
        }.padding(16)
    }
}

struct ProjectTaskList: View {
    var store: AppStore
    let runs: [Run]
    let createTask: () -> Void
    @State private var filter = ProjectTaskFilter.all

    private var filteredRuns: [Run] {
        runs.filter(filter.includes).sorted(by: RunDisplay.attentionOrder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Trabalho neste projeto").font(.system(size: 16, weight: .semibold))
                    Text("Abra uma tarefa para acompanhar as etapas e agir no contexto.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !runs.isEmpty {
                    Picker("Filtrar tarefas do projeto", selection: $filter) {
                        ForEach(ProjectTaskFilter.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.menu).fixedSize().accessibilityIdentifier("project.tasks.filter")
                }
            }
            if runs.isEmpty {
                ProjectEmptyState(
                    symbol: "play.rectangle", title: "O projeto está pronto para receber uma tarefa",
                    detail: "Defina um objetivo, escolha um fluxo e revise o contexto antes de executar."
                ) {
                    Button("Preparar primeira tarefa", action: createTask).buttonStyle(.borderedProminent)
                }
            } else if filteredRuns.isEmpty {
                ProjectEmptyState(
                    symbol: "line.3.horizontal.decrease.circle", title: "Nenhuma tarefa neste filtro",
                    detail: "As outras tarefas continuam disponíveis no histórico do projeto."
                ) {
                    Button("Ver todas") { filter = .all }
                }
            } else {
                Text("\(filteredRuns.count) de \(runs.count) \(runs.count == 1 ? "tarefa" : "tarefas")")
                    .font(.caption).foregroundStyle(.secondary)
                Surface(padding: 0) {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredRuns) { run in
                            taskRow(run)
                            if run.id != filteredRuns.last?.id { Divider().padding(.horizontal, 16) }
                        }
                    }
                }
            }
        }
    }

    private func taskRow(_ run: Run) -> some View {
        Button {
            store.route = "run:" + run.id
        } label: {
            HStack(spacing: 13) {
                Image(systemName: RunDisplay.symbol(for: run.state))
                    .foregroundStyle(RunDisplay.color(for: run.state)).frame(width: 20).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(run.title).font(.callout.weight(.medium)).lineLimit(2)
                    Text("\(run.runbook.name) · \(run.stageLabel)").font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(run.state.label).font(.caption.weight(.medium)).foregroundStyle(
                        RunDisplay.color(for: run.state))
                    Text(RunDisplay.nextAction(for: run)).font(.caption).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityElement(children: .ignore).accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(run.title), \(run.state.label)").accessibilityHint(RunDisplay.nextAction(for: run))
        .accessibilityIdentifier("project.task." + run.id)
        .help("Atualizada \(run.updatedAt.formatted(date: .abbreviated, time: .shortened))")
    }
}

private enum ProjectTaskFilter: String, CaseIterable, Identifiable {
    case all = "Todas"
    case attention = "Pedem atenção"
    case running = "Em execução"
    case archived = "Arquivadas"

    var id: String { rawValue }

    func includes(_ run: Run) -> Bool {
        switch self {
        case .all: true
        case .attention: RunDisplay.needsAttention(run)
        case .running: run.state.active
        case .archived: run.state == .archived
        }
    }
}
