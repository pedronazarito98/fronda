import HarnessDomain
import SwiftUI

struct RunbookEditorView: View {
    var store: AppStore
    @State var book: Runbook
    var onSaved: (String) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var section = RunbookEditorSection.configuration
    @State private var selectedStepID: String?
    @State private var saving = false
    @State private var saveError: String?

    private var validation: RunbookEditorValidation { RunbookEditorValidation(book: book) }
    private var isNew: Bool { !store.snapshot.runbooks.contains { $0.id == book.id } }

    var body: some View {
        VStack(spacing: 0) {
            header
            Picker("Área do editor", selection: $section) {
                ForEach(RunbookEditorSection.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented).labelsHidden().disabled(saving)
            .padding(.horizontal, 22).padding(.bottom, 15)
            .accessibilityIdentifier("runbook-editor.section")
            Divider()
            editor.frame(maxWidth: .infinity, maxHeight: .infinity).disabled(saving)
            Divider()
            footer
        }
        .frame(width: 760, height: 640)
        .background(FrondaTheme.canvas).tint(FrondaTheme.accent)
        .interactiveDismissDisabled(saving)
        .onChange(of: book) { _, _ in saveError = nil }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: book.symbol).font(.system(size: 19))
                .foregroundStyle(FrondaTheme.accent).frame(width: 35, height: 35)
                .background(FrondaTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(isNew ? "Criar fluxo" : "Editar fluxo").font(.system(size: 19, weight: .semibold))
                Text(book.name.isEmpty ? "Dê um nome ao seu fluxo" : book.name)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 10)
            if saving { ProgressView().controlSize(.small).accessibilityLabel("Salvando fluxo") }
            Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction).disabled(saving)
            Button(saving ? "Salvando…" : isNew ? "Criar fluxo" : "Salvar revisão", action: save)
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                .disabled(saving || !store.connected || validation.issue != nil)
                .accessibilityIdentifier("runbook-editor.save")
        }.padding(22)
    }

    @ViewBuilder private var editor: some View {
        switch section {
        case .configuration:
            RunbookConfigurationEditor(book: $book)
        case .steps:
            RunbookStepsEditor(book: $book, selectedStepID: $selectedStepID)
        case .validations:
            ScrollView {
                ValidationCommandsEditor(
                    commands: Binding(get: { book.validationCommands ?? [] }, set: { book.validationCommands = $0 }),
                    scope: .runbook
                ).padding(24)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let saveError {
                Label(saveError, systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(FrondaTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 14) {
                if let issue = validation.issue {
                    Label(issue, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(FrondaTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Revisar") {
                        section =
                            book.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .configuration : .steps
                    }.controlSize(.small)
                } else {
                    Label(
                        "Estrutura válida · \(book.steps.count) \(book.steps.count == 1 ? "etapa" : "etapas")",
                        systemImage: "checkmark.circle"
                    )
                    .font(.caption).foregroundStyle(FrondaTheme.success)
                    Spacer(minLength: 0)
                    Text(isNew ? "Novo fluxo" : "Revisão atual \(book.version)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            if !store.connected {
                Text("Conecte ao coordenador para salvar o fluxo.")
                    .font(.caption).foregroundStyle(FrondaTheme.warning)
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrondaTheme.surface)
    }

    private func save() {
        guard !saving else { return }
        do {
            _ = try book.orderedSteps()
            var request = RPCRequest("runbook.save")
            request.runbook = book
            let command = request
            saveError = nil
            saving = true
            Task {
                defer { saving = false }
                do {
                    _ = try await store.send(command)
                    await store.refresh(silent: true)
                    onSaved(book.id)
                    dismiss()
                } catch {
                    saveError = error.localizedDescription
                }
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
