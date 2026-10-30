import HarnessDomain
import SwiftUI

struct NewRunProviderPicker: View {
    @Binding var draft: NewRunDraft
    let providers: [ProviderInfo]
    let defaultProvider: ProviderKind?

    private var selected: ProviderInfo? { providers.first { $0.kind == draft.provider } }
    private var available: Bool { selected?.state == "AVAILABLE" }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Executor", systemImage: "terminal").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if draft.providerIsCustomized, let defaultProvider {
                    Button("Usar padrão") {
                        var updatedDraft = draft
                        updatedDraft.provider = defaultProvider
                        updatedDraft.providerIsCustomized = false
                        draft = updatedDraft
                    }.buttonStyle(.link).font(.system(size: 10)).help("Padrão do fluxo: \(defaultProvider.rawValue)")
                }
            }
            Picker("Executor", selection: selection) {
                ForEach(ProviderKind.allCases) { Text($0.rawValue).tag($0) }
            }.labelsHidden().pickerStyle(.segmented).frame(maxWidth: .infinity, alignment: .leading)
            Label(
                available ? "Disponível" : "Conectar antes de executar",
                systemImage: available ? "checkmark.circle.fill" : "circle.dotted"
            )
            .font(.system(size: 10)).foregroundStyle(available ? FrondaTheme.success : .secondary)
            .help(selected?.detail ?? "Você pode preparar o contexto agora e conectar o executor antes de executar.")
        }
    }

    private var selection: Binding<ProviderKind> {
        Binding(
            get: { draft.provider },
            set: {
                var updatedDraft = draft
                updatedDraft.provider = $0
                updatedDraft.providerIsCustomized = true
                draft = updatedDraft
            })
    }
}
