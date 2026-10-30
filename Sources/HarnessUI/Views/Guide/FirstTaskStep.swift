enum FirstTaskStep: String, Codable, CaseIterable {
    case project, flow, executor, objective, criteria, prepare, context

    var number: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
    var title: String {
        switch self {
        case .project: "Onde vamos criar?"
        case .flow: "Escolha o caminho"
        case .executor: "Quem vai ajudar?"
        case .objective: "Dê uma direção clara"
        case .criteria: "Como reconhecer o resultado?"
        case .prepare: "Vamos preparar o contexto"
        case .context: "Confira antes de autorizar"
        }
    }
    var explanation: String {
        switch self {
        case .project:
            "Escolha o projeto desta tarefa. Se ele ainda não estiver aqui, use o + para adicionar sua pasta Git."
        case .flow:
            "O fluxo define as etapas do trabalho. Confira o percurso à direita e escolha o que combina com seu objetivo."
        case .executor:
            "Escolha Codex ou Claude Code. Modelo e esforço ficam à direita. Você pode preparar agora e conectar o executor antes de executar."
        case .objective:
            "Descreva o resultado que você quer alcançar e onde ele deve aparecer. Termine de escrever e saia do campo para continuar."
        case .criteria:
            "Escreva um resultado verificável por linha. Por exemplo: a busca encontra tarefas pelo título. Esta orientação é opcional."
        case .prepare:
            "Confira suas escolhas e clique em Criar e preparar contexto. Vou esperar a confirmação da tarefa; sua autorização para o executor continua separada."
        case .context:
            "Confira os arquivos selecionados e o payload. Só depois autorize o envio pelo fluxo normal da tarefa. A jornada não aprova nada por você."
        }
    }
    var confirmation: String? {
        switch self {
        case .project: "Usar este projeto"
        case .flow: "Usar este fluxo"
        case .executor: "Usar este executor"
        case .objective: "Objetivo definido"
        case .criteria: "Critérios definidos"
        case .prepare, .context: nil
        }
    }
    var field: NewRunField? {
        switch self {
        case .project: .project
        case .flow: .flow
        case .objective: .objective
        case .criteria: .criteria
        default: nil
        }
    }
}
