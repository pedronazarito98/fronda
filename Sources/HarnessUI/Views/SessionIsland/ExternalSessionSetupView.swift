import AppKit
import HarnessInfrastructure
import SwiftUI

struct ExternalSessionSetupView: View {
    @State private var result = ""
    private var helper: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/harness").path
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Conectar sessões externas").font(.headline)
            HStack {
                Button("Configurar hooks do Codex") { configureCodex(enabled: true) }
                Button("Remover hooks do Harness") { configureCodex(enabled: false) }
            }
            if !result.isEmpty { Text(result).font(.caption).foregroundStyle(.secondary) }
            Text(
                "No Codex, configure os hooks e autorize em /hooks. Para Claude, use o comando abaixo no terminal do projeto. Sessões já abertas precisam ser retomadas com a integração."
            )
            .font(.caption).foregroundStyle(.secondary)
            ForEach(["codex", "claude"], id: \.self) { provider in
                let command = "'" + helper.replacingOccurrences(of: "'", with: "'\\''") + "' watch " + provider
                HStack {
                    Text(command).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                        .lineLimit(3)
                    Spacer()
                    Button("Copiar") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(command, forType: .string)
                    }.help("Copiar comando para \(provider)")
                }
            }
            Text(
                "A integração recebe só estado, projeto e horário. Não importa conversas. Aprovações e controles das sessões externas continuam no provider."
            )
            .font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 8)
    }

    private func configureCodex(enabled: Bool) {
        do {
            try CodexIslandHooks.configure(executable: helper, root: nil, enabled: enabled)
            result =
                enabled
                ? "Configurado. Abra /hooks no Codex para revisar e autorizar; depois retome a sessão."
                : "Hooks do Harness removidos."
        } catch { result = "Não foi possível alterar os hooks. Use o comando no terminal para verificar." }
    }
}
