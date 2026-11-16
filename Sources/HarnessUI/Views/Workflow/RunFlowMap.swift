import HarnessDomain
import SwiftUI

struct RunFlowMap: View {
    let run: Run
    @Binding var selectedStepID: String?
    var project: Project?
    var loops: [RunFlowMapLoop] = []
    var selectedLoopID: String?
    var isConnected = true
    var showsCurrent = true
    var onInspectStep: (String) -> Void = { _ in }
    var onSelectLoop: (String) -> Void = { _ in }

    @State private var presentation = Presentation.map
    @State private var zoom: CGFloat = 1
    @State private var scrollRequest = 0
    @State private var scrollPosition = ScrollPosition(point: .zero)
    @FocusState private var focusedStepID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Presentation: String, CaseIterable {
        case map = "Grafo"
        case list = "Etapas"
    }

    private var journey: RunJourneyModel { RunJourneyModel(run: run) }
    private var nodes: [RunFlowMapNodeModel] {
        var seen = Set<String>()
        return journey.steps.filter { seen.insert($0.id).inserted }.map {
            RunFlowMapNodeModel(
                journey: $0, run: run, project: project, connected: isConnected, showsCurrent: showsCurrent)
        }
    }
    private var layout: RunFlowMapLayout { RunFlowMapLayout(steps: run.plan, loops: loops) }

    var body: some View {
        GeometryReader { geometry in
            let showMap = presentation == .map
            VStack(spacing: 0) {
                toolbar(showMap: showMap, size: geometry.size)
                if !isConnected {
                    notice("Sem conexão · mostrando o último estado recebido", symbol: "wifi.slash")
                }
                if layout.hasInvalidDependencies {
                    notice("O plano contém dependências que precisam de revisão.", symbol: "exclamationmark.triangle")
                }
                if nodes.isEmpty {
                    ContentUnavailableView(
                        "O fluxo está sendo preparado", systemImage: "point.3.connected.trianglepath.dotted",
                        description: Text("As etapas aparecerão quando o plano estiver disponível."))
                } else if showMap {
                    map
                } else {
                    RunFlowMapList(
                        nodes: nodes, loops: loops, selectedStepID: $selectedStepID,
                        selectedLoopID: selectedLoopID, onInspectStep: onInspectStep, onSelectLoop: onSelectLoop)
                }
                if showMap { legend }
            }
        }
        .background(FrondaTheme.surface)
        .onChange(of: run.id) { _, _ in
            zoom = 1
            focusedStepID = nil
        }
    }

    private var map: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                graph
                    .scaleEffect(zoom, anchor: .topLeading)
                    .frame(
                        width: layout.size.width * zoom, height: layout.size.height * zoom, alignment: .topLeading
                    )
                    .frame(
                        minWidth: geometry.size.width, minHeight: geometry.size.height,
                        alignment: .top)
            }
            .scrollPosition($scrollPosition)
            .onAppear {
                if layout.size.width > 0 && layout.size.height > 0 {
                    zoom = max(
                        0.55,
                        min(
                            1,
                            min(
                                (geometry.size.width - 24) / layout.size.width,
                                (geometry.size.height - 24) / layout.size.height)))
                }
                reveal(selectedStepID ?? journey.currentStepID, in: geometry.size)
            }
            .onChange(of: scrollRequest) { _, _ in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    reveal(journey.currentStepID, in: geometry.size)
                }
            }
            .onChange(of: focusedStepID) { _, id in
                guard let id else { return }
                selectedStepID = id
                reveal(id, in: geometry.size)
            }
            .onChange(of: journey.currentStepID) { previous, current in
                guard selectedStepID == nil || selectedStepID == previous else { return }
                selectedStepID = current
                reveal(current, in: geometry.size)
            }
            .onChange(of: selectedStepID) { _, id in reveal(id, in: geometry.size) }
            .onChange(of: zoom) { _, _ in reveal(selectedStepID, in: geometry.size) }
        }
        .background(FrondaTheme.surface)
    }

    private func reveal(_ id: String?, in viewport: CGSize) {
        guard let node = layout.nodes.first(where: { $0.id == id }) else { return }
        scrollPosition.scrollTo(
            x: max(0, node.frame.midX * zoom - viewport.width / 2),
            y: max(0, node.frame.midY * zoom - viewport.height / 2))
    }

    private var graph: some View {
        let models = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        return ZStack(alignment: .topLeading) {
            ForEach(layout.groups) { group in
                RunFlowMapGroup(group: group, selected: selectedLoopID == group.id) { onSelectLoop(group.id) }
            }
            RunFlowMapEdges(layout: layout, nodes: models)
            ForEach(layout.nodes) { placement in
                if let node = models[placement.id] {
                    RunFlowMapNode(node: node, selected: selectedStepID == node.id && selectedLoopID == nil) {
                        selectedStepID = node.id
                        onInspectStep(node.id)
                    }
                    .focused($focusedStepID, equals: node.id)
                    // Identify the node's own bounds, before position expands its layout wrapper.
                    .id(node.id)
                    .position(x: placement.frame.midX, y: placement.frame.midY)
                }
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .onMoveCommand(perform: moveSelection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Grafo da tarefa. Use a apresentação em etapas para ler as dependências em sequência.")
    }

    private func toolbar(showMap: Bool, size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                Picker("Apresentação do fluxo", selection: $presentation) {
                    ForEach(Presentation.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).labelsHidden().frame(width: 116)
                    .accessibilityIdentifier("flow.presentation")
                Spacer(minLength: 0)
            }
            if showMap {
                HStack(spacing: 10) {
                    zoomControls(size: size)
                    Spacer(minLength: 0)
                    Button {
                        selectedStepID = journey.currentStepID
                        scrollRequest += 1
                    } label: {
                        Image(systemName: "scope")
                    }
                    .disabled(journey.currentStepID == nil)
                    .help("Selecionar e mostrar a etapa atual").accessibilityLabel("Ir para a etapa atual")
                    .accessibilityIdentifier("flow.current")
                }
            }
        }
        .controlSize(.small).buttonStyle(.borderless)
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private func zoomControls(size: CGSize) -> some View {
        HStack(spacing: 6) {
            Button {
                zoom = max(0.35, zoom - 0.15)
            } label: {
                Image(systemName: "minus")
            }
            .disabled(zoom <= 0.35).help("Diminuir mapa").accessibilityLabel("Diminuir mapa")
            Text("\(Int((zoom * 100).rounded()))%")
                .font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary).frame(width: 34)
                .accessibilityLabel("Ampliação de \(Int((zoom * 100).rounded())) por cento")
            Button {
                zoom = min(1.6, zoom + 0.15)
            } label: {
                Image(systemName: "plus")
            }
            .disabled(zoom >= 1.6).help("Ampliar mapa").accessibilityLabel("Ampliar mapa")
            Button {
                zoom = max(
                    0.35, min(1.6, min((size.width - 24) / layout.size.width, (size.height - 120) / layout.size.height))
                )
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Ajustar mapa ao espaço").accessibilityLabel("Ajustar mapa ao espaço")
            .accessibilityIdentifier("flow.fit")
        }
    }

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { legendItems(RunFlowAppearance.allCases) }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) { legendItems(Array(RunFlowAppearance.allCases.prefix(3))) }
                HStack(spacing: 12) { legendItems(Array(RunFlowAppearance.allCases.dropFirst(3))) }
            }
        }
        .font(.system(size: 10)).padding(.horizontal, 12).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estados: execução, resultado comprovado, atenção, espera e falha")
    }

    private func legendItems(_ appearances: [RunFlowAppearance]) -> some View {
        ForEach(appearances, id: \.self) { appearance in
            Label(appearance.label, systemImage: appearance.symbol)
                .foregroundStyle(appearance.color)
        }
    }

    private func notice(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption).foregroundStyle(FrondaTheme.warning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.bottom, 10)
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard let selected = focusedStepID ?? selectedStepID ?? journey.currentStepID ?? nodes.first?.id else { return }
        let next: String?
        switch direction {
        case .left: next = layout.neighbor(of: selected, horizontal: -1, vertical: 0)
        case .right: next = layout.neighbor(of: selected, horizontal: 1, vertical: 0)
        case .up: next = layout.neighbor(of: selected, horizontal: 0, vertical: -1)
        case .down: next = layout.neighbor(of: selected, horizontal: 0, vertical: 1)
        @unknown default: next = nil
        }
        if let next { focusedStepID = next }
    }
}
