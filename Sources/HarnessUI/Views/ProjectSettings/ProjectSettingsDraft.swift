import Foundation
import HarnessDomain

struct ProjectSettingsDraft: Equatable {
    var allowedPaths: String
    var lockedPaths: String
    var exclusions: String
    var requireStrongIsolation: Bool
    var disabledProviders: Set<ProviderKind>
    var contextWeights: [String: Int]?
    var jiraAcceptanceField: String
    var validators: [Validator]

    init(project: Project) {
        allowedPaths = project.allowedPaths.joined(separator: "\n")
        lockedPaths = project.lockedPaths.joined(separator: "\n")
        exclusions = project.exclusions.joined(separator: "\n")
        requireStrongIsolation = project.requireStrongIsolation
        disabledProviders = Set(project.disabledProviders ?? [])
        contextWeights = project.contextWeights
        jiraAcceptanceField = project.jiraAcceptanceField ?? ""
        validators = project.validators
    }

    func applying(to current: Project) -> Project {
        var updated = current
        updated.allowedPaths = allowedPaths.split(separator: "\n").map(String.init)
        updated.lockedPaths = lockedPaths.split(separator: "\n").map(String.init)
        updated.exclusions = exclusions.split(separator: "\n").map(String.init)
        updated.requireStrongIsolation = requireStrongIsolation
        if disabledProviders != Set(current.disabledProviders ?? []) {
            updated.disabledProviders = ProviderKind.allCases.filter { disabledProviders.contains($0) }
        }
        updated.contextWeights = contextWeights
        updated.jiraAcceptanceField = jiraAcceptanceField.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.validators = validators
        return updated
    }
}
