import HarnessDomain
import SwiftUI

struct RunExecutionPickers: View {
    let store: AppStore
    let run: Run
    @State private var choosingModel = false
    @State private var choosingEffort = false
    @State private var draft = ExecutionConfiguration()
    @State private var baseline: Run?
    @State private var saving = false
    @State private var error: String?
    @State private var customModel = ""

    private var models: [ProviderModel] {
        store.snapshot.providers.first { $0.kind == run.provider }?.models ?? []
    }
    private var modelLabel: String {
        guard let id = run.execution?.model else { return "Modelo" }
        guard let model = models.first(where: { $0.id == id }), !model.name.isEmpty else { return id }
        return model.name
    }
    private var effortLabel: String {
        run.execution?.effort.map { ExecutionControls.effortLabel($0).components(separatedBy: " · ")[0] } ?? "Esforço"
    }
    private var disabled: Bool {
        run.state.active || run.state == .archived || !store.connected || store.busy.contains(run.id) || saving
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                begin()
                choosingModel = true
            } label: {
                selector(modelLabel)
            }
            .accessibilityLabel("Selecionar modelo").accessibilityIdentifier("run.model-picker")
            .popover(isPresented: $choosingModel, arrowEdge: .top) { choices(model: true) }
            Divider().frame(height: 14)
            Button {
                begin()
                choosingEffort = true
            } label: {
                selector(effortLabel)
            }
            .accessibilityLabel("Selecionar esforço").accessibilityIdentifier("run.effort-picker")
            .popover(isPresented: $choosingEffort, arrowEdge: .top) { choices(model: false) }
        }
        .buttonStyle(.plain).disabled(disabled)
        .help(run.state.active ? "Pause a execução para alterar modelo e esforço." : "Configuração padrão da tarefa")
    }

    private func selector(_ text: String) -> some View {
        HStack(spacing: 5) {
            Text(text).lineLimit(1).truncationMode(.middle)
            Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium))
        }.font(.system(size: 11)).contentShape(Rectangle())
    }

    private func choices(model: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model ? "Modelo da tarefa" : "Esforço de raciocínio").font(.headline)
            Text(run.provider.rawValue).font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 4) {
                    if model {
                        option(
                            "Padrão do provider", detail: "Usar a configuração da instalação",
                            selected: draft.model == nil
                        ) {
                            draft.model = nil
                            draft.effort = nil
                        }
                        ForEach(models) { model in
                            option(
                                model.name.isEmpty ? model.id : model.name, detail: model.detail,
                                selected: draft.model == model.id
                            ) {
                                draft.model = model.id
                                draft.effort = nil
                            }
                        }
                        DisclosureGroup("Outro modelo") {
                            TextField("Identificador", text: $customModel).textFieldStyle(.roundedBorder)
                            Button("Usar identificador") {
                                draft.model = customModel
                                draft.effort = nil
                            }
                            .disabled(customModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }.font(.caption).padding(8)
                    } else {
                        option(
                            "Padrão do modelo", detail: "Usar o esforço recomendado pelo provider",
                            selected: draft.effort == nil
                        ) {
                            draft.effort = nil
                        }
                        ForEach(availableEfforts, id: \.self) { effort in
                            option(ExecutionControls.effortLabel(effort), detail: "", selected: draft.effort == effort)
                            {
                                draft.effort = effort
                            }
                        }
                    }
                }
            }.frame(maxHeight: 280)
            Divider()
            Text(
                "Aplicar cria uma revisão do plano e pede nova aprovação. As configurações próprias de cada etapa são preservadas."
            )
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let error {
                Text(error).font(.caption).foregroundStyle(FrondaTheme.danger)
                Button("Recarregar tarefa") {
                    Task {
                        await store.refresh()
                        baseline = store.snapshot.runs.first { $0.id == run.id }
                        self.error = nil
                    }
                }
            }
            HStack {
                Text(model ? (draft.model ?? "Padrão") : (draft.effort ?? "Padrão"))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                if saving { ProgressView().controlSize(.small) }
                Button("Aplicar", action: save).buttonStyle(.borderedProminent)
                    .disabled(saving || draft == (baseline?.execution ?? ExecutionConfiguration()))
            }
        }
        .padding(18).frame(width: 320).disabled(saving).interactiveDismissDisabled(saving)
    }

    private var availableEfforts: [String] {
        let model = models.first { $0.id == draft.model }
        let values = model?.efforts ?? ["low", "medium", "high"]
        if let current = draft.effort, !values.contains(current) { return values + [current] }
        return values
    }

    private func option(_ title: String, detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 12, weight: .medium))
                    if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(3) }
                }
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark").foregroundStyle(FrondaTheme.accent) }
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            .background(selected ? FrondaTheme.accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func begin() {
        baseline = run
        draft = run.execution ?? ExecutionConfiguration()
        customModel = draft.model ?? ""
        error = nil
    }

    private func save() {
        guard var edited = baseline else { return }
        do { edited.execution = try draft.validated() } catch {
            self.error = error.localizedDescription
            return
        }
        saving = true
        Task {
            defer { saving = false }
            do {
                var request = RPCRequest("plan.save")
                request.id = edited.id
                request.expectedSequence = edited.sequence
                request.run = edited
                _ = try await store.send(request)
                await store.refresh()
                choosingModel = false
                choosingEffort = false
                store.notice = "Configuração atualizada. Revise o plano antes de retomar."
            } catch { self.error = error.localizedDescription }
        }
    }
}
