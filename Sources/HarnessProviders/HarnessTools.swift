import Foundation
import HarnessDomain

public enum HarnessTools {
    public static var definitions: [JSONValue] {
        [
            definition(
                "harness_read_file",
                "Read an eligible project file by relative path. Never reads credentials or private files.",
                properties: ["path": .object(["type": .string("string")])], required: ["path"]),
            definition(
                "harness_search", "Search the authorized local project index.",
                properties: ["query": .object(["type": .string("string")])], required: ["query"]),
            definition(
                "harness_write_file",
                "Write a scoped file in the run worktree. Supply the exact SHA-256 of existing contents; use an empty hash for a new file. Sensitive edits require a Harness decision.",
                properties: [
                    "path": .object(["type": .string("string")]), "content": .object(["type": .string("string")]),
                    "expectedHash": .object(["type": .string("string")]),
                ], required: ["path", "content", "expectedHash"]),
            definition(
                "harness_validate",
                "Execute an explicitly approved project validator by ID. No shell or arbitrary arguments.",
                properties: ["validatorID": .object(["type": .string("string")])], required: ["validatorID"]),
        ]
    }
    private static func definition(
        _ name: String, _ description: String, properties: [String: JSONValue], required: [String]
    ) -> JSONValue {
        .object([
            "type": .string("function"), "name": .string(name), "description": .string(description),
            "inputSchema": .object([
                "type": .string("object"), "properties": .object(properties),
                "required": .array(required.map(JSONValue.string)), "additionalProperties": .bool(false),
            ]),
        ])
    }
}
