import SwiftUI

struct MascotCompanionPopover: View {
    let store: AppStore
    @Bindable var companion: MascotCompanionController
    private var activities: [MascotActivity] { store.mascotActivities }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Por aqui com você.").font(.headline)
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    companion.enabled = false
                } label: {
                    Image(systemName: "eye.slash")
                }
                .buttonStyle(.plain).help("Ocultar companheiro — reabra pelo menu Fronda")
                .accessibilityLabel("Ocultar companheiro").accessibilityIdentifier("mascot.hide")
            }
            if !store.connected {
                Label("Desconectado · último estado recebido", systemImage: "wifi.slash")
                    .font(.caption2).foregroundStyle(FrondaTheme.warning)
            }
            if let error = store.externalSessionError {
                Label(error, systemImage: "clock.badge.exclamationmark")
                    .font(.caption2).foregroundStyle(FrondaTheme.warning)
            }
            if activities.isEmpty {
                Text("Suas tarefas aparecem aqui quando você começar um trabalho.")
                    .font(.callout).foregroundStyle(.secondary).padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(activities.prefix(8).enumerated()), id: \.element.id) { index, activity in
                            MascotActivityRow(activity: activity, prominent: index == 0) {
                                companion.openActivity(activity)
                            }
                        }
                    }
                }.scrollIndicators(.hidden)
                    .frame(
                        height: min(280, CGFloat(min(8, activities.count)) * 124))
            }
            HStack {
                Button("Nova tarefa", systemImage: "plus") { companion.newTask() }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier("mascot.new-task")
                    .disabled(store.showComposer || store.showPalette)
                Spacer()
                Button("Abrir Fronda", systemImage: "arrow.up.right.square") { companion.open() }
                    .buttonStyle(.plain).font(.caption).accessibilityIdentifier("mascot.open-app")
            }
            Divider()
            HStack {
                Button("Ver sessões") { companion.showSessions() }
                Spacer()
                Button("Decisões") { companion.open("decisions") }
            }.buttonStyle(.plain).font(.caption).foregroundStyle(FrondaTheme.accent)
            Button(store.firstTaskJourney.entryTitle, systemImage: "leaf") { companion.startJourney() }
                .buttonStyle(.plain).font(.caption).foregroundStyle(FrondaTheme.accent)
                .disabled(store.showComposer || store.showPalette || !store.connected)
                .accessibilityIdentifier("mascot.guide")
            DisclosureGroup("Ajustar companheiro") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Animar mascote", isOn: $companion.animationsEnabled).toggleStyle(.switch)
                    HStack {
                        Text("Tamanho")
                        Slider(value: $companion.size, in: 112...240, step: 8).accessibilityLabel(
                            "Tamanho do companheiro")
                    }
                    Button("Restaurar posição") { companion.resetPosition() }
                        .buttonStyle(.plain).foregroundStyle(FrondaTheme.accent)
                }.font(.caption).padding(.top, 10)
            }.font(.caption).foregroundStyle(.secondary)
        }
        .padding(20).frame(width: 350).tint(FrondaTheme.accent)
        .preferredColorScheme(store.colorScheme)
    }

    private var status: String {
        guard let activity = activities.first else { return "Tudo tranquilo" }
        switch activity.state {
        case .attention: return activity.priority == 0 ? "Uma decisão precisa de você" : "Há um resultado para conferir"
        case .error: return "Vamos conferir o que aconteceu"
        case .success: return "Um resultado está pronto para revisar"
        case .working: return "O trabalho está acontecendo"
        default: return "Seus trabalhos estão por aqui"
        }
    }
}
