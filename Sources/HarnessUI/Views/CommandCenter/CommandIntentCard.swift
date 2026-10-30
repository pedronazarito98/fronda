import HarnessDomain
import SwiftUI

struct CommandIntentCard: View {
    var store: AppStore
    @Binding var intent: String
    var welcomesFirstTask = true
    @State private var projectID = ""
    @FocusState private var intentFocused: Bool

    private var canPrepare: Bool { !intent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var selectedProject: Project? {
        store.snapshot.projects.first { $0.id == projectID } ?? store.snapshot.projects.first
    }
    private var projectSelection: Binding<String> {
        Binding(get: { selectedProject?.id ?? "" }, set: { projectID = $0 })
    }
    private var quickStarts: [Runbook] {
        let preferred = ["Implementar issue", "Corrigir bug", "Revisar PR", "Explorar código"]
        let matches = preferred.compactMap { name in store.snapshot.runbooks.first { $0.name == name } }
        let ids = Set(matches.map(\.id))
        return Array((matches + store.snapshot.runbooks.filter { !ids.contains($0.id) }).prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    if welcomesFirstTask {
                        FrondaMascot(size: 42).accessibilityHidden(true)
                    } else {
                        Image(nsImage: FrondaMenuBarIcon.image).renderingMode(.template)
                            .foregroundStyle(FrondaTheme.accent).accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(welcomesFirstTask ? "O que você quer resolver?" : "Começar uma tarefa")
                            .font(.system(size: 18, weight: .semibold)).tracking(-0.3)
                        Text("Descreva um objetivo ou cole uma issue ou um PR.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }.padding(.horizontal, 20).padding(.top, 18)
                TextField("Quero…", text: $intent, axis: .vertical)
                    .textFieldStyle(.plain).font(.system(size: 16)).lineLimit(2...4)
                    .padding(.horizontal, 23).padding(.top, 18).padding(.bottom, 17)
                    .focused($intentFocused)
                    .onSubmit { if canPrepare { prepare() } }
                    .accessibilityLabel("Objetivo da nova tarefa")
                    .accessibilityIdentifier("home.intent")
                Divider().padding(.horizontal, 20)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        projectControl
                        Spacer(minLength: 10)
                        prepareButton
                    }
                    VStack(alignment: .leading, spacing: 13) {
                        projectControl
                        prepareButton
                    }
                }.padding(.horizontal, 20).padding(.vertical, 15)
            }
            .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: FrondaTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: FrondaTheme.cornerRadius)
                    .strokeBorder(intentFocused ? FrondaTheme.accent.opacity(0.6) : FrondaTheme.border, lineWidth: 1)
            }
            if !quickStarts.isEmpty {
                HStack(alignment: .center, spacing: 12) {
                    Text("Ou comece com").font(.caption).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(quickStarts) { book in
                                RunbookStartButton(book: book) { prepare(book: book) }
                            }
                        }
                    }.fixedSize(horizontal: false, vertical: true)
                    Button("Ver fluxos") { store.route = "runbooks" }
                        .buttonStyle(.plain).font(.caption).foregroundStyle(FrondaTheme.accent)
                }
            }
        }
    }

    @ViewBuilder private var projectControl: some View {
        if let project = selectedProject {
            HStack(spacing: 10) {
                Image(systemName: "folder").foregroundStyle(FrondaTheme.accent).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Picker("Projeto", selection: projectSelection) {
                        ForEach(store.snapshot.projects) { Text($0.name).tag($0.id) }
                    }.labelsHidden().pickerStyle(.menu).fixedSize()
                        .accessibilityIdentifier("home.project")
                    if !project.branch.isEmpty {
                        Text(project.branch).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Button {
                    store.addProject()
                } label: {
                    Image(systemName: "plus").font(.caption)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .disabled(!store.connected || store.busy.contains("project.add"))
                .help("Adicionar outro projeto").accessibilityLabel("Adicionar outro projeto")
            }
        } else {
            HStack(spacing: 10) {
                Button {
                    store.addProject()
                } label: {
                    Label("Escolher repositório…", systemImage: "folder.badge.plus")
                }
                .controlSize(.regular)
                .disabled(!store.connected || store.busy.contains("project.add"))
                .accessibilityIdentifier("home.add-project")
                Text("Seu primeiro projeto").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var prepareButton: some View {
        Button(action: { prepare() }) {
            Label("Preparar tarefa", systemImage: "arrow.up.right")
        }
        .buttonStyle(.borderedProminent).controlSize(.large)
        .disabled(!canPrepare)
        .help("Definir fluxo, contexto e critérios antes de executar")
        .accessibilityIdentifier("home.prepare")
    }

    private func prepare(book: Runbook? = nil) {
        guard canPrepare || book != nil else { return }
        store.composerText = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        store.composerSource = nil
        store.composerRunbookID = book?.id ?? ""
        store.composerProjectID = selectedProject?.id ?? ""
        store.showComposer = true
    }
}

struct RunbookStartButton: View {
    let book: Runbook
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: book.symbol).accessibilityHidden(true)
                Text(book.name)
            }
            .font(.system(size: 11, weight: .medium)).foregroundStyle(FrondaTheme.accent)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(FrondaTheme.accent.opacity(0.07), in: Capsule())
            .fixedSize()
        }
        .buttonStyle(.plain)
        .help("Preparar tarefa com o fluxo \(book.name)")
        .accessibilityLabel("Usar fluxo \(book.name)")
        .accessibilityRemoveTraits(.isSelected)
    }
}
