import HarnessDomain
import SwiftUI

struct ChatRunDetail: Identifiable {
    enum Page: Hashable {
        case section(RunWorkspaceSection)
        case step(String)
        case action(RunActionSheet)
    }
    let runID: String
    let page: Page
    var sequence: Int? = nil
    var id: String { runID }
}

struct ChatRunDetailView: View {
    let store: AppStore
    let detail: ChatRunDetail
    @Environment(\.dismiss) private var dismiss

    private var showingAction: Bool {
        if case .action = detail.page { return true }
        return false
    }

    private func close() {
        if showingAction {
            dismiss()
            store.runDetail = nil
        } else {
            store.runDetail = nil
            store.graph = nil
        }
    }

    @ViewBuilder private var navigationButtons: some View {
        if !showingAction, let graph = store.graph, graph.runID == detail.runID, graph.sequence == detail.sequence {
            Button("Voltar ao grafo", systemImage: "chevron.left") { store.runDetail = nil }
                .labelStyle(.titleAndIcon)
        }
        Button {
            close()
        } label: {
            Image(systemName: "xmark")
        }.buttonStyle(.plain).help("Fechar painel").accessibilityLabel("Fechar painel")
    }

    private func move(_ page: ChatRunDetail.Page) {
        store.runDetail = ChatRunDetail(runID: detail.runID, page: page, sequence: detail.sequence)
    }

    var body: some View {
        if let historical = store.runDetail, let sequence = historical.sequence,
            case .step(let id) = historical.page,
            let run = store.snapshot.runs.first(where: { $0.id == detail.runID })
        {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text("Etapa deste envio").font(.system(size: 20, weight: .medium, design: .serif))
                    Spacer()
                    navigationButtons
                }.padding(.horizontal, 20).padding(.vertical, 17)
                Divider()
                ChatRunRevision(store: store, current: run, sequence: sequence) { snapshot in
                    if let step = RunJourneyModel(run: snapshot).steps.first(where: { $0.id == id }) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(step.title).font(.title2)
                                Text(step.state.label).font(.callout).foregroundStyle(.secondary)
                                RunJourneyOutputs(run: snapshot, step: step.step)
                            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }.id(ChatRunReference(runID: run.id, sequence: sequence))
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let run = store.snapshot.runs.first(where: { $0.id == detail.runID }) {
            // Keep the current destination while the panel remains open.
            let page = store.runDetail?.page ?? detail.page
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        Text(title(page)).font(.system(size: 20, weight: .medium, design: .serif))
                        Spacer()
                        navigationButtons
                    }
                    if case .section(let section) = page { decision(for: section, run: run) }
                }.padding(.horizontal, 20).padding(.vertical, 17)
                Divider()
                switch page {
                case .step(let id):
                    if let step = RunJourneyModel(run: run).steps.first(where: { $0.id == id }) {
                        RunJourneyDetail(
                            store: store, run: run, selected: step,
                            onOpen: { move(.section($0)) }, onSelectStep: { move(.step($0)) })
                    } else {
                        ContentUnavailableView(
                            "Etapa indisponível", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                case .section(let section): sectionContent(section, run: run)
                case .action(let sheet): sheet.content(store: store, run: run)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FrondaTheme.surface)
            .task(id: run.sequence) {
                if store.connected { await store.loadEvents(run.id) }
            }
        }
    }

    private func title(_ page: ChatRunDetail.Page) -> String {
        switch page {
        case .step: "Atividade da etapa"
        case .section(let section): section == .files ? "Arquivos e entregas" : section.rawValue
        case .action(.loopPolicy): "Plano do ciclo"
        case .action(.operations): "Operações"
        case .action: "Evidências"
        }
    }

    @ViewBuilder private func decision(for section: RunWorkspaceSection, run: Run) -> some View {
        let action = RunUserAction.next(for: run, project: store.snapshot.projects.first { $0.id == run.projectID })
        HStack {
            if section == action?.destination {
                if [.reviewContext, .reviewProposal].contains(action),
                    let pack = run.pack, !run.revision.isEmpty, pack.revision == run.revision
                {
                    Button(action == .reviewContext ? "Autorizar contexto" : "Aprovar implementação") {
                        store.perform("run.approve", id: run.id) { $0.expectedSequence = run.sequence }
                    }.buttonStyle(.borderedProminent)
                } else if action == .recover {
                    Button("Reconciliar arquivos") { store.perform("run.reconcile", id: run.id) }
                } else if action == .inspectBlocker && [.failed, .blocked].contains(run.state) {
                    Button("Tentar novamente") { store.perform("run.resume", id: run.id) }
                }
            }
        }.disabled(!store.connected || store.busy.contains(run.id))
    }

    @ViewBuilder private func sectionContent(_ section: RunWorkspaceSection, run: Run) -> some View {
        let selection = Binding(get: { section }, set: { self.move(.section($0)) })
        switch section {
        case .context: ContextView(store: store, run: run)
        case .changes: DiffView(store: store, run: run)
        case .files: RunFilesView(store: store, run: run, section: selection)
        case .plan, .proposal: RunPlanDetailsView(store: store, run: run)
        case .review: ReviewView(store: store, run: run)
        case .validation: ValidationView(store: store, run: run)
        case .checkup: RunCheckupView(store: store, run: run, section: selection)
        case .evidence: EvidenceView(store: store, run: run)
        case .scenarios: ScenarioEvidenceView(store: store, run: run)
        case .activity: ActivityView(store: store, run: run)
        case .tokens: TokensView(store: store, run: run)
        case .conversation, .overview: Button("Voltar à conversa") { close() }
        }
    }
}
