enum ProjectSettingsSection: String, CaseIterable, Identifiable {
    case access, permissions, context, validation

    var id: Self { self }
    var title: String {
        switch self {
        case .access: "Acesso"
        case .permissions: "Permissões"
        case .context: "Contexto"
        case .validation: "Comandos"
        }
    }
    var symbol: String {
        switch self {
        case .access: "folder.badge.gearshape"
        case .permissions: "lock.shield"
        case .context: "text.viewfinder"
        case .validation: "checkmark.rectangle.stack"
        }
    }
    var summary: String {
        switch self {
        case .access: "Pasta do projeto"
        case .permissions: "Executores e escopo"
        case .context: "Índice e relevância"
        case .validation: "Catálogo de validação"
        }
    }
    var detail: String {
        switch self {
        case .access: "Confira a pasta usada pelas tarefas e renove a autorização de acesso quando necessário."
        case .permissions: "Defina quais executores podem trabalhar aqui e os limites das alterações."
        case .context: "Ajuste quais arquivos entram no índice e o que ganha prioridade ao preparar uma tarefa."
        case .validation: "Revise os comandos literais disponíveis para validar as tarefas deste projeto."
        }
    }
}
