import Foundation

public struct ExecutionConfiguration: Codable, Sendable, Hashable {
    public var model: String?
    public var effort: String?
    public init(model: String? = nil, effort: String? = nil) {
        self.model = model
        self.effort = effort
    }

    public var summary: String {
        [model ?? "Padrão do provider", effort.map { "esforço \($0)" } ?? "esforço padrão"].joined(separator: " · ")
    }

    public func validated() throws -> Self {
        var result = self
        result.model = model?.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.model?.isEmpty == true { result.model = nil }
        if let model = result.model,
            model.count > 150 || model.hasPrefix("-") || model.contains(where: { $0.isWhitespace || $0.isNewline })
        {
            throw HarnessError("Informe um identificador de modelo válido.")
        }
        if let effort, !Self.efforts.contains(effort) {
            throw HarnessError("Nível de esforço não suportado.")
        }
        return result
    }

    public static let efforts = ["none", "minimal", "low", "medium", "high", "xhigh", "max", "ultra"]
}

public struct ProviderModel: Codable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var detail: String
    public var efforts: [String]
    public var defaultEffort: String?
    public init(id: String, name: String, detail: String = "", efforts: [String] = [], defaultEffort: String? = nil) {
        self.id = id
        self.name = name
        self.detail = detail
        self.efforts = efforts
        self.defaultEffort = defaultEffort
    }
}

extension RunbookStep {
    public var usesAgent: Bool {
        ["investigation", "plan", "implementation", "reproduction", "verification", "review"].contains(kind)
    }

    public func execution(in run: Run) -> ExecutionConfiguration {
        let inheritsProvider = provider == nil || provider == run.provider
        let inherited = inheritsProvider ? (run.execution ?? ExecutionConfiguration()) : ExecutionConfiguration()
        return ExecutionConfiguration(model: model ?? inherited.model, effort: effort ?? inherited.effort)
    }
}
