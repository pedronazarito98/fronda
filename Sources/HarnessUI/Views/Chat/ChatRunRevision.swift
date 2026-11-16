import HarnessDomain
import SwiftUI

struct ChatRunReference: Hashable {
    let runID: String
    let sequence: Int?
}

/// Replays the event sequence associated with a past turn. The current worktree can keep advancing independently.
struct ChatRunRevision<Content: View>: View {
    let store: AppStore
    let current: Run
    let sequence: Int?
    @ViewBuilder let content: (Run) -> Content
    @State private var historical: Run?
    @State private var failure: String?
    @State private var retry = 0

    var body: some View {
        Group {
            if sequence == nil {
                content(current)
            } else if let historical, historical.id == current.id, historical.sequence == sequence {
                content(historical)
            } else if let failure {
                VStack(alignment: .leading) {
                    Label(failure, systemImage: "exclamationmark.circle").font(.caption)
                    Button("Tentar novamente") { retry += 1 }.disabled(!store.connected)
                }
            } else {
                ProgressView("Abrindo etapas deste envio…").controlSize(.small)
            }
        }
        .task(id: retry) {
            guard let sequence else { return }
            failure = nil
            do {
                var request = RPCRequest("replay")
                request.id = current.id
                request.number = sequence
                guard let replay = try await store.send(request).run, replay.sequence == sequence else {
                    throw HarnessError("A revisão desta execução está indisponível.")
                }
                historical = replay
            } catch {
                if !Task.isCancelled { failure = error.localizedDescription }
            }
        }
    }
}
