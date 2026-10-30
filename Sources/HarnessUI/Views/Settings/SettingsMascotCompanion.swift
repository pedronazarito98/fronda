import SwiftUI

struct SettingsMascotCompanion: View {
    @Bindable var companion: MascotCompanionController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Mini companheiro Fronda", isOn: $companion.enabled)
                .toggleStyle(.switch).accessibilityIdentifier("settings.mascot-enabled")
            Text("O mascote acompanha seu trabalho na mesa. Clique para ver tarefas ou arraste para mudar de lugar.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("Tamanho").font(.caption)
                Slider(value: $companion.size, in: 112...240, step: 8)
                    .accessibilityLabel("Tamanho do companheiro").accessibilityIdentifier("settings.mascot-size")
                Text("\(Int(companion.size))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Toggle("Animar mascote", isOn: $companion.animationsEnabled).toggleStyle(.checkbox)
                .accessibilityIdentifier("settings.mascot-animate")
            HStack {
                Button("Mostrar tarefas") { companion.showActions() }
                Button("Restaurar posição") { companion.resetPosition() }
            }
            Text("Respeita Reduzir Movimento do macOS e pausa quando está oculto.")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(.vertical, 6)
    }
}
