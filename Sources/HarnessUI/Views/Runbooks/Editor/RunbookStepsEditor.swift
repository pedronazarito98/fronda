import HarnessDomain
import SwiftUI

struct RunbookStepsEditor: View {
    @Binding var book: Runbook
    @Binding var selectedStepID: String?
    @State private var removalIssue: String?
    @State private var additionNotice: String?

    private var validation: RunbookEditorValidation { RunbookEditorValidation(book: book) }
    private var selectedStep: RunbookStep? {
        book.steps.first { $0.id == selectedStepID } ?? validation.orderedSteps.first
    }

    var body: some View {
        HStack(spacing: 0) {
            stepList.frame(width: 214)
            Divider()
            if let step = selectedStep {
                RunbookStepEditor(
                    step: Binding(
                        get: { book.steps.first { $0.id == step.id } ?? step },
                        set: { value in
                            if let index = book.steps.firstIndex(where: { $0.id == value.id }) {
                                book.steps[index] = value
                            }
                        }),
                    book: book, steps: validation.orderedSteps, remove: { remove(step) }
                ).id(step.id)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "point.3.connected.trianglepath.dotted").font(.title)
                        .foregroundStyle(FrondaTheme.accent)
                    Text("Defina a primeira etapa").font(.headline)
                    Text("Use Adicionar etapa para começar seu percurso.")
                        .font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if selectedStepID == nil { selectedStepID = selectedStep?.id }
        }
        .alert(
            "Esta etapa tem dependentes",
            isPresented: Binding(get: { removalIssue != nil }, set: { if !$0 { removalIssue = nil } })
        ) {
            Button("Entendi") { removalIssue = nil }
        } message: {
            Text(removalIssue ?? "")
        }
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Etapas").font(.callout.weight(.semibold))
                Spacer()
                Text(book.steps.count.formatted()).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }.padding(16)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(Array(validation.orderedSteps.enumerated()), id: \.element.id) { index, step in
                            stepButton(step, number: index + 1).id(step.id)
                        }
                    }.padding(.horizontal, 8).padding(.bottom, 12)
                }
                .onChange(of: selectedStep?.id) { _, id in
                    if let id { proxy.scrollTo(id, anchor: .center) }
                }
                .onChange(of: validation.orderedSteps.map(\.id)) { _, _ in
                    if let id = selectedStep?.id { proxy.scrollTo(id, anchor: .center) }
                }
                .onAppear { if let id = selectedStep?.id { proxy.scrollTo(id, anchor: .center) } }
            }
            Divider()
            VStack(alignment: .leading, spacing: 9) {
                Menu {
                    ForEach(StepKind.allCases, id: \.rawValue) { kind in
                        Button(RunbookEditorStepLabels.title(for: kind)) { add(kind) }
                    }
                } label: {
                    Label("Adicionar etapa", systemImage: "plus")
                }.accessibilityIdentifier("runbook-editor.add-step")
                if let additionNotice {
                    Text(additionNotice).font(.caption2).foregroundStyle(.secondary).lineLimit(3)
                }
            }.padding(12)
        }.background(FrondaTheme.surface.opacity(0.5))
    }

    private func stepButton(_ step: RunbookStep, number: Int) -> some View {
        let selected = step.id == selectedStep?.id
        return Button {
            selectedStepID = step.id
        } label: {
            HStack(spacing: 9) {
                Text(number.formatted()).font(.system(size: 10, weight: .medium, design: .monospaced))
                    .frame(width: 24, height: 24)
                    .background(FrondaTheme.accent.opacity(0.1), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title.isEmpty ? "Etapa sem nome" : step.title)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium)).lineLimit(2)
                    Text(RunbookEditorStepLabels.title(for: step.kind))
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(9).frame(maxWidth: .infinity, alignment: .leading)
                .background(selected ? FrondaTheme.accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 9))
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(selected ? FrondaTheme.accent.opacity(0.3) : .clear, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Etapa \(number): \(step.title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityRemoveTraits(selected ? [] : .isSelected)
        .accessibilityIdentifier("runbook-editor.step." + step.id)
    }

    private func add(_ kind: StepKind) {
        let predecessor = selectedStep
        var step = RunbookStep(title: RunbookEditorStepLabels.title(for: kind), kind: kind.rawValue)
        if let predecessor { step.dependencies = [predecessor.id] }
        book.steps.append(step)
        selectedStepID = step.id
        additionNotice =
            predecessor.map { "Conectada a “\($0.title)”. Ajuste em Depende de." }
            ?? "Primeira etapa adicionada."
    }

    private func remove(_ step: RunbookStep) {
        let dependents = book.steps.filter { $0.id != step.id && $0.dependencies.contains(step.id) }
        guard dependents.isEmpty else {
            removalIssue =
                "“\(step.title)” é usada por: \(dependents.map(\.title).joined(separator: ", ")). Desmarque essa dependência nessas etapas antes de excluir."
            return
        }
        let index = validation.orderedSteps.firstIndex { $0.id == step.id } ?? 0
        book.steps.removeAll { $0.id == step.id }
        let remaining = RunbookEditorValidation(book: book).orderedSteps
        selectedStepID = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
        additionNotice = nil
    }
}
