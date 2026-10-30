import AppKit
import HarnessDomain
import SwiftUI

struct ProjectSettingsView: View {
    var store: AppStore
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProjectSettingsDraft
    @State private var savedDraft: ProjectSettingsDraft
    @State private var section: ProjectSettingsSection
    @State private var operation: Operation?
    @State private var localError: String?
    @State private var notice = ""

    private enum Operation { case save, renewAccess }
    private var working: Bool { operation != nil }
    private var hasChanges: Bool { draft != savedDraft }
    private var currentProject: Project { store.snapshot.projects.first { $0.id == project.id } ?? project }

    init(store: AppStore, project: Project, initialSection: ProjectSettingsSection = .access) {
        self.store = store
        self.project = project
        let initialDraft = ProjectSettingsDraft(project: project)
        _draft = State(initialValue: initialDraft)
        _savedDraft = State(initialValue: initialDraft)
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                navigation
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if section != .validation {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title).font(.system(size: 23, weight: .semibold)).tracking(-0.5)
                                Text(section.detail).font(.callout).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        sectionContent
                    }.padding(26).frame(maxWidth: .infinity, alignment: .topLeading)
                }.id(section)
            }.disabled(working)
            Divider()
            status
        }
        .frame(width: 900, height: 660)
        .background(FrondaTheme.canvas).tint(FrondaTheme.accent)
        .interactiveDismissDisabled(working)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "folder.badge.gearshape").font(.system(size: 22, weight: .light))
                .foregroundStyle(FrondaTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(currentProject.name).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                Text("Ajustes do projeto").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction).disabled(working)
            Button(operation == .save ? "Salvando…" : "Salvar alterações", action: save)
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                .disabled(working || !store.connected || !hasChanges)
                .accessibilityIdentifier("project.settings.save")
        }.padding(.horizontal, 24).padding(.vertical, 17).background(FrondaTheme.surface)
    }

    private var navigation: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(ProjectSettingsSection.allCases) { item in
                Button {
                    section = item
                } label: {
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: item.symbol).font(.system(size: 15)).frame(width: 20).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.title).font(.system(size: 12, weight: .semibold))
                            Text(item.summary).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(section == item ? FrondaTheme.accent : .primary)
                    .padding(.horizontal, 12).padding(.vertical, 13)
                    .background(
                        section == item ? FrondaTheme.accent.opacity(0.10) : .clear,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(item.title)
                .accessibilityAddTraits(section == item ? .isSelected : [])
                .accessibilityRemoveTraits(section == item ? [] : .isSelected)
                .accessibilityIdentifier("project.settings.section.\(item.rawValue)")
            }
            Spacer()
            Label(
                draft.validators.count == 1 ? "1 comando cadastrado" : "\(draft.validators.count) comandos cadastrados",
                systemImage: "terminal"
            ).font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 12)
        }
        .padding(12).frame(width: 192).frame(maxHeight: .infinity)
        .background(FrondaTheme.surface)
    }

    @ViewBuilder private var sectionContent: some View {
        switch section {
        case .access:
            ProjectSettingsAccess(
                project: currentProject, renewing: operation == .renewAccess,
                canRenew: store.connected && !working, renew: renewAccess,
                reveal: { store.reveal(currentProject.path) })
        case .permissions: ProjectSettingsPermissions(draft: $draft)
        case .context: ProjectSettingsContext(draft: $draft)
        case .validation: ValidationCommandsEditor(commands: $draft.validators, scope: .project)
        }
    }

    private var status: some View {
        HStack(alignment: .center, spacing: 10) {
            if working { ProgressView().controlSize(.small) }
            if let localError {
                Label(localError, systemImage: "exclamationmark.circle")
                    .foregroundStyle(FrondaTheme.danger).lineLimit(3).help(localError)
            } else if working {
                Text(operation == .save ? "Confirmando alterações no projeto…" : "Renovando acesso à pasta…")
                    .foregroundStyle(.secondary)
            } else if !store.connected {
                Label("Reconecte ao coordenador para salvar as alterações.", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(FrondaTheme.warning)
            } else if !notice.isEmpty {
                Label(notice, systemImage: "checkmark.circle").foregroundStyle(FrondaTheme.success)
            } else {
                Label(
                    hasChanges ? "Alterações ainda não salvas" : "Configuração atual do projeto",
                    systemImage: hasChanges ? "circle.dotted" : "checkmark.circle"
                ).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if !store.connected, !working {
                Button("Tentar novamente") {
                    Task {
                        await store.refresh(silent: true)
                        if store.connected { localError = nil }
                    }
                }
            }
        }.font(.system(size: 11)).padding(.horizontal, 24).padding(.vertical, 13)
            .frame(minHeight: 46).background(FrondaTheme.surface)
    }

    private func save() {
        guard !working, store.connected, hasChanges else { return }
        let submitted = draft
        operation = .save
        localError = nil
        notice = ""
        Task {
            defer { operation = nil }
            do {
                let latest = try await store.send(RPCRequest("snapshot"))
                guard let current = latest.snapshot?.projects.first(where: { $0.id == project.id }) else {
                    throw HarnessError("O projeto não está mais disponível. Suas alterações continuam neste painel.")
                }
                var request = RPCRequest("project.update")
                request.project = submitted.applying(to: current)
                _ = try await store.send(request)
                savedDraft = submitted
                await store.refresh(silent: true)
                if store.connected {
                    dismiss()
                } else {
                    localError =
                        "As alterações foram salvas, mas não foi possível atualizar o projeto. Reconecte ao coordenador."
                }
            } catch { localError = error.localizedDescription }
        }
    }

    private func renewAccess() {
        guard !working, store.connected else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Renovar acesso"
        panel.message = "Selecione a pasta do repositório. Seu rascunho de ajustes será preservado."
        panel.directoryURL = URL(fileURLWithPath: currentProject.path, isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        operation = .renewAccess
        localError = nil
        notice = ""
        Task {
            defer { operation = nil }
            do {
                var access = Project()
                access.bookmark = try url.bookmarkData(
                    options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                var request = RPCRequest("project.reauthorize")
                request.id = project.id
                request.path = url.path
                request.project = access
                _ = try await store.send(request)
                await store.refresh(silent: true)
                notice = "Acesso renovado. Seu rascunho foi preservado."
                if !store.connected {
                    localError =
                        "O acesso foi renovado, mas não foi possível atualizar a pasta exibida. Reconecte ao coordenador. Seu rascunho foi preservado."
                }
            } catch { localError = error.localizedDescription }
        }
    }
}
