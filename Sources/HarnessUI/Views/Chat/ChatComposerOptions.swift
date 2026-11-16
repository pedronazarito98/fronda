import HarnessDomain
import SwiftUI

struct ChatComposerOptions: View {
    let store: AppStore
    @Binding var draft: ChatComposerDraft
    let recentProjectID: String?
    @Environment(\.openSettings) private var openSettings
    @State private var enteringModel = false
    @State private var customModel = ""
    @State private var requestedProviders = Set<ProviderKind>()

    private var selectedModel: ProviderModel? {
        models(for: draft.provider).first { $0.id == draft.execution.model }
    }

    private var modelLabel: String {
        if let model = selectedModel { return model.name.isEmpty ? model.id : model.name }
        return draft.execution.model ?? draft.provider.rawValue
    }

    private var efforts: [String] {
        let available = selectedModel?.efforts ?? ["low", "medium", "high"]
        if let current = draft.execution.effort, !available.contains(current) { return available + [current] }
        return available
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if enteringModel {
                HStack {
                    TextField("Identificador do modelo para " + draft.provider.rawValue, text: $customModel)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(applyCustomModel)
                    Button("Usar", action: applyCustomModel)
                        .disabled(customModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Cancelar") { enteringModel = false }
                }
                .accessibilityIdentifier("chat.custom-model")
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) {
                    modelMenu
                    effortMenu
                    projectControl
                }
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 4) {
                        modelMenu
                        effortMenu
                    }
                    projectControl
                }
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.primary)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .task(id: providersState) { await discoverModels() }
    }

    private var providersState: String {
        store.snapshot.providers.map { $0.kind.rawValue + ":" + $0.state }.sorted().joined(separator: "|")
    }

    private var modelMenu: some View {
        Menu {
            ForEach(ProviderKind.allCases) { provider in
                Section(provider.rawValue) {
                    if let info = store.snapshot.providers.first(where: { $0.kind == provider }),
                        info.state != "AVAILABLE"
                    {
                        Text("Conexão necessária")
                    }
                    option(
                        "Padrão do " + provider.rawValue,
                        selected: provider == draft.provider && draft.execution.model == nil
                    ) { selectModel(nil, for: provider) }
                    if let info = store.snapshot.providers.first(where: { $0.kind == provider }),
                        info.state == "AVAILABLE", requestedProviders.contains(provider),
                        info.models?.isEmpty != false
                    {
                        Text(info.modelDiscoveryDetail ?? "Nenhum modelo disponível")
                    }
                    ForEach(models(for: provider)) { model in
                        option(
                            model.name.isEmpty ? model.id : model.name,
                            selected: provider == draft.provider && draft.execution.model == model.id
                        ) { selectModel(model.id, for: provider) }
                    }
                }
            }
            Divider()
            Button("Ajustes de provedores…") {
                store.settingsSection = "Providers"
                openSettings()
            }
            Button("Informar outro modelo…") {
                customModel = draft.execution.model ?? ""
                enteringModel = true
            }
            Button("Atualizar modelos") {
                requestedProviders.removeAll()
                Task { await discoverModels() }
            }.disabled(!store.connected)
        } label: {
            controlLabel(modelLabel, icon: "sparkles")
        }
        .help("Modelo da próxima mensagem")
        .accessibilityLabel("Modelo, " + modelLabel)
        .accessibilityIdentifier("chat.model")
    }

    private var effortMenu: some View {
        Menu {
            option("Padrão do modelo", selected: draft.execution.effort == nil) {
                draft.execution.effort = nil
            }
            ForEach(efforts, id: \.self) { effort in
                option(ExecutionControls.effortLabel(effort), selected: draft.execution.effort == effort) {
                    draft.execution.effort = effort
                }
            }
        } label: {
            controlLabel("Esforço: " + (draft.execution.effort.map(shortEffort) ?? "Padrão"), icon: "brain")
        }
        .help("Esforço de raciocínio da próxima mensagem")
        .accessibilityLabel("Esforço de raciocínio, " + (draft.execution.effort.map(shortEffort) ?? "Padrão"))
        .accessibilityIdentifier("chat.effort")
    }

    private var projectControl: some View {
        HStack(spacing: 4) {
            projectMenu
            if draft.projectID != nil {
                Menu {
                    option("Automático", selected: draft.autonomy == .auto) { draft.autonomy = .auto }
                    option("Revisar antes", selected: draft.autonomy == .guided) { draft.autonomy = .guided }
                } label: {
                    controlLabel(draft.autonomy == .auto ? "Automático" : "Revisar antes", icon: "play.circle")
                }
                .help(
                    draft.autonomy == .auto
                        ? "O Fronda avança sozinho. Comandos não aprovados e ações sensíveis pedem sua decisão."
                        : "O Fronda aguarda sua aprovação do contexto e do plano."
                )
                .accessibilityLabel("Modo de execução, " + (draft.autonomy == .auto ? "Automático" : "Revisar antes"))
                .accessibilityIdentifier("chat.autonomy")
            }
            if draft.projectID == nil, let id = recentProjectID,
                let project = store.snapshot.projects.first(where: { $0.id == id })
            {
                Button {
                    draft.projectID = id
                } label: {
                    Label("Trabalhar em " + project.name, systemImage: "folder")
                        .lineLimit(1).truncationMode(.middle)
                }
                .buttonStyle(.plain)
                .foregroundStyle(FrondaTheme.accent)
                .help("Selecionar o projeto para o próximo pedido de alteração")
                .accessibilityIdentifier("chat.reuse-project")
            }
        }
    }

    private var projectMenu: some View {
        let selected = store.snapshot.projects.first { $0.id == draft.projectID }
        return Menu {
            option("Responder no chat", selected: draft.projectID == nil) {
                draft.projectID = nil
            }
            Section("Trabalhar em um projeto") {
                ForEach(store.snapshot.projects) { project in
                    option(project.name, selected: project.id == draft.projectID) {
                        draft.projectID = project.id
                    }
                }
                Button("Escolher pasta…", systemImage: "folder.badge.plus") {
                    Task {
                        do {
                            if let id = try await store.addChatProject() { draft.projectID = id }
                        } catch {
                            store.error = error.localizedDescription
                        }
                    }
                }
            }
        } label: {
            controlLabel(
                selected.map { "Projeto: " + $0.name }
                    ?? (draft.projectID == nil ? "Conversar" : "Projeto indisponível"),
                icon: draft.projectID == nil ? "bubble.left" : "folder"
            )
            .foregroundStyle(draft.projectID == nil ? FrondaTheme.textMuted : FrondaTheme.accent)
        }
        .help(
            selected.map { "O próximo envio inicia uma execução em " + $0.name }
                ?? (draft.projectID == nil
                    ? "Escolher entre conversar e trabalhar em um projeto"
                    : "Escolha outro projeto ou volte para Conversar")
        )
        .accessibilityLabel(
            selected.map { "Trabalhar em " + $0.name }
                ?? (draft.projectID == nil ? "Conversar" : "Projeto indisponível")
        )
        .accessibilityIdentifier("chat.mode")
    }

    private func models(for provider: ProviderKind) -> [ProviderModel] {
        store.snapshot.providers.first { $0.kind == provider }?.models ?? []
    }

    private func selectModel(_ id: String?, for provider: ProviderKind) {
        draft.provider = provider
        draft.execution = ExecutionConfiguration(model: id)
        enteringModel = false
    }

    private func applyCustomModel() {
        let value = customModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        selectModel(value, for: draft.provider)
    }

    private func discoverModels() async {
        for info in store.snapshot.providers where info.state == "AVAILABLE" && (info.models?.isEmpty != false) {
            guard requestedProviders.insert(info.kind).inserted else { continue }
            do {
                var request = RPCRequest("provider.models")
                request.text = info.kind.rawValue
                _ = try await store.send(request)
                await store.refresh(silent: true)
            } catch {
                requestedProviders.remove(info.kind)
            }
        }
    }

    private func shortEffort(_ effort: String) -> String {
        ExecutionControls.effortLabel(effort).components(separatedBy: " · ").first ?? effort
    }

    private func controlLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).lineLimit(1).truncationMode(.middle)
            Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9).strokeBorder(FrondaTheme.border)
        }
        .contentShape(Rectangle())
    }

    private func option(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if selected { Label(title, systemImage: "checkmark") } else { Text(title) }
        }
    }
}
