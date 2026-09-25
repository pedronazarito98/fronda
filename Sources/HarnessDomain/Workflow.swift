import Foundation

public enum WorkKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case feature, bug, interface, investigation
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .feature: "Feature"
        case .bug: "Correção de bug"
        case .interface: "Interface"
        case .investigation: "Investigação"
        }
    }
}

public enum StepKind: String, CaseIterable, Sendable {
    case context, investigation, reproduction, plan, implementation, validation, verification, review, evidence
}

public enum ObservationPhase: String, Codable, CaseIterable, Sendable, Identifiable {
    case before, after, visual
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .before: "Antes · reprodução"
        case .after: "Depois · cenário corrigido"
        case .visual: "Validação visual"
        }
    }
}

/// A user-observed scenario is distinct from a provider's narrative or a process exit code.
public struct ScenarioEvidence: Codable, Identifiable, Sendable {
    public var id = makeID()
    public var phase = ObservationPhase.before
    public var scenario = ""
    public var expected = ""
    public var observed = ""
    public var environment = ""
    public var criterionIDs = [String]()
    public var status = GateStatus.notRun
    public var revision = ""
    public var source: String?
    public var artifactID: String?
    public var mediaHash: String?
    public var mediaExtension: String?
    public var createdAt = Date()
    public init() {}
}

public struct DeliveryRecord: Codable, Sendable {
    public var commitSHA: String?
    public var pushedSHA: String?
    public var pullRequestURL: String?
    public var pullRequestPath: String?
    public var accountID: String?
    public var endpoint: String?
    public var mergedAt: Date?
    public var mergedHead: String?
    public var cleanupHead: String?
    public var closedAt: Date?
    public init() {}
}

/// Optional on Run so historical runs retain their original workflow and decoding contract.
public struct CardWorkflow: Codable, Sendable {
    public var kind = WorkKind.feature
    public var reference = ""
    public var investigation = ""
    public var proposal = ""
    public var observations = [ScenarioEvidence]()
    public var delivery = DeliveryRecord()
    public init() {}
}

extension Run {
    public var currentStep: RunbookStep? {
        plan.first { ![.pass, .skipped].contains($0.status) }
    }
    public var stageLabel: String {
        if workflow?.delivery.closedAt != nil { return "Encerrada" }
        if workflow != nil && !contextApproved && !state.active { return "Revisar contexto" }
        if state.active { return currentStep?.title ?? state.label }
        if workflow?.delivery.mergedAt != nil { return "Merge confirmado" }
        if workflow?.delivery.pullRequestURL != nil { return "Acompanhando PR" }
        if state == .ready { return "Revisão da entrega" }
        if contextApproved && !planApproved && !(workflow?.proposal.isEmpty ?? true) { return "Aprovar plano" }
        return currentStep?.title ?? state.label
    }
    public var nextAction: String {
        if workflow?.delivery.closedAt != nil { return "Consultar diário" }
        if state.active { return "Acompanhar execução" }
        if !contextApproved { return "Revisar contexto" }
        if !planApproved && !(workflow?.proposal.isEmpty ?? true) { return "Revisar plano" }
        if currentStep?.kind == "reproduction" { return "Registrar reprodução" }
        if currentStep?.kind == "verification" { return "Conferir cenário" }
        if workflow?.delivery.mergedAt != nil { return "Encerrar tarefa" }
        if workflow?.delivery.pullRequestURL != nil { return "Consultar merge" }
        if state == .ready { return "Preparar entrega" }
        if state == .partial { return "Resolver pendências" }
        return "Retomar trabalho"
    }
    public var workflowEvidenceComplete: Bool {
        guard let workflow else { return true }
        switch workflow.kind {
        case .bug:
            let before = workflow.observations.filter { $0.phase == .before && $0.status == .pass }
            return !before.isEmpty
                && before.allSatisfy { baseline in
                    workflow.observations.contains {
                        $0.phase == .after && $0.status == .pass && $0.revision == revision
                            && $0.scenario == baseline.scenario
                    }
                }
        case .interface:
            return workflow.observations.contains {
                $0.phase == .visual && $0.status == .pass && $0.revision == revision && $0.mediaHash != nil
            }
        case .feature, .investigation: return true
        }
    }
}
