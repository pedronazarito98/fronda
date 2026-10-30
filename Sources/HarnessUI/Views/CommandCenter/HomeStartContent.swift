import SwiftUI

struct HomeStartContent: View {
    let store: AppStore
    let size: HomeCardSize
    @SceneStorage("fronda.home.intent") private var intent = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("O que você quer resolver?").font(.callout.weight(.medium))
            TextField("Descreva um objetivo…", text: $intent, axis: .vertical)
                .textFieldStyle(.plain).lineLimit(size == .compact ? 2...3 : 3...5)
                .padding(12).background(FrondaTheme.canvas, in: .rect(cornerRadius: 10))
                .accessibilityLabel("Objetivo da nova tarefa").accessibilityIdentifier("home.intent")
                .onSubmit(prepare)
            Button("Preparar tarefa", systemImage: "arrow.up.right", action: prepare)
                .buttonStyle(.borderedProminent)
                .disabled(intent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("home.prepare")
            Spacer(minLength: 0)
            if size != .compact {
                Text("Defina fluxo, projeto e contexto antes de executar.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Explorar fluxos", systemImage: "point.3.connected.trianglepath.dotted") {
                store.route = "runbooks"
            }.buttonStyle(.plain).font(.caption.weight(.medium)).foregroundStyle(FrondaTheme.accent)
        }
    }

    private func prepare() {
        let objective = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !objective.isEmpty else { return }
        store.composerText = objective
        store.composerSource = nil
        store.composerRunbookID = ""
        store.composerProjectID = ""
        store.showComposer = true
    }
}
