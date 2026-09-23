import Foundation
import HarnessDomain

public enum JiraDocumentText {
    /// Deterministic extraction; original JSON is retained in the source preview.
    public static func criteria(_ value: JSONValue) -> [String] {
        text(value).split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter {
            !$0.isEmpty
        }
    }
    private static func text(_ value: JSONValue) -> String {
        if case .string(let content) = value { return content }
        if case .array(let values) = value { return values.map(text).joined(separator: "\n") }
        let kind = value["type"].string
        if kind == "text" { return value["text"].string }
        if kind == "hardBreak" { return "\n" }
        let children = value["content"].array.map(text).joined()
        return ["paragraph", "heading", "listItem", "blockquote"].contains(kind) ? children + "\n" : children
    }
}
