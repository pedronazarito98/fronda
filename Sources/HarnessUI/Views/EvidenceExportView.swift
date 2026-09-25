import HarnessDomain
import SwiftUI

struct EvidenceExportView: View {
    var store: AppStore
    let run: Run
    @Environment(\.dismiss) private var dismiss
    @State private var options = EvidenceExportOptions()
    @State private var working = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Exportar evidências").font(.title2.weight(.semibold))
            Text("O pacote será salvo neste Mac. Escolha os dados que deseja incluir antes de compartilhá-lo.").font(
                .callout
            ).foregroundStyle(.secondary)
            Toggle("Incluir descrições, nomes de arquivos e resultados", isOn: $options.includeText)
            Toggle("Incluir código alterado no diff", isOn: $options.includeDiff).disabled(!options.includeText)
            Toggle(
                "Incluir imagens e vídeos locais",
                isOn: Binding(get: { options.includeMedia == true }, set: { options.includeMedia = $0 })
            ).disabled(!options.includeText)
            Toggle("Incluir histórico de eventos", isOn: $options.includeEvents)
            if !options.includeText {
                Label(
                    "Somente IDs, hashes, estados e contagens. Textos livres, caminhos, comandos, outputs e código serão omitidos.",
                    systemImage: "eye.slash"
                ).font(.caption)
            }
            GroupBox("Arquivos do pacote") {
                VStack(alignment: .leading, spacing: 7) {
                    Text("manifest.json · hashes e revisão")
                    Text("report.md · \(options.includeText ? "relatório da run" : "resumo de metadados")")
                    Text(
                        "trace.json · \(options.includeText ? "vínculos e trechos de validação" : "vínculos sem textos livres")"
                    )
                    if options.includeDiff && options.includeText {
                        Text("diff.patch · código alterado, com redação de segredos reconhecidos")
                    }
                    if options.includeEvents {
                        Text(
                            "events.json · \(options.includeText ? "eventos e suas mensagens" : "IDs, tipos e revisões dos eventos")"
                        )
                    }
                }.font(.caption.monospaced()).frame(maxWidth: .infinity, alignment: .leading).padding(6)
            }
            Text(
                "Credenciais e sessões dos providers não entram no pacote. Revise textos livres antes de compartilhar; a redação automática não identifica todos os dados pessoais."
            ).font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(working ? "Exportando…" : "Salvar pacote local") { export() }.buttonStyle(.borderedProminent)
                    .disabled(working).keyboardShortcut(.defaultAction)
            }
        }.padding(28).frame(width: 580)
    }
    private func export() {
        working = true
        error = nil
        var request = RPCRequest("evidence.export")
        request.id = run.id
        request.exportOptions = options
        Task {
            do {
                let response = try await store.send(request)
                store.reveal(response.path)
                await store.refresh()
                dismiss()
            } catch { self.error = error.localizedDescription }
            working = false
        }
    }
}
