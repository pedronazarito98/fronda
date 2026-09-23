import Foundation
import HarnessDomain
import HarnessInfrastructure

enum PolicyEngine {
    static func sensitiveReason(_ path: String, deleted: Bool = false) -> String? {
        if deleted { return "Remoção de arquivo exige decisão explícita." }
        if ContextFirewall.exclusion(path) != nil { return "Arquivo privado ou excluído." }
        if ["package.json", "Package.swift", "Cargo.toml", "go.mod", "requirements.txt", "Gemfile"].contains(
            URL(fileURLWithPath: path).lastPathComponent) || path.lowercased().contains("lock")
        {
            return "Alteração de dependência ou lockfile."
        }
        if path.hasPrefix(".github/") || path.hasPrefix(".gitlab") || path.lowercased().contains("migration") {
            return "Alteração de CI ou migração."
        }
        return nil
    }
    static func writable(path: String, run: Run, project: Project) throws -> URL {
        guard run.mode.writes, run.workspace != project.path, run.planApproved else {
            throw HarnessError("POLICY_DENIED: escrita requer plano aprovado e worktree exclusiva.")
        }
        guard ContextFirewall.matches(path, patterns: run.scope),
            ContextFirewall.matches(path, patterns: project.allowedPaths)
        else { throw HarnessError("POLICY_DENIED: arquivo fora do escopo aprovado.") }
        guard !ContextFirewall.matches(path, patterns: run.lockedPaths + project.lockedPaths) else {
            throw HarnessError("POLICY_DENIED: arquivo travado.")
        }
        return try ContextFirewall.containedPath(path, root: run.workspace)
    }
    static func approveValidator(_ validator: Validator, run: Run) throws {
        guard validator.approved else {
            throw HarnessError("APPROVAL_REQUIRED: confirme este comando no projeto antes de executar.")
        }
        guard run.mode.writes || validator.readOnly else {
            throw HarnessError("POLICY_DENIED: o modo de leitura aceita somente diagnósticos cadastrados como leitura.")
        }
        guard
            !["sh", "bash", "zsh", "fish", "rm", "sudo", "curl", "wget"].contains(
                URL(fileURLWithPath: validator.executable).lastPathComponent)
        else {
            throw HarnessError(
                "POLICY_DENIED: shell, elevação e comandos destrutivos não fazem parte do catálogo permitido.")
        }
        guard !validator.arguments.contains("--force"), !validator.arguments.contains("--force-with-lease") else {
            throw HarnessError("POLICY_DENIED: argumento de força não permitido.")
        }
    }
    static func findings(run: Run, project: Project) -> [ReviewFinding] {
        run.changedFiles.compactMap { file in
            let reason: String?
            if !ContextFirewall.matches(file.path, patterns: run.scope)
                || !ContextFirewall.matches(file.path, patterns: project.allowedPaths)
            {
                reason = "Arquivo fora do escopo aprovado."
            } else if ContextFirewall.matches(file.path, patterns: run.lockedPaths + project.lockedPaths) {
                reason = "Arquivo travado foi alterado."
            } else if let sensitivity = sensitiveReason(file.path, deleted: file.status == "D"),
                !run.approvals.contains(where: {
                    $0.kind == "file.write" && $0.destination == file.path && $0.state == "CONFIRMED"
                })
            {
                reason = sensitivity
            } else {
                reason = nil
            }
            guard let reason else { return nil }
            var finding = ReviewFinding()
            finding.severity = "P1"
            finding.title = reason
            finding.path = file.path
            finding.evidence = "Git: \(file.status) \(file.path)"
            finding.revision = run.revision
            return finding
        }
    }
}
