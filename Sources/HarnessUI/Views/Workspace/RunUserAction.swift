import HarnessDomain

enum RunUserAction: Equatable {
    case prepareContext, reviewContext, reviewProposal, recordReproduction, recordVerification
    case reviewOperations, editLoopPolicy, reviewFindings, reviewCriteria, reviewChecks
    case reviewChanges, reviewDelivery, inspectBlocker, recover, resume

    static func next(for run: Run, project: Project? = nil) -> Self? {
        guard !run.state.active, ![.archived, .cancelled].contains(run.state), run.workflow?.delivery.closedAt == nil
        else { return nil }
        if run.approvals.contains(where: { ["PREPARED", "UNKNOWN"].contains($0.state) }) {
            return .reviewOperations
        }
        switch run.state {
        case .queued, .preparing, .running, .archived, .cancelled: return nil
        case .draft: return .prepareContext
        case .recovering: return .recover
        case .paused: return .resume
        case .ready: return .reviewDelivery
        case .waitingUser, .partial, .blocked, .failed: return pendingAction(for: run, project: project)
        }
    }

    private static func pendingAction(for run: Run, project: Project?) -> Self {
        if let state = run.loopExecution?.state, [.limitReached, .stalled].contains(state) { return .editLoopPolicy }
        let validationWait = run.loopExecution?.state == .awaitingUser ? run.loopExecution?.validationWait : nil
        if run.state == .waitingUser || run.state == .partial {
            if !run.contextApproved {
                guard let pack = run.pack, !run.revision.isEmpty, pack.revision == run.revision else {
                    return .prepareContext
                }
                return .reviewContext
            }
            if !run.planApproved, run.workflow?.proposal.isEmpty == false { return .reviewProposal }
            if validationWait == nil {
                switch run.currentStep?.kind {
                case "reproduction" where run.workflow != nil: return .recordReproduction
                case "verification" where run.workflow != nil: return .recordVerification
                default: break
                }
            }
        }
        if run.approvals.contains(where: { ["APPROVED", "SENDING"].contains($0.state) }) { return .reviewOperations }
        if run.findings.contains(where: { ["OPEN", "ACCEPTED_RISK"].contains($0.state) }) { return .reviewFindings }
        if run.loopExecution?.state == .awaitingUser,
            run.extensionInvocations?.contains(where: { ["RUNNING", "UNKNOWN"].contains($0.state) }) == true
        {
            return .inspectBlocker
        }
        if [.waitingUser, .partial].contains(run.state), let wait = validationWait {
            guard let project, project.id == run.projectID else { return .reviewChecks }
            let mandatory = run.runbook.validators(for: project).filter(\.required)
            guard !mandatory.isEmpty, mandatory.allSatisfy(\.approved) else { return .reviewChecks }
            switch wait {
            case .catalog: return .resume
            case .results: return run.observedLoopValidations(for: mandatory) == nil ? .reviewChecks : .resume
            }
        }
        let requiredChecks = RunFollowupEvidence.latestValidations(in: run).filter(\.validator.required)
        if run.currentStep?.kind == "validation"
            || requiredChecks.contains(where: { !RunFollowupEvidence.validationIsConfirmed($0, in: run) })
        {
            return .reviewChecks
        }
        if run.state == .partial {
            if !run.workflowEvidenceComplete {
                if run.workflow?.kind == .bug,
                    run.workflow?.observations.contains(where: { $0.phase == .before && $0.status == .pass }) != true
                {
                    return .recordReproduction
                }
                return .recordVerification
            }
            let criteria = Set(run.criteria.map(\.id))
            if run.changedFiles.contains(where: {
                $0.linkedCriteria.isEmpty || !Set($0.linkedCriteria).isSubset(of: criteria)
            }) {
                return .reviewChanges
            }
            if !run.revision.isEmpty, run.reviewRevision == run.revision, !run.criteria.isEmpty,
                run.humanReviewRevision != run.revision
                    || !run.criteria.allSatisfy(RunFollowupEvidence.criterionIsConfirmed)
            {
                return .reviewCriteria
            }
        }
        return .inspectBlocker
    }

    var destination: RunWorkspaceSection? {
        switch self {
        case .reviewContext: .context
        case .reviewProposal: .proposal
        case .reviewChecks: .validation
        case .reviewFindings, .reviewCriteria: .review
        case .reviewChanges, .recover: .changes
        case .reviewDelivery: .evidence
        case .inspectBlocker: .activity
        case .prepareContext, .recordReproduction, .recordVerification, .reviewOperations, .editLoopPolicy, .resume: nil
        }
    }

    var title: String {
        switch self {
        case .prepareContext: "Preparar contexto"
        case .reviewContext: "Revisar contexto"
        case .reviewProposal: "Revisar proposta"
        case .recordReproduction: "Registrar reprodução"
        case .recordVerification: "Registrar resultado do cenário"
        case .reviewOperations: "Conferir operação"
        case .editLoopPolicy: "Revisar plano do ciclo"
        case .reviewFindings: "Conferir achados"
        case .reviewCriteria: "Revisar critérios"
        case .reviewChecks: "Conferir validações"
        case .reviewChanges: "Conferir alterações"
        case .reviewDelivery: "Revisar entrega"
        case .inspectBlocker: "Inspecionar impedimento"
        case .recover: "Conferir recuperação"
        case .resume: "Retomar etapas"
        }
    }

    var detail: String {
        switch self {
        case .prepareContext: "Prepare os arquivos desta revisão para conferir o que o executor receberá."
        case .reviewContext: "Em Contexto, confira os arquivos e o destino antes de autorizar o envio."
        case .reviewProposal: "Leia a proposta e confira o escopo antes de aprovar a implementação."
        case .recordReproduction: "Em Cenários, registre como reproduzir o problema e o que você observou."
        case .recordVerification: "Em Cenários, registre o resultado observado e a evidência desta revisão."
        case .reviewOperations: "Confira o destino, o conteúdo e o estado da operação antes de decidir."
        case .editLoopPolicy: "No editor do plano, confira a abordagem, o orçamento e os limites antes de continuar."
        case .reviewFindings: "Em Revisão, abra o achado para conferir a evidência e registrar a resolução."
        case .reviewCriteria: "Em Revisão, confira o parecer e os critérios antes de confirmar a revisão humana."
        case .reviewChecks: "Em Validação, confira os comandos obrigatórios, as aprovações pendentes e os resultados."
        case .reviewChanges: "Em Alterações, escolha um arquivo para conferir o diff e orientar os ajustes."
        case .reviewDelivery: "Em Evidências, confira os critérios e as alterações antes de decidir sobre a entrega."
        case .inspectBlocker: "Em Atividade, confira o último evento e o motivo que o coordenador registrou."
        case .recover: "Confira as alterações preservadas na tarefa antes de reconciliar os arquivos e retomar."
        case .resume: "Coloque a tarefa de volta na fila para continuar a partir da próxima etapa pendente."
        }
    }
}
