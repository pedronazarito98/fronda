import HarnessDomain
import SwiftUI

struct ChatGraphInspector: View {
    let store: AppStore
    let run: Run
    let snapshotSequence: Int?
    @State private var selectedStep: String?
    @State private var selectedLoop: String?
    @State private var stepToSkip: String?
    @State private var skipRevision = 0
    @State private var skipReason = ""
    @State private var skipError: String?
    @State private var savingSkip = false

    private var loops: [RunFlowMapLoop] {
        let loop = RunFollowupLoopProjection(run: run)
        guard let policy = loop.policy else { return [] }
        return [
            RunFlowMapLoop(
                id: policy.id, title: policy.title,
                stepIDs: [policy.implementationStepID, policy.validationStepID],
                summary: loop.summary ?? "Até \(policy.maxIterations) ciclos",
                returnLabel: "Repetir se a verificação falhar", didRepeat: loop.didRepeat)
        ]
    }

    private var currentStatus: some View {
        let followup = RunFollowupModel(run: run, isConnected: store.connected)
        let step = followup.currentStep
        let selected = followup.journey.steps.first { $0.id == selectedStep }
        let next = RunUserAction.next(
            for: run, project: store.snapshot.projects.first { $0.id == run.projectID })
        return VStack(alignment: .leading, spacing: 10) {
            if let selected, selectedLoop == nil {
                let node = RunFlowMapNodeModel(
                    journey: selected, run: run, project: store.snapshot.projects.first { $0.id == run.projectID },
                    connected: store.connected, showsCurrent: snapshotSequence == nil)
                Text("Etapa \(selected.number) de \(followup.journey.totalCount) · \(node.status)")
                    .font(.caption.weight(.semibold)).foregroundStyle(node.appearance.color)
                    .accessibilityIdentifier(node.isCurrent ? "graph.current-step" : "graph.selected-step")
                Text(selected.title)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                Text(selected.detail)
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Ver atividade e resultados", systemImage: "list.bullet") {
                    store.runDetail = ChatRunDetail(runID: run.id, page: .step(selected.id), sequence: snapshotSequence)
                }
                .buttonStyle(.link).font(.caption)
                .accessibilityIdentifier("graph.step.details")
            } else {
                Text(snapshotSequence == nil ? followup.currentSummary(for: next) : "Estado deste envio")
                    .font(.callout.weight(.semibold))
                Text(followup.journey.progressSummary).font(.caption).foregroundStyle(.secondary)
            }
            if snapshotSequence == nil {
                if let selected, let step, selected.id != step.id {
                    Text("Controles da execução · etapa atual: " + step.title)
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("graph.current-step")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 8) { interventions(step: step) }
                    VStack(alignment: .leading, spacing: 8) { interventions(step: step) }
                }
                if let stepID = stepToSkip,
                    let step = followup.journey.steps.first(where: { $0.id == stepID })
                {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pular \(step.title)").font(.callout.weight(.semibold))
                        Text("A etapa ficará registrada como pulada. Pendências continuam visíveis.")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("Por que deseja pular?", text: $skipReason, axis: .vertical)
                            .textFieldStyle(.roundedBorder).lineLimit(2...4)
                        if let skipError {
                            Text(skipError).font(.caption).foregroundStyle(FrondaTheme.danger)
                        }
                        HStack {
                            Button("Voltar") { stepToSkip = nil }
                            Button(savingSkip ? "Salvando…" : "Confirmar etapa pulada") { skip(step) }
                                .buttonStyle(.borderedProminent)
                                .disabled(
                                    savingSkip || skipReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }.controlSize(.small)
                    }.padding(12)
                        .background(FrondaTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.vertical, 16)
        .background(FrondaTheme.surface)
    }

    @ViewBuilder private func interventions(step: RunJourneyStep?) -> some View {
        RunInterventionControls(store: store, run: run)
        if let step, canSkip(step) {
            Button("Pular etapa") {
                skipReason = ""
                skipError = nil
                stepToSkip = step.id
                skipRevision = run.sequence
            }.controlSize(.small).disabled(!store.connected || store.busy.contains(run.id))
        }
    }

    private func canSkip(_ step: RunJourneyStep) -> Bool {
        run.pauseAllowsContinuation && [.paused, .waitingUser, .blocked, .failed, .partial].contains(run.state)
            && run.workflow?.delivery.closedAt == nil && ![.pass, .skipped].contains(step.step.status)
    }

    private func skip(_ step: RunJourneyStep) {
        guard canSkip(step), !savingSkip, step.id == stepToSkip else { return }
        var request = RPCRequest("step.skip")
        request.id = run.id
        request.relatedID = step.id
        request.expectedSequence = skipRevision
        request.text = skipReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.text.isEmpty else { return }
        savingSkip = true
        skipError = nil
        Task {
            defer { savingSkip = false }
            do {
                _ = try await store.send(request)
                await store.refresh()
                stepToSkip = nil
            } catch { skipError = error.localizedDescription }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Trilha da tarefa")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    Text(run.title).font(.caption).foregroundStyle(FrondaTheme.textMuted).lineLimit(2)
                }
                Spacer()
                Button {
                    store.graph = nil
                } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(FrondaTheme.canvas, in: Circle())
                }
                .buttonStyle(.plain).accessibilityLabel("Fechar grafo")
            }.padding(.horizontal, 20).padding(.vertical, 17)
            Divider()
            RunFlowMap(
                run: run, selectedStepID: $selectedStep,
                project: store.snapshot.projects.first { $0.id == run.projectID }, loops: loops,
                selectedLoopID: selectedLoop,
                isConnected: store.connected, showsCurrent: snapshotSequence == nil,
                onInspectStep: { _ in
                    selectedLoop = nil
                }, onSelectLoop: { id in selectedLoop = selectedLoop == id ? nil : id })
            Divider()
            ScrollView { currentStatus }
                .frame(maxHeight: stepToSkip == nil ? 200 : 300)
                .fixedSize(horizontal: false, vertical: true)
            if selectedLoop != nil {
                Divider()
                let projection = RunFollowupLoopProjection(run: run)
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(projection.summary ?? "Ciclo").font(.headline)
                        Text(projection.repetitionReason).font(.callout).foregroundStyle(.secondary)
                        RunFollowupHistory(items: projection.history)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }.frame(maxHeight: 170)
            }
        }
        .background(FrondaTheme.surface)
        .onAppear {
            if selectedStep == nil && snapshotSequence == nil { selectedStep = RunJourneyModel(run: run).currentStepID }
        }
        .onChange(of: RunJourneyModel(run: run).currentStepID) { previous, current in
            guard selectedStep == nil || selectedStep == previous else { return }
            selectedStep = current
        }
    }
}
