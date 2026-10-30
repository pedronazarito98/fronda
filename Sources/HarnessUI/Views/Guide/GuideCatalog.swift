import Foundation

struct GuideTopic: Identifiable {
    struct Step: Identifiable {
        let title: String
        let text: String
        var id: String { title }
    }
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let action: String
    let steps: [Step]

    static let topics = [
        GuideTopic(
            id: "providers", title: "Conectar meu executor", subtitle: "Codex ou Claude Code neste Mac",
            symbol: "terminal", action: "Abrir conexões",
            steps: [
                Step(
                    title: "Use sua instalação",
                    text:
                        "Em Ajustes → Providers, confirme o executável do Codex ou do Claude Code. Conectar verifica a instalação e a autenticação."
                ),
                Step(
                    title: "Entre pela ferramenta oficial",
                    text:
                        "Se aparecer autenticação pendente, use o comando indicado no Terminal. Volte e conecte novamente."
                ),
                Step(
                    title: "Escolha o que trazer",
                    text:
                        "A conexão abre uma revisão do contexto local. Você decide quais itens importar; pode voltar a essa revisão depois."
                ),
            ]),
        GuideTopic(
            id: "context", title: "Trazer minhas skills e regras", subtitle: "Escolha seu contexto com checkboxes",
            symbol: "tray.and.arrow.down", action: "Escolher contexto",
            steps: [
                Step(
                    title: "Escolha a origem",
                    text:
                        "Busque as configurações deste usuário ou inclua um projeto cadastrado. Cada item mostra sua origem."
                ),
                Step(
                    title: "Confira a prévia",
                    text:
                        "Clique no item para ler o conteúdo. Marque apenas o que deseja importar. Se houver mais de um padrão de modelo, escolha um."
                ),
                Step(
                    title: "Revise as ferramentas",
                    text:
                        "MCPs chegam desativados. Em Extensões, descubra as ferramentas, escolha permissões e habilite a conexão. Regras entram no contexto; skills são lidas sob demanda."
                ),
            ]),
        GuideTopic(
            id: "models", title: "Escolher modelo e esforço", subtitle: "Um executor para cada parte do trabalho",
            symbol: "cpu", action: "Configurar uma tarefa",
            steps: [
                Step(
                    title: "Comece pelo tamanho do problema",
                    text:
                        "Na nova tarefa, escolha modelo e esforço. Ajustes pontuais costumam pedir menos raciocínio; investigações com muitas dependências podem precisar de mais."
                ),
                Step(
                    title: "Personalize os agentes por etapa",
                    text:
                        "Abra Modelo e esforço na tarefa. Expanda investigação, implementação ou revisão para escolher outro provider, modelo ou esforço. Cada etapa abre uma tentativa própria."
                ),
                Step(
                    title: "Confira o consumo",
                    text:
                        "O teto de tokens pertence à tarefa inteira. Mais esforço pode aumentar o consumo. Alterações de configuração pedem uma nova revisão do contexto; pause a tarefa antes de trocar."
                ),
            ]),
        GuideTopic(
            id: "first-task", title: "Criar minha primeira tarefa", subtitle: "Do objetivo ao contexto aprovado",
            symbol: "square.and.pencil", action: "Criar tarefa",
            steps: [
                Step(
                    title: "Escolha um repositório",
                    text:
                        "Adicione uma pasta com Git e pelo menos um commit. O Fronda usa uma worktree isolada para preservar seu checkout."
                ),
                Step(
                    title: "Descreva um resultado observável",
                    text:
                        "Por exemplo: corrigir o botão Salvar para desabilitar durante o envio. Acrescente critérios que você consiga conferir."
                ),
                Step(
                    title: "Prepare e aprove",
                    text:
                        "Escolha o fluxo, o executor e o orçamento. Crie a tarefa, confira o contexto e autorize o envio. A implementação também depende da aprovação do plano."
                ),
            ]),
        GuideTopic(
            id: "review", title: "Revisar antes de entregar", subtitle: "Diff, validação e evidências no mesmo lugar",
            symbol: "checkmark.seal", action: "Abrir minhas tarefas",
            steps: [
                Step(
                    title: "Siga o percurso da tarefa",
                    text:
                        "Clique nas etapas para conferir diagnóstico, plano, arquivos, validações e revisão. O próximo passo indica quando a tarefa depende de você."
                ),
                Step(
                    title: "Confira a evidência",
                    text:
                        "Leia o diff e os resultados dos comandos. Capturas e relatórios precisam corresponder ao snapshot atual. Ausência de evidência aparece como pendência."
                ),
                Step(
                    title: "Decida a entrega",
                    text:
                        "Commit, push e publicação têm propostas próprias para você revisar e confirmar. O histórico preserva as tentativas anteriores."
                ),
            ]),
        GuideTopic(
            id: "shortcuts", title: "Encontrar e retomar rápido", subtitle: "Busca, janelas e atalhos do Mac",
            symbol: "command", action: "Abrir busca",
            steps: [
                Step(
                    title: "⌘K · buscar e agir",
                    text:
                        "Encontre tarefas, projetos, fluxos e comandos. Digite parte do nome e pressione Return para abrir."
                ),
                Step(
                    title: "⌘N · começar uma tarefa",
                    text:
                        "Crie uma tarefa de qualquer lugar. Use ⇧⌘N para adicionar um projeto e ⌘1 para voltar à visão geral."
                ),
                Step(
                    title: "⌥⌘F · focar no trabalho",
                    text:
                        "Em uma tarefa, ative o modo foco. Use ⌃⌘I para conferir os detalhes e ⌥⌘Return para abrir a tarefa em outra janela."
                ),
            ]),
    ]
}
