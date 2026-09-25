import HarnessDomain
import SwiftUI

struct RunCapabilitiesView: View {
    var store: AppStore
    let run: Run
    private var eligible: [HarnessExtension] {
        (store.snapshot.preferences.extensions ?? []).filter {
            $0.enabled && ($0.projectIDs.isEmpty || $0.projectIDs.contains(run.projectID))
        }
    }
    var body: some View {
        DisclosureGroup("Capacidades da tarefa · \(run.extensionBindings?.count ?? 0) selecionadas") {
            VStack(alignment: .leading, spacing: 12) {
                if eligible.isEmpty {
                    Text("Adicione MCPs, skills e comandos em Ajustes → Extensões.").font(.caption).foregroundStyle(
                        .secondary)
                }
                ForEach(eligible) { item in
                    let binding = run.extensionBindings?.first { $0.extensionID == item.id }
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(
                            item.name,
                            isOn: Binding(
                                get: { run.extensionOverrides?[item.id] ?? (binding != nil) },
                                set: { enabled in
                                    store.perform("extension.select", id: run.id) {
                                        $0.relatedID = item.id
                                        $0.flag = enabled
                                    }
                                })
                        ).disabled(run.state.active || run.state == .archived)
                        Text(binding?.reason ?? "Não selecionada automaticamente").font(.caption).foregroundStyle(
                            .secondary)
                        Text(item.stages.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if !eligible.isEmpty {
                    Text("Alterações exigem preparar o contexto novamente.").font(.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
        }
    }
}
