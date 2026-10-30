import Foundation
import HarnessDomain
import HarnessInfrastructure

public enum ProviderModelCatalog {
    public static func refresh(_ input: ProviderInfo) async -> ProviderInfo {
        var info = input
        do {
            guard !info.path.isEmpty else { throw HarnessError("Conecte a instalação local primeiro.") }
            if info.kind == .codex {
                info.models = try await CodexSession().models(binary: info.path)
                info.modelDiscoveryDetail = "Catálogo consultado no App Server desta instalação."
            } else {
                let help = try await ProcessRunner.run(info.path, ["--help"], cwd: NSTemporaryDirectory(), timeout: 15)
                let efforts = help.stdout.contains("--effort") ? ["low", "medium", "high"] : []
                info.models = [
                    ProviderModel(id: "haiku", name: "Haiku", detail: "Tarefas curtas e bem delimitadas."),
                    ProviderModel(
                        id: "sonnet", name: "Sonnet", detail: "Trabalho cotidiano de desenvolvimento.", efforts: efforts
                    ),
                    ProviderModel(
                        id: "opus", name: "Opus", detail: "Investigações e decisões mais complexas.", efforts: efforts),
                ]
                info.modelDiscoveryDetail = "Aliases do Claude Code. Disponibilidade e limites dependem da sua conta."
            }
        } catch {
            info.modelDiscoveryDetail = ContextFirewall.redact(error.localizedDescription)
        }
        return info
    }
}
