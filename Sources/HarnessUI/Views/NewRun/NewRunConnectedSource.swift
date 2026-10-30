import HarnessDomain
import SwiftUI

struct NewRunConnectedSource: View {
    @Binding var draft: NewRunDraft
    let canFetch: Bool
    let fetching: Bool
    let fetchSource: () -> Void
    var focusedField: FocusState<NewRunField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Fonte \((draft.sourcePreview?.intent.kind ?? draft.sourceKind).rawValue)", systemImage: "link")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(FrondaTheme.accent)
                Spacer()
                if draft.sourceKind != .text {
                    Button(fetching ? "Lendo fonte…" : "Ler fonte conectada", action: fetchSource)
                        .controlSize(.small).disabled(!canFetch || fetching)
                        .focused(focusedField, equals: .source)
                }
            }
            Text("Ao ler novamente, o contexto será substituído pelo conteúdo atualizado da fonte.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if draft.sourceKind != .text {
                TextField("IDs de comentários autorizados, separados por vírgula", text: $draft.commentIDs)
                    .textFieldStyle(.roundedBorder).font(.system(size: 11))
                    .help("Comentários só são importados quando seus IDs são informados aqui.")
            }
            if let preview = draft.sourcePreview, !preview.attachments.isEmpty {
                DisclosureGroup("Anexos disponíveis no Jira · \(preview.attachments.count)") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(preview.attachments) { attachment in
                            Toggle(
                                "\(attachment.name) · \(ByteCountFormatter.string(fromByteCount: Int64(max(0, attachment.size)), countStyle: .file))",
                                isOn: remoteSelection(attachment.id)
                            ).font(.system(size: 11)).toggleStyle(.checkbox)
                        }
                    }.padding(.top, 8)
                }.font(.system(size: 11, weight: .medium))
            }
            if draft.sourceNeedsRefresh {
                Label(
                    draft.sourceKind == .text
                        ? "O objetivo mudou. Desvincule a fonte para continuar com o contexto como texto."
                        : "A seleção mudou. Leia a fonte novamente para conferir o conteúdo escolhido.",
                    systemImage: "arrow.clockwise"
                ).font(.system(size: 11)).foregroundStyle(FrondaTheme.warning).fixedSize(
                    horizontal: false, vertical: true)
            }
            if draft.sourcePreview != nil {
                if draft.sourceKind == .text {
                    detachButton.focused(focusedField, equals: .source)
                } else {
                    detachButton
                }
            }
        }
    }

    private var detachButton: some View {
        Button("Desvincular fonte") {
            draft.sourcePreview = nil
            draft.fetchedSignature = ""
            draft.remoteAttachmentIDs.removeAll()
        }.buttonStyle(.link).font(.system(size: 11))
            .help("Mantém o contexto visível e remove o vínculo com a leitura da fonte.")
    }

    private func remoteSelection(_ id: String) -> Binding<Bool> {
        Binding(
            get: { draft.remoteAttachmentIDs.contains(id) },
            set: { selected in
                if selected {
                    draft.remoteAttachmentIDs.insert(id)
                } else {
                    draft.remoteAttachmentIDs.remove(id)
                }
            })
    }
}
