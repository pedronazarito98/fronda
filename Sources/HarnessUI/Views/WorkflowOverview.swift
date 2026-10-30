import HarnessDomain
import SwiftUI

struct WorkflowOverview: View {
    let run: Run
    @Binding var section: RunWorkspaceSection
    @Binding var selectedStepID: String?
    @Binding var followsCurrentStep: Bool

    private var model: RunJourneyModel { RunJourneyModel(run: run) }
    private var selected: RunJourneyStep? { model.step(id: selectedStepID) }
    private var selection: Binding<String?> {
        Binding(
            get: { selected?.id },
            set: { id in
                selectedStepID = id
                followsCurrentStep = id == model.currentStepID
            })
    }

    var body: some View {
        VStack(spacing: 0) {
            RunJourneySummary(
                run: run, openChanges: { section = .changes },
                openValidation: { section = .validation }, openEvidence: { section = .evidence }
            ).padding(.horizontal, 22).padding(.vertical, 16)
            Divider()
            if model.steps.isEmpty {
                ContentUnavailableView(
                    "O fluxo está sendo preparado", systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("As etapas aparecerão aqui quando o coordenador preparar o plano."))
            } else {
                GeometryReader { geometry in
                    if geometry.size.width >= 780 {
                        HStack(spacing: 0) {
                            RunJourneyTimeline(model: model, selectedStepID: selection)
                                .frame(width: 238)
                                .background(FrondaTheme.surface.opacity(0.65))
                            Divider()
                            detail
                        }
                    } else {
                        VStack(spacing: 0) {
                            compactSteps
                            Divider()
                            detail
                        }
                    }
                }
            }
        }
        .onAppear { if followsCurrentStep { selectedStepID = model.currentStepID } }
        .onChange(of: model.currentStepID) { _, id in
            if followsCurrentStep { selectedStepID = id }
        }
        .onChange(of: run.plan.map(\.id)) { _, ids in
            if let selectedStepID, !ids.contains(selectedStepID) {
                self.selectedStepID = nil
                followsCurrentStep = true
            }
        }
    }

    @ViewBuilder private var detail: some View {
        if let selected {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Label(
                        selected.isCurrent ? "Etapa atual" : "Explorando o fluxo",
                        systemImage: selected.isCurrent ? "dot.radiowaves.left.and.right" : "cursorarrow.click"
                    )
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Spacer()
                    if !selected.isCurrent, let currentID = model.currentStepID {
                        Button("Voltar à etapa atual") {
                            selectedStepID = currentID
                            followsCurrentStep = true
                        }.font(.caption).accessibilityIdentifier("journey.follow-current")
                    }
                }.padding(.horizontal, 24).padding(.vertical, 12)
                Divider()
                RunJourneyDetail(run: run, selected: selected, onOpen: { section = $0 }) { id in
                    selection.wrappedValue = id
                }
                Divider()
                stageNavigation(selected)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var compactSteps: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.steps) { item in
                        Button {
                            selection.wrappedValue = item.id
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: item.state.symbol).foregroundStyle(item.state.color)
                                Text(item.title).font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(
                                selected?.id == item.id ? FrondaTheme.accent.opacity(0.12) : FrondaTheme.surface,
                                in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain).id(item.id)
                        .accessibilityLabel("\(item.title), \(item.state.label)")
                        .accessibilityAddTraits(selected?.id == item.id ? .isSelected : [])
                        .accessibilityIdentifier("journey.step." + item.id)
                    }
                }.padding(12)
            }
            .onAppear { if let id = selected?.id { proxy.scrollTo(id, anchor: .center) } }
            .onChange(of: selected?.id) { _, id in
                if let id { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private func stageNavigation(_ selected: RunJourneyStep) -> some View {
        let index = model.steps.firstIndex { $0.id == selected.id } ?? 0
        return HStack {
            Button {
                selection.wrappedValue = model.steps[index - 1].id
            } label: {
                Label("Etapa anterior", systemImage: "chevron.left")
            }.disabled(index == 0)
            Spacer()
            Text("\(index + 1) de \(model.steps.count)")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Spacer()
            Button {
                selection.wrappedValue = model.steps[index + 1].id
            } label: {
                HStack(spacing: 6) {
                    Text("Ver próxima etapa")
                    Image(systemName: "chevron.right")
                }
            }.disabled(index == model.steps.count - 1)
        }.font(.caption).padding(.horizontal, 20).padding(.vertical, 12)
    }
}
