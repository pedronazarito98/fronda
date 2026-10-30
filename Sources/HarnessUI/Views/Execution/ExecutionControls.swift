import HarnessDomain
import SwiftUI

struct ExecutionControls: View {
    @Binding var configuration: ExecutionConfiguration
    let provider: ProviderKind
    var models: [ProviderModel] = []
    var defaultLabel = "Padrão do provider"
    var inheritedModel: String?
    @State private var customModel = false

    private var selectedModel: ProviderModel? { models.first { $0.id == (configuration.model ?? inheritedModel) } }
    private var efforts: [String] {
        let available = selectedModel?.efforts ?? ["low", "medium", "high"]
        if let current = configuration.effort, !available.contains(current) { return available + [current] }
        return available
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Picker("Modelo", selection: modelBinding) {
                    Text(defaultLabel).tag("")
                    ForEach(models) { model in Text(model.name.isEmpty ? model.id : model.name).tag(model.id) }
                    if let model = configuration.model, !models.contains(where: { $0.id == model }) {
                        Text(model).tag(model)
                    }
                }.accessibilityIdentifier("execution.model")
                Button("Outro…") { customModel.toggle() }.font(.caption).help("Informar o identificador do modelo")
            }
            if customModel {
                TextField("Identificador do modelo", text: modelBinding).textFieldStyle(.roundedBorder)
            }
            Picker(
                "Esforço",
                selection: Binding(
                    get: { configuration.effort ?? "" }, set: { configuration.effort = $0.isEmpty ? nil : $0 })
            ) {
                Text("Herdar padrão").tag("")
                ForEach(efforts, id: \.self) { Text(Self.effortLabel($0)).tag($0) }
            }.accessibilityIdentifier("execution.effort")
            if let model = selectedModel, !model.detail.isEmpty {
                Text(model.detail).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }
            Text(effortHint).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.pickerStyle(.menu)
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { configuration.model ?? "" },
            set: {
                configuration.model = $0.isEmpty ? nil : $0
                configuration.effort = nil
            })
    }

    private var effortHint: String {
        switch configuration.effort {
        case "none", "minimal", "low":
            "Para ajustes curtos e bem definidos. Revise o resultado antes de ampliar o escopo."
        case "high", "xhigh", "max", "ultra":
            "Mais raciocínio pode consumir mais tokens. Reserve para problemas que exigem investigação."
        case "medium": "Um ponto de partida para tarefas com complexidade moderada."
        default: "O padrão pode variar por modelo e conta. O teto de tokens da tarefa continua valendo."
        }
    }

    static func effortLabel(_ effort: String) -> String {
        switch effort {
        case "none": "Sem raciocínio adicional"
        case "minimal": "Mínimo"
        case "low": "Baixo · tarefas pontuais"
        case "medium": "Médio · uso cotidiano"
        case "high": "Alto · investigação"
        case "xhigh": "Muito alto"
        case "max": "Máximo"
        case "ultra": "Ultra"
        default: effort
        }
    }
}
