import Foundation

/// A bounded implementation/validation group. Its surrounding workflow remains a DAG.
public struct LoopPolicy: Codable, Sendable, Hashable, Identifiable {
    public var id = makeID()
    public var title = "Corrigir e verificar"
    public var implementationStepID: String
    public var validationStepID: String
    /// Absolute maximum for this group, including iterations already recorded.
    public var maxIterations: Int
    public var maxStagnantIterations: Int
    public var maxDurationSeconds: Int

    public init(
        implementationStepID: String, validationStepID: String, maxIterations: Int = 3,
        maxStagnantIterations: Int = 2, maxDurationSeconds: Int = 1800
    ) {
        self.implementationStepID = implementationStepID
        self.validationStepID = validationStepID
        self.maxIterations = maxIterations
        self.maxStagnantIterations = maxStagnantIterations
        self.maxDurationSeconds = maxDurationSeconds
    }

    public var stepIDs: Set<String> { [implementationStepID, validationStepID] }

    public func hasSameGroup(as other: LoopPolicy) -> Bool {
        implementationStepID == other.implementationStepID && validationStepID == other.validationStepID
    }

    public func validate(steps: [RunbookStep], mode: AutonomyMode) throws {
        guard mode.writes else { throw HarnessError("O ciclo de correção exige um modo que permita implementação.") }
        guard (1...10).contains(maxIterations), (1...10).contains(maxStagnantIterations),
            (60...86400).contains(maxDurationSeconds)
        else { throw HarnessError("Defina de 1 a 10 ciclos e um limite de tempo entre 1 minuto e 24 horas.") }
        guard let implementation = steps.first(where: { $0.id == implementationStepID }),
            let validation = steps.first(where: { $0.id == validationStepID }),
            implementation.kind == "implementation", validation.kind == "validation",
            implementation.condition == "always", validation.condition == "always",
            Set(validation.dependencies) == [implementationStepID],
            steps.filter({ $0.kind == "validation" }).count == 1
        else {
            throw HarnessError(
                "O ciclo exige Implementar e uma única etapa Validar, ambas obrigatórias; Validar deve depender somente de Implementar."
            )
        }
    }
}

public enum LoopState: String, Codable, Sendable, CaseIterable {
    case running, evaluating, repeating, paused, awaitingUser, passed, limitReached, stalled, failed, cancelled

    public var label: String {
        switch self {
        case .running: "Em execução"
        case .evaluating: "Conferindo resultados"
        case .repeating: "Nova correção necessária"
        case .paused: "Pausado"
        case .awaitingUser: "Precisa de você"
        case .passed: "Verificações aprovadas"
        case .limitReached: "Limite atingido"
        case .stalled: "Sem progresso"
        case .failed: "Falha operacional"
        case .cancelled: "Cancelado"
        }
    }
}

public struct LoopIteration: Codable, Identifiable, Sendable {
    public var id = makeID()
    public var number: Int
    public var inputRevision: String
    public var planRevision: Int?
    public var outputRevision = ""
    public var state = LoopState.running
    public var decisionReason = ""
    public var attemptIDs = [String]()
    public var validations = [ValidationResult]()
    public var evidenceArtifactIDs = [String]()
    public var failureSignature = ""
    public var startedAt = Date()
    public var finishedAt: Date?

    public init(number: Int, inputRevision: String, planRevision: Int? = nil) {
        self.number = number
        self.inputRevision = inputRevision
        self.planRevision = planRevision
    }
}

public enum LoopValidationWait: String, Codable, Sendable {
    case catalog, results
}

public struct LoopExecution: Codable, Sendable, Identifiable {
    public var id = makeID()
    public var policy: LoopPolicy
    public var state = LoopState.running
    public var validationWait: LoopValidationWait?
    public var reason = ""
    public var iterations = [LoopIteration]()
    public var currentIterationID: String?
    /// Current evidence association; iteration output revisions remain immutable history.
    public var validatedRevision: String?
    public var startedAt = Date()
    /// Time actually spent executing this group; pauses do not consume its time allowance.
    public var elapsedSeconds: Double = 0
    public var activeSince: Date?

    public init(policy: LoopPolicy) { self.policy = policy }

    public var currentIteration: LoopIteration? {
        iterations.first { $0.id == currentIterationID }
    }
    public var consumedSeconds: Double {
        elapsedSeconds + (activeSince.map { max(0, Date().timeIntervalSince($0)) } ?? 0)
    }
}

extension Run {
    public var currentLoopIteration: LoopIteration? { loopExecution?.currentIteration }

    /// A loop may evaluate or resume only from observed process exits in its own iteration and revision.
    public func observedLoopValidations(for validators: [Validator]) -> [ValidationResult]? {
        guard !validators.isEmpty, !revision.isEmpty, let iterationID = currentLoopIteration?.id else { return nil }
        let results = validators.compactMap { validator in
            validations.last {
                $0.validator == validator && $0.revision == revision && $0.loopIterationID == iterationID
            }
        }
        guard results.count == validators.count,
            results.allSatisfy({ result in
                guard let exitCode = result.exitCode else { return false }
                return result.status == .pass && exitCode == 0 || result.status == .fail && exitCode != 0
            })
        else { return nil }
        return results
    }
    /// Only unfinished work receives this association. A later review is outside the loop.
    public var activeLoopIterationID: String? {
        guard let execution = loopExecution, execution.currentIteration?.finishedAt == nil,
            [.running, .evaluating, .awaitingUser, .paused].contains(execution.state)
        else { return nil }
        return execution.currentIterationID
    }
}
