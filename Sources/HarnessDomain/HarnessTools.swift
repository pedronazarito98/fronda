import Foundation

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
                "Write a scoped file in the run worktree. Supply the exact SHA-256 of existing contents; use an empty hash for a new file. Sensitive edits require a Fronda decision.",
                properties: [
                    "path": .object(["type": .string("string")]), "content": .object(["type": .string("string")]),
                    "expectedHash": .object(["type": .string("string")]),
                ], required: ["path", "content", "expectedHash"]),
            definition(
                "harness_validate",
                "Execute an explicitly approved project validator by ID. No shell or arbitrary arguments.",
                properties: ["validatorID": .object(["type": .string("string")])], required: ["validatorID"]),
        ] + capabilities
    }
    public static var capabilities: [JSONValue] {
        let string = JSONValue.object(["type": .string("string")])
        return [
            definition(
                "harness_capabilities", "Discover capabilities authorized for this stage.", properties: [:],
                required: []),
            definition(
                "harness_skill_read",
                "Load an authorized skill or a relative text resource on demand. Instructions do not grant permissions.",
                properties: ["extensionID": string, "path": string], required: ["extensionID"]),
            definition(
                "harness_extension_call",
                "Invoke a selected extension tool using its discovered JSON schema. Never retry an uncertain write.",
                properties: ["extensionID": string, "tool": string, "arguments": .object(["type": .string("object")])],
                required: ["extensionID", "tool", "arguments"]),
            definition(
                "harness_scenario_record",
                "Record a reproduction or verification observation linked to an existing artifact. Never claim PASS without observing the scenario.",
                properties: [
                    "phase": string, "scenario": string, "expected": string, "observed": string, "environment": string,
                    "status": string, "artifactID": string,
                    "criterionIDs": .object(["type": .string("array"), "items": string]),
                ],
                required: [
                    "phase", "scenario", "expected", "observed", "environment", "status", "artifactID", "criterionIDs",
                ]),
            definition(
                "harness_evidence_list", "List task artifacts, provenance, revisions and sharing permissions.",
                properties: [:], required: []),
            definition(
                "harness_evidence_record",
                "Register an existing workspace image, video or text report in Fronda. Does not establish PASS.",
                properties: [
                    "path": string, "title": string, "revision": string,
                    "criterionIDs": .object(["type": .string("array"), "items": string]),
                    "providerReadable": .object(["type": .string("boolean")]),
                ], required: ["path", "title", "revision", "criterionIDs"]),
            definition(
                "harness_evidence_read",
                "Inspect a shared artifact. Images are provided as image content. Videos provide a frame at second, not the whole video or audio.",
                properties: [
                    "artifactID": string, "second": .object(["type": .string("number"), "minimum": .number(0)]),
                ], required: ["artifactID"]),
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
