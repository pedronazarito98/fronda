import HarnessDomain
import SwiftUI

struct SessionIslandView: View {
    var store: AppStore
    var controller: SessionIslandController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealContent = false
    @Namespace private var glass

    private var shape: IslandSilhouette {
        IslandSilhouette(radius: controller.revealed ? 26 : 12, attached: controller.cameraHeight > 0)
    }

    var body: some View {
        surface
            .overlay(alignment: .top) {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: controller.crownHeight / (controller.crownHeight + 16)),
                        .init(color: .black.opacity(0), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: controller.revealed ? controller.crownHeight + 16 : controller.height * 2)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                IslandCrownView(
                    controller: controller, activeCount: store.islandActiveCount,
                    attentionCount: store.islandAttentionCount
                )
            }
            .clipShape(shape)
            .contentShape(shape)
            .animation(reduceMotion ? nil : IslandMotion.morph, value: controller.presentation)
            .animation(reduceMotion ? nil : IslandMotion.morph, value: controller.width)
            .animation(reduceMotion ? nil : IslandMotion.morph, value: controller.height)
            .onHover { controller.hover($0) }
            .frame(width: controller.canvasWidth, height: controller.canvasHeight, alignment: .top)
            .preferredColorScheme(store.colorScheme)
            .tint(FrondaTheme.accent)
            .ignoresSafeArea()
            .onChange(
                of: [
                    store.islandRuns.count + store.visibleExternalSessions.count,
                    store.islandActiveCount, store.islandAttentionCount,
                ], initial: true
            ) { _, counts in
                controller.resize(sessionCount: counts[0], activityCount: counts[1], attentionCount: counts[2])
            }
            .task(id: controller.presentation) {
                revealContent = false
                guard controller.revealed else { return }
                if !reduceMotion { try? await Task.sleep(for: .milliseconds(70)) }
                guard !Task.isCancelled else { return }
                revealContent = true
            }
    }

    @ViewBuilder private var surface: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 0) { island }
        } else {
            island
        }
    }

    private var island: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: controller.crownHeight).accessibilityHidden(true)
            if controller.revealed {
                Group {
                    if controller.expanded {
                        expandedContent
                    } else {
                        IslandPeekView(activity: IslandActivitySummary.current(in: store), connected: store.connected) {
                            controller.expand(focus: true)
                        }
                    }
                }
                .modifier(IslandReveal(visible: revealContent, delay: 0))
                .transition(.opacity)
            }
        }
        .frame(width: controller.width, height: controller.height, alignment: .top)
        .modifier(
            IslandGlassSurface(
                shape: shape, namespace: glass, revealed: controller.revealed)
        )
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if !store.connected {
                Label("Desconectado · último estado recebido", systemImage: "wifi.slash")
                    .font(.system(size: 10)).foregroundStyle(.orange)
            }
            if store.islandRuns.isEmpty && store.visibleExternalSessions.isEmpty {
                IslandEmptyState().frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(store.islandRuns) { run in
                            IslandRunRow(run: run, connected: store.connected) {
                                controller.openHarness(route: "run:" + run.id, store: store)
                            }
                        }
                        ForEach(store.visibleExternalSessions) { session in IslandExternalSessionRow(session: session) }
                    }
                }.scrollIndicators(.hidden).frame(maxHeight: .infinity)
            }
            if let error = store.externalSessionError {
                Text(error).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(2)
            }
            footer
        }.padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 16)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Sessões").font(.system(size: 13, weight: .semibold)).tracking(-0.2)
            Text(
                store.islandAttentionCount > 0
                    ? "\(store.islandAttentionCount) aguardando" : "\(store.islandActiveCount) em execução"
            )
            .font(.system(size: 10)).foregroundStyle(store.islandAttentionCount > 0 ? Color.orange : .secondary)
            .contentTransition(.numericText())
            Spacer()
            Button {
                controller.togglePin()
            } label: {
                Image(systemName: controller.pinned ? "pin.fill" : "pin")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(controller.pinned ? FrondaTheme.accent : Color.secondary)
            }.help(controller.pinned ? "Soltar central" : "Manter aberta")
                .accessibilityLabel(controller.pinned ? "Soltar central" : "Manter central aberta")
            Button {
                controller.collapse()
            } label: {
                Image(systemName: "chevron.up").foregroundStyle(.secondary)
            }.help("Recolher (Esc)").accessibilityLabel("Recolher central").accessibilityIdentifier("island.collapse")
        }.font(.system(size: 10, weight: .medium)).buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                controller.openHarness(store: store)
            } label: {
                Label("Abrir Fronda", systemImage: "arrow.up.right")
            }.buttonStyle(.plain).accessibilityIdentifier("island.open-harness")
            Spacer()
            Button {
                store.perform("queue.toggle")
            } label: {
                Label(
                    store.snapshot.preferences.queuePaused ? "Retomar fila" : "Pausar fila",
                    systemImage: store.snapshot.preferences.queuePaused ? "play.fill" : "pause.fill")
            }.buttonStyle(.plain)
                .disabled(!store.connected || store.busy.contains("queue.toggle"))
                .help("Controla apenas a fila de runs do Fronda")
        }.font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            .padding(.top, 6)
    }
}
