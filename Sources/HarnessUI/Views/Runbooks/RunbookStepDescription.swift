import HarnessDomain
import SwiftUI

struct RunbookStepDescription {
    let book: Runbook
    let step: RunbookStep

    var symbol: String {
        switch step.kind {
        case "context": "doc.text.magnifyingglass"
        case "investigation": "magnifyingglass"
        case "reproduction": "arrow.counterclockwise"
        case "plan": "list.bullet.clipboard"
        case "implementation": "hammer"
        case "validation": "checkmark.shield"
        case "verification": "viewfinder"
        case "review": "eye"
        case "evidence": "doc.richtext"
        default: "circle.dotted"
        }
    }

    var tint: Color {
        ["plan", "review", "evidence"].contains(step.kind) ? FrondaTheme.clay : FrondaTheme.accent
    }

    var condition: String {
        switch step.condition {
        case "always":
            step.dependencies.isEmpty
                ? "Pode começar sem esperar outra etapa." : "Executa depois que as dependências terminarem."
        case "on_pass": "Executa somente se todas as dependências passarem."
        case "on_failure": "Executa quando uma dependência falhar ou estiver bloqueada."
        case "has_changes": "Executa somente quando houver alterações no projeto."
        default: "A condição desta etapa precisa ser corrigida no editor."
        }
    }

    var purpose: String {
        switch step.kind {
        case "context": "Seleciona arquivos e escopo para você conferir antes de autorizar o envio ao executor."
        case "investigation": "Examina o fluxo real do projeto e registra o diagnóstico que fundamenta a proposta."
        case "reproduction":
            "Registra como o problema acontece, o resultado esperado e o comportamento observado antes da correção."
        case "plan": "Organiza a proposta, os arquivos envolvidos e os critérios para você revisar antes de seguir."
        case "implementation":
            book.mode.writes
                ? "Executa o trabalho aprovado e registra as alterações no espaço isolado da tarefa."
                : "Aprofunda a análise em modo de leitura e registra o resultado da investigação."
        case "validation": "Executa os comandos de validação autorizados e vincula os resultados à revisão do código."
        case "verification":
            "Confere o cenário real depois da implementação e registra evidências do comportamento observado."
        case "review": "Examina as alterações de forma independente e preserva os achados para a sua decisão."
        case "evidence": "Reúne critérios, resultados e artefatos para você conferir a entrega."
        default: "Etapa personalizada. Confira o tipo e as condições no editor antes de usar o fluxo."
        }
    }
}
