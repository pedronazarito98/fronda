import HarnessDomain
import SwiftUI

struct NewRunSourceSection: View {
    @Binding var draft: NewRunDraft
    let canFetch: Bool
    let fetching: Bool
    let fetchSource: () -> Void
    var focusedField: FocusState<NewRunField?>.Binding
    @State private var contextExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            objective
            if draft.sourceKind != .text || draft.sourcePreview != nil {
                NewRunConnectedSource(
                    draft: $draft, canFetch: canFetch, fetching: fetching, fetchSource: fetchSource,
                    focusedField: focusedField
                )
                .padding(15)
                .background(FrondaTheme.accent.opacity(0.05), in: RoundedRectangle(cornerRadius: 13))
                .id(NewRunField.source)
            }
            Divider()
            criteria
            Divider()
            DisclosureGroup(isExpanded: $contextExpanded) {
                TextField(
                    "Decisões já tomadas, restrições e detalhes importantes…", text: $draft.context, axis: .vertical
                )
                .textFieldStyle(.plain).lineLimit(4...8).font(.system(size: 13))
                .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 10)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Contexto adicional", systemImage: "text.alignleft").font(
                        .system(size: 12, weight: .semibold))
                    if !contextExpanded {
                        Text(draft.context.isEmpty ? "Inclua o que o executor precisa saber" : draft.context)
                            .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
            .padding(.vertical, 3)
            NewRunAttachments(paths: $draft.attachments)
        }
        .onAppear {
            contextExpanded = !draft.context.isEmpty
            focusedField.wrappedValue = .objective
        }
        .onChange(of: draft.context) { oldValue, value in
            if oldValue.isEmpty && !value.isEmpty { contextExpanded = true }
        }
    }

    private var objective: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("O que vamos fazer?").font(.system(size: 16, weight: .semibold)).tracking(-0.2)
                Spacer()
                Text("Obrigatório").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            TextField("Descreva o resultado que você quer alcançar…", text: $draft.title, axis: .vertical)
                .font(.system(size: 21)).textFieldStyle(.plain).lineLimit(3...6)
                .focused(focusedField, equals: .objective).accessibilityIdentifier("composer.objective")
                .padding(.vertical, 8).frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            Text("Pode ser uma descrição, um PR do GitHub ou uma issue do Jira.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }.id(NewRunField.objective).guideTarget(.objective)
    }

    private var criteria: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Como saberemos que está pronto?", systemImage: "checklist")
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 5)
                if !draft.criteriaLines.isEmpty {
                    Text("\(draft.criteriaLines.count)").font(.system(size: 10, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(FrondaTheme.accent).padding(.horizontal, 7).padding(.vertical, 3)
                        .background(FrondaTheme.accent.opacity(0.08), in: Capsule())
                }
            }
            TextField(
                "Um resultado verificável por linha. Você pode completar depois.", text: $draft.criteria,
                axis: .vertical
            )
            .textFieldStyle(.plain).lineLimit(2...6).font(.system(size: 13))
            .accessibilityIdentifier("composer.criteria")
            .focused(focusedField, equals: .criteria)
            .padding(.vertical, 5).frame(maxWidth: .infinity, alignment: .leading)
        }.id(NewRunField.criteria).guideTarget(.criteria)
    }
}
