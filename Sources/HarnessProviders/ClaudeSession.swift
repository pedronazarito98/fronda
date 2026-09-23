import Foundation
import HarnessDomain
import HarnessInfrastructure

public actor ClaudeSession {
    private let process = RunningProcess()
    public init() {}
    public func run(
        binary: String, run: Run, prompt: String, mcpConfiguration: String, onEvent: @escaping AgentEventHandler
    ) async throws -> AgentOutcome {
        let help = try await ProcessRunner.run(binary, ["--help"], cwd: run.workspace, timeout: 15)
        guard help.stdout.contains("--restricted") else {
            throw HarnessError(
                "VERSION_UNSUPPORTED: Claude Code não oferece --restricted. Nenhuma permissão será ampliada.")
        }
        let arguments = [
            "--restricted", "--print", "--verbose", "--output-format", "stream-json", "--tools", "",
            "--strict-mcp-config", "--mcp-config", mcpConfiguration, "--permission-mode", "dontAsk",
            "--permission-prompts", "none", "--allowedTools",
            "mcp__harness__harness_read_file,mcp__harness__harness_search,mcp__harness__harness_write_file,mcp__harness__harness_validate",
            "--no-session-persistence",
        ]
        let started = Date()
        try process.start(executable: binary, arguments: arguments, cwd: run.workspace, timeout: 3600, stdin: prompt)
        var outcome = AgentOutcome(status: "failed")
        var model = "indisponível"
        for await line in process.lines {
            guard let data = line.data(using: .utf8), let event = try? JSONDecoder().decode(JSONValue.self, from: data)
            else { continue }
            if event["type"].string == "system", !event["model"].string.isEmpty { model = event["model"].string }
            if event["type"].string == "result" {
                outcome.sessionID = event["session_id"].string
                outcome.text = ContextFirewall.redact(event["result"].string)
                outcome.status = event["is_error"].bool ? "failed" : "completed"
                let usage = event["usage"]
                var record = TokenRecord()
                record.provider = .claude
                record.model = model
                record.source = "reported"
                if let input = usage["input_tokens"].int {
                    record.input =
                        input + (usage["cache_read_input_tokens"].int ?? 0)
                        + (usage["cache_creation_input_tokens"].int ?? 0)
                }
                record.output = usage["output_tokens"].int
                record.cachedInput = usage["cache_read_input_tokens"].int
                record.cost = event["total_cost_usd"].double
                record.costSource = "client_estimated_cost"
                outcome.usage = record
            }
            if event["type"].string != "stream_event" { await onEvent("claude.\(event["type"].string)", event) }
        }
        let result = await process.result(since: started)
        guard result.exitCode == 0 else {
            throw HarnessError(
                result.stderr.isEmpty ? "Claude Code terminou com código \(result.exitCode)." : result.stderr)
        }
        return outcome
    }
    public func interrupt() { process.stop() }
}
