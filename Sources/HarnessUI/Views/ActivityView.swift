import HarnessDomain
import SwiftUI

struct ActivityView: View {
    var store: AppStore
    let run: Run
    @State private var filter = ""
    @State private var selected: RunEvent?
    @State private var replay: Run?
    var events: [RunEvent] {
        (store.events[run.id] ?? []).filter {
            filter.isEmpty || $0.kind.localizedCaseInsensitiveContains(filter)
                || $0.message.localizedCaseInsensitiveContains(filter)
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Filtrar atividade…", text: $filter).textFieldStyle(.roundedBorder)
                Button("Atualizar") { Task { await store.loadEvents(run.id) } }
            }.padding(18)
            if let replay {
                Surface(padding: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("REPLAY · EVENTO \(replay.sequence)").font(.caption.monospaced()).foregroundStyle(
                                .orange)
                            Text("\(replay.state.rawValue) · \(replay.reason)").font(.callout)
                            Text("Snapshot \(replay.revision.prefix(16)) · plano v\(replay.planRevision)").font(
                                .caption
                            ).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Voltar ao presente") { self.replay = nil }
                    }
                }.padding(.horizontal, 18)
                DisclosureGroup("Plano, diff e gates naquele momento") {
                    MonospaceBlock(
                        text: replay.plan.map { "\($0.title): \($0.status.rawValue)" }.joined(separator: "\n") + "\n\n"
                            + replay.diff + "\n\n"
                            + replay.validations.map {
                                "\($0.validator.displayCommand): \($0.status.rawValue)\n\($0.output)"
                            }.joined(separator: "\n")
                    ).frame(height: 240)
                }.padding(.horizontal, 18)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let earliest = store.events[run.id]?.first, earliest.sequence > 1 {
                        Button("Carregar eventos anteriores") {
                            Task { await store.loadEvents(run.id, before: earliest.sequence) }
                        }
                    }
                    ForEach(events.reversed()) { event in
                        Button {
                            selected = event
                            loadReplay(event.sequence)
                        } label: {
                            HStack(alignment: .top, spacing: 15) {
                                VStack(spacing: 5) {
                                    Circle().fill(
                                        event.kind.contains("blocked") || event.kind.contains("fail")
                                            ? .orange : FrondaTheme.accent.opacity(0.65)
                                    ).frame(width: 7, height: 7)
                                    Rectangle().fill(.quaternary).frame(width: 1, height: 46)
                                }.padding(.top, 5)
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text(event.kind).font(.system(size: 11, weight: .medium, design: .monospaced))
                                        Spacer()
                                        Text(event.occurredAt, style: .time).font(.caption).foregroundStyle(.tertiary)
                                    }
                                    Text(event.message).font(.system(size: 12)).foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading).textSelection(.enabled)
                                    Text("#\(event.sequence) · \(event.actor)").font(
                                        .system(size: 9, design: .monospaced)
                                    ).foregroundStyle(.tertiary)
                                }
                            }.padding(.vertical, 10)
                        }.buttonStyle(.plain)
                    }
                }.padding(24)
            }
            Text("Replay reconstrói snapshots em modo de leitura. Comandos nunca são reexecutados.").font(
                .system(size: 10)
            ).foregroundStyle(.secondary).padding(12)
        }.task(id: run.sequence) { await store.loadEvents(run.id) }
    }
    private func loadReplay(_ sequence: Int) {
        var request = RPCRequest("replay")
        request.id = run.id
        request.number = sequence
        Task { do { replay = try await store.send(request).run } catch { store.error = error.localizedDescription } }
    }
}
