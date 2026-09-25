import HarnessDomain
import SwiftUI

struct RunWorkspace: View {
    var store: AppStore
    let runID: String
    @State private var tab = "Visão geral"
    @State private var steering = ""
    @State private var confirmingCancel = false
    @State private var inspector = true
    @Environment(\.openWindow) private var openWindow
    private let detailTabs = [
        "Visão geral", "Plano", "Alterações", "Validação", "Revisão", "Contexto", "Atividade", "Tokens", "Evidências",
    ]
    private var tabs: [String] {
        run?.workflow == nil ? detailTabs : ["Visão geral", "Alterações", "Evidências", "Atividade"]
    }
    private var run: Run? { store.snapshot.runs.first { $0.id == runID } }
    var body: some View {
        if let run {
            VStack(spacing: 0) {
                header(run)
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(tabs, id: \.self) { name in
                            Button {
                                tab = name
                            } label: {
                                Text(name).font(.system(size: 11, weight: tab == name ? .semibold : .regular)).padding(
                                    .horizontal, 12
                                ).padding(.vertical, 9).background(
                                    tab == name ? HarnessTheme.accent.opacity(0.12) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 7)
                                ).foregroundStyle(tab == name ? HarnessTheme.accent : .secondary)
                            }.buttonStyle(.plain).accessibilityIdentifier("run.tab." + name)
                        }
                    }.padding(.horizontal, 22).padding(.vertical, 10)
                }
                Divider()
                HSplitView {
                    Group {
                        switch tab {
                        case "Plano": RunPlanView(store: store, run: run)
                        case "Alterações": DiffView(store: store, run: run)
                        case "Validação": ValidationView(store: store, run: run)
                        case "Revisão": ReviewView(store: store, run: run)
                        case "Contexto": ContextView(store: store, run: run)
                        case "Atividade": ActivityView(store: store, run: run)
                        case "Tokens": TokensView(store: store, run: run)
                        case "Evidências": EvidenceView(store: store, run: run)
                        default:
                            if run.workflow != nil { WorkflowOverview(store: store, run: run) } else { overview(run) }
                        }
                    }.frame(minWidth: 570, maxWidth: .infinity, maxHeight: .infinity)
                    if inspector {
                        RunInspector(store: store, run: run).frame(minWidth: 220, idealWidth: 235, maxWidth: 290)
                    }
                }
                Divider()
                HStack(spacing: 10) {
                    Image(systemName: "text.bubble").foregroundStyle(.secondary)
                    TextField("Orientar esta run…", text: $steering).textFieldStyle(.plain).onSubmit { sendSteering() }
                    Button("Enviar orientação") { sendSteering() }.disabled(
                        steering.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding(16)
            }.tint(HarnessTheme.accent)
                .confirmationDialog("Cancelar esta run?", isPresented: $confirmingCancel) {
                    Button("Cancelar run", role: .destructive) { store.perform("run.cancel", id: run.id) }
                } message: {
                    Text("A execução será interrompida. Worktree, arquivos e histórico serão preservados.")
                }
        } else {
            EmptyPanel(
                symbol: "play.rectangle", title: "Selecione uma run",
                detail: "A execução aparecerá aqui assim que o coordenador confirmar sua criação.")
        }
    }
    private func header(_ run: Run) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(
                    "\(store.snapshot.projects.first { $0.id == run.projectID }?.name ?? "Projeto")  /  \(run.id.prefix(8))"
                ).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Button {
                    openWindow(id: "run", value: run.id)
                } label: {
                    Image(systemName: "macwindow.badge.plus")
                }.help("Abrir em outra janela").accessibilityIdentifier("run.open-window")
                Button {
                    inspector.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                }.help("Mostrar Inspector")
            }.buttonStyle(.plain)
            HStack(alignment: .top) {
                Text(run.title).font(.system(size: 23, weight: .semibold)).lineLimit(2).accessibilityIdentifier(
                    "run.title")
                Spacer()
                StatusBadge(text: run.state.rawValue).accessibilityIdentifier("run.state")
            }
            HStack(spacing: 12) {
                Label(run.provider.rawValue, systemImage: "terminal")
                Text(run.mode.rawValue)
                Text(run.stageLabel)
                Spacer()
                if run.state.active {
                    Button("Pausar") { store.perform("run.pause", id: run.id) }
                } else if run.state == .waitingUser && !run.contextApproved {
                    Button("Revisar contexto") { tab = "Contexto" }.accessibilityIdentifier(
                        run.workflow == nil ? "run.context" : "run.tab.Contexto")
                    Button(run.workflow == nil ? "Aprovar plano e envio" : "Autorizar investigação") {
                        store.perform("run.approve", id: run.id) { $0.expectedSequence = run.sequence }
                    }.buttonStyle(.borderedProminent).accessibilityIdentifier("run.approve")
                } else if run.workflow != nil && !run.planApproved && !(run.workflow?.proposal.isEmpty ?? true) {
                    Button("Revisar plano") { tab = "Plano" }
                    Button("Aprovar implementação") {
                        store.perform("run.approve", id: run.id) { $0.expectedSequence = run.sequence }
                    }.buttonStyle(.borderedProminent)
                } else if run.state != .archived {
                    Button(run.contextApproved ? "Retomar etapas" : "Preparar contexto") {
                        store.perform("run.resume", id: run.id)
                    }
                }
                Menu {
                    ForEach(["Plano", "Validação", "Revisão", "Contexto", "Tokens"], id: \.self) { name in
                        Button(name) { tab = name }
                    }
                    Divider()
                    Button("Bifurcar abordagem") { store.perform("run.fork", id: run.id) }
                    Button("Reconciliar arquivos") { store.perform("run.reconcile", id: run.id) }
                    Button("Exportar evidências") { store.perform("evidence.export", id: run.id) }
                    Button("Arquivar") { store.perform("run.archive", id: run.id) }
                    Divider()
                    Button("Cancelar run", role: .destructive) { confirmingCancel = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }.font(.caption).foregroundStyle(.secondary)
        }.padding(24)
    }
    private func overview(_ run: Run) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Surface {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: run.state == .ready ? "checkmark.seal" : "info.circle").foregroundStyle(
                            HarnessTheme.accent)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(run.state.label).font(.headline)
                            Text(run.reason).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                }
                SectionHeading(title: "Etapas da execução", detail: "PROGRESSO OBSERVADO")
                VStack(spacing: 0) {
                    ForEach(Array(run.plan.enumerated()), id: \.element.id) { index, step in
                        HStack(spacing: 13) {
                            Text(String(format: "%02d", index + 1)).font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary).frame(width: 25)
                            Text(step.title).font(.system(size: 13))
                            Spacer()
                            StatusBadge(text: step.status.rawValue, compact: true)
                        }.padding(.vertical, 12)
                        if index < run.plan.count - 1 { Divider() }
                    }
                }
                SectionHeading(title: "Critérios de aceite")
                ForEach(run.criteria) { criterion in
                    Surface(padding: 14) {
                        HStack(alignment: .top) {
                            Image(systemName: criterion.state == "SATISFIED" ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(criterion.state == "SATISFIED" ? .green : .secondary)
                            MarkdownView(criterion.text)
                            Spacer()
                            Text(criterion.state).font(.system(size: 9, design: .monospaced)).foregroundStyle(
                                .secondary)
                        }
                    }
                }
                if !run.report.isEmpty {
                    SectionHeading(title: "Resultado do executor")
                    MarkdownView(run.report)
                }
                DisclosureGroup("Fonte original e contexto adicional") {
                    MarkdownView(run.source.text).padding(.top, 10)
                }
            }.padding(24)
        }
    }
    private func sendSteering() {
        let text = steering
        steering = ""
        store.perform("run.steer", id: runID) { $0.text = text }
    }
}

struct RunInspector: View {
    var store: AppStore
    let run: Run
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                Text("INSPECTOR").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.4)
                    .foregroundStyle(.secondary)
                item("Projeto", store.snapshot.projects.first { $0.id == run.projectID }?.name ?? "")
                item("Runbook", "\(run.runbook.name) · v\(run.runbook.version)")
                item("Branch", run.branch.isEmpty ? "Preparação pendente" : run.branch)
                item("Base Git", String(run.baseSHA.prefix(12)))
                item("Snapshot", String(run.revision.prefix(16)))
                Divider()
                VStack(alignment: .leading, spacing: 9) {
                    Text("Orçamento de tokens").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(run.reportedTokens.formatted()).font(.title3.monospacedDigit())
                        Text("/ \(run.budget.formatted())").font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressView(
                        value: min(Double(run.reportedTokens), Double(run.budget)), total: Double(max(1, run.budget))
                    ).tint(run.reportedTokens > run.budget * 8 / 10 ? .orange : HarnessTheme.accent)
                    Text("Consumo informado pelo provider").font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                item("Escopo", run.scope.joined(separator: "\n"))
                item("Tentativas", "\(run.attempts.count)")
                Divider()
                Button {
                    store.reveal(run.workspace)
                } label: {
                    Label("Abrir worktree", systemImage: "folder")
                }.disabled(run.workspace.isEmpty)
                Menu("Trocar provider") {
                    ForEach(ProviderKind.allCases) { provider in
                        Button(provider.rawValue) {
                            store.perform("run.provider", id: run.id) { $0.text = provider.rawValue }
                        }
                    }
                }.disabled(run.state.active)
                Text("Trocar o executor cria uma nova tentativa e exige revisão do contexto.").font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }.padding(20)
        }
    }
    private func item(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 11)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }
}
