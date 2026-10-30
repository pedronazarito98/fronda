import HarnessDomain

enum RunbookEditorSection: String, CaseIterable, Identifiable {
    case configuration = "Configuração"
    case steps = "Etapas"
    case validations = "Validações"

    var id: String { rawValue }
}

struct RunbookEditorValidation {
    let orderedSteps: [RunbookStep]
    let issue: String?

    init(book: Runbook) {
        do {
            orderedSteps = try book.orderedSteps()
            issue = nil
        } catch {
            orderedSteps = book.steps
            issue = error.localizedDescription
        }
    }

    static func createsCycle(stepID: String, dependencyID: String, steps: [RunbookStep]) -> Bool {
        var pending = [dependencyID]
        var visited = Set<String>()
        while let id = pending.popLast() {
            if id == stepID { return true }
            guard visited.insert(id).inserted else { continue }
            pending += steps.first { $0.id == id }?.dependencies ?? []
        }
        return false
    }
}

enum RunbookEditorStepLabels {
    static func title(for kind: StepKind) -> String {
        switch kind {
        case .context: "Contexto"
        case .investigation: "Investigação"
        case .reproduction: "Reprodução"
        case .plan: "Plano"
        case .implementation: "Implementação"
        case .validation: "Validação"
        case .verification: "Verificação do cenário"
        case .review: "Revisão"
        case .evidence: "Evidências"
        }
    }

    static func title(for rawValue: String) -> String {
        StepKind(rawValue: rawValue).map { title(for: $0) } ?? "Tipo não reconhecido"
    }

    static func workKind(_ kind: WorkKind) -> String {
        kind == .feature ? "Nova funcionalidade" : kind.label
    }
}
