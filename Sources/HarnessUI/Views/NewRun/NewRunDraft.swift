import Foundation
import HarnessDomain

enum NewRunField: Hashable {
    case objective, criteria, project, flow, source
}

struct NewRunDraft: Codable {
    var title = ""
    var context = ""
    var criteria = ""
    var projectID = ""
    var bookID = ""
    var provider = ProviderKind.codex
    var execution = ExecutionConfiguration()
    var providerIsCustomized = false
    var mode = AutonomyMode.guided
    var modeIsCustomized = false
    var scope = "**"
    var budget = 32000
    var budgetIsCustomized = false
    var attachments = [String]()
    var commentIDs = ""
    var remoteAttachmentIDs = Set<String>()
    var sourcePreview: SourcePreview?
    var fetchedSignature = ""

    var sourceKind: SourceKind { SourceKind.detect(title) }
    var sourceSignature: String {
        [title, projectID, commentIDs, remoteAttachmentIDs.sorted().joined(separator: ",")].joined(separator: "\n")
    }
    var sourceNeedsRefresh: Bool { sourcePreview != nil && fetchedSignature != sourceSignature }
    var hasObjective: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var criteriaLines: [String] {
        criteria.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func makeRun(book: Runbook, originalSource: SourceIntent?) -> Run {
        var run = Run()
        run.title = title
        run.projectID = projectID
        run.runbook = book
        run.provider = provider
        run.execution = execution
        run.mode = mode
        run.budget = budget
        run.source = sourcePreview?.intent ?? originalSource ?? SourceIntent()
        run.source.text = context.isEmpty ? title : title + "\n\n" + context
        run.source.kind = originalSource?.kind ?? sourceKind
        run.source.attachments = attachments
        if !attachments.isEmpty {
            run.source.kind =
                attachments.contains(where: {
                    ["png", "jpg", "jpeg", "heic"].contains(URL(fileURLWithPath: $0).pathExtension.lowercased())
                }) ? .screenshot : .file
        }
        if [.github, .jira].contains(run.source.kind) { run.source.sourceURL = title }
        run.criteria = criteriaLines.map { Criterion(text: $0) }
        run.scope = scope.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return run
    }
}
