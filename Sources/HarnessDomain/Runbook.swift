import Foundation

public struct RunbookStep: Codable, Identifiable, Sendable, Hashable {
    public var id = makeID()
    public var title = ""
    public var kind = "implementation"
    public var dependencies = [String]()
    public var criteria = [String]()
    public var paths = [String]()
    public var status = GateStatus.notRun
    public var condition = "always"
    public var provider: ProviderKind?
    public var model: String?
    public var effort: String?
    public init(title: String = "", kind: String = "implementation") {
        self.title = title
        self.kind = kind
    }
}

public struct Runbook: Codable, Identifiable, Sendable, Hashable {
    public var id = makeID()
    public var name = ""
    public var subtitle = ""
    public var symbol = "square.stack.3d.up"
    public var version = 1
    public var mode = AutonomyMode.guided
    public var provider = ProviderKind.codex
    public var budget = 32000
    public var retries = 3
    public var steps = [RunbookStep]()
    public var validationCommands: [Validator]?
    public var workKind: WorkKind?
    public init() {}

    public func validators(for project: Project) -> [Validator] {
        project.validators
            + (validationCommands ?? []).filter { command in
                !project.validators.contains(where: { $0.id == command.id })
            }
    }

    public func orderedSteps() throws -> [RunbookStep] {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !steps.isEmpty else {
            throw HarnessError("Nome e etapas são obrigatórios.")
        }
        guard Set(steps.map(\.id)).count == steps.count else { throw HarnessError("IDs de etapas duplicados.") }
        guard
            steps.allSatisfy({
                StepKind(rawValue: $0.kind) != nil
                    && ["always", "on_pass", "on_failure", "has_changes"].contains($0.condition)
            })
        else { throw HarnessError("Tipo ou condição de etapa não suportado.") }
        guard retries >= 0 && retries <= 10 else { throw HarnessError("Retries devem ficar entre 0 e 10.") }
        var remaining = steps
        var result = [RunbookStep]()
        while !remaining.isEmpty {
            let ready = remaining.filter { Set($0.dependencies).isSubset(of: Set(result.map(\.id))) }
            guard !ready.isEmpty else { throw HarnessError("Grafo contém ciclo ou dependência inexistente.") }
            result += ready
            remaining.removeAll { step in ready.contains { $0.id == step.id } }
        }
        if let workKind {
            var chain = ["context", "investigation"]
            if workKind == .bug { chain.append("reproduction") }
            chain += ["plan", "implementation", "validation"]
            if workKind == .bug || workKind == .interface { chain.append("verification") }
            chain += ["review", "evidence"]
            var predecessor: RunbookStep?
            for kind in chain {
                guard let step = result.first(where: { $0.kind == kind }), step.condition == "always" else {
                    throw HarnessError("O fluxo exige uma etapa obrigatória de \(kind).")
                }
                if let predecessor {
                    var ancestors = Set(step.dependencies)
                    for _ in result {
                        for item in result where ancestors.contains(item.id) { ancestors.formUnion(item.dependencies) }
                    }
                    guard ancestors.contains(predecessor.id) else {
                        throw HarnessError("\(step.title) precisa depender de \(predecessor.title).")
                    }
                }
                predecessor = step
            }
        }
        return result
    }

    public static var builtins: [Runbook] {
        let definitions: [(String, String, String, AutonomyMode)] = [
            ("Implementar issue", "Da intenção à alteração validada.", "checklist", .guided),
            ("Corrigir bug", "Reproduza, investigue e corrija.", "ladybug", .guided),
            ("Corrigir teste", "Entenda a falha antes de alterar.", "checkmark.diamond", .guided),
            ("Revisar PR", "Diff, critérios e achados independentes.", "arrow.triangle.pull", .explore),
            ("Refatorar", "Melhore a estrutura, preserve o comportamento.", "arrow.triangle.branch", .guided),
            ("Explorar código", "Conheça o fluxo e suas dependências.", "safari", .explore),
            ("Implementar UI", "Interface integrada aos padrões do projeto.", "macwindow", .guided),
            ("Investigar incidente", "Hipóteses sustentadas por evidências.", "waveform.path.ecg", .explore),
            ("Atualizar dependência", "Compatibilidade e mudanças explícitas.", "shippingbox", .guided),
            ("Recuperar CI", "Diagnostique e valide a correção local.", "arrow.clockwise", .guided),
            ("Performance", "Meça, encontre o gargalo e compare.", "gauge.with.dots.needle.50percent", .guided),
            ("Personalizado", "Construa seu próprio fluxo de trabalho.", "slider.horizontal.3", .plan),
        ]
        return definitions.enumerated().map { index, value in
            var book = Runbook()
            book.id = "builtin-\(index)"
            book.name = value.0
            book.subtitle = value.1
            book.symbol = value.2
            book.mode = value.3
            book.version = 2
            book.workKind =
                !value.3.writes ? .investigation : index == 1 || index == 2 ? .bug : index == 6 ? .interface : .feature
            var kinds = [("Selecionar contexto", "context"), ("Investigar o projeto", "investigation")]
            if book.workKind == .bug { kinds.append(("Reproduzir o problema", "reproduction")) }
            kinds += [
                ("Propor plano", "plan"),
                (value.3.writes ? "Implementar" : "Investigar", "implementation"), ("Validar", "validation"),
            ]
            if [.bug, .interface].contains(book.workKind) {
                kinds.append(("Conferir cenário e interface", "verification"))
            }
            kinds += [("Revisar de forma independente", "review"), ("Consolidar evidências", "evidence")]
            book.steps = kinds.enumerated().map { offset, item in
                var step = RunbookStep(title: item.0, kind: item.1)
                step.id = "step-\(offset)"
                step.dependencies = offset == 0 ? [] : ["step-\(offset - 1)"]
                return step
            }
            return book
        }
    }
}
