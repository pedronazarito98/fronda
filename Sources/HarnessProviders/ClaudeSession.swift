import Foundation
import HarnessDomain
import HarnessInfrastructure

public actor ClaudeSession {
    private let process = RunningProcess()
    private var onPartial: (@Sendable (String) async -> Void)?
    public init() {}
    public func run(
        binary: String, run: Run, prompt: String, mcpConfiguration: String, readOnly: Bool = false,
        selectedModel: String? = nil, selectedEffort: String? = nil, onEvent: @escaping AgentEventHandler
    ) async throws -> AgentOutcome {
        try await perform(
            binary: binary, workspace: run.workspace, prompt: prompt, mcpConfiguration: mcpConfiguration,
            readOnly: readOnly, selectedModel: selectedModel, selectedEffort: selectedEffort, onEvent: onEvent)
    }

    func reply(
        binary: String, workspace: String, prompt: String, execution: ExecutionConfiguration,
        onPartial: @escaping @Sendable (String) async -> Void
    ) async throws -> AgentOutcome {
        self.onPartial = onPartial
        return try await perform(
            binary: binary, workspace: workspace, prompt: prompt, mcpConfiguration: nil,
            readOnly: true, selectedModel: execution.model, selectedEffort: execution.effort, onEvent: nil)
    }

    private func perform(
        binary: String, workspace: String, prompt: String, mcpConfiguration: String?, readOnly: Bool,
        selectedModel: String?, selectedEffort: String?, onEvent: AgentEventHandler?
    ) async throws -> AgentOutcome {
        try Task.checkCancellation()
        let help = try await ProcessRunner.run(binary, ["--help"], cwd: workspace, timeout: 15)
        guard help.stdout.contains("--restricted") else {
            throw HarnessError(
                "VERSION_UNSUPPORTED: Claude Code não oferece --restricted. Nenhuma permissão será ampliada.")
        }
        var arguments = [
            "--restricted", "--print", "--verbose", "--output-format", "stream-json", "--tools", "",
            "--strict-mcp-config", "--mcp-config", mcpConfiguration ?? #"{"mcpServers":{}}"#,
            "--permission-mode", "dontAsk", "--permission-prompts", "none",
            "--no-session-persistence", "--disable-slash-commands",
        ]
        if mcpConfiguration != nil {
            let allowedTools = HarnessTools.definitions.filter {
                !readOnly || !["harness_write_file", "harness_validate"].contains($0["name"].string)
            }
            arguments += [
                "--allowedTools", allowedTools.map { "mcp__harness__" + $0["name"].string }.joined(separator: ","),
            ]
        } else {
            arguments += ["--system-prompt", ConversationProvider.instructions]
            if help.stdout.contains("--include-partial-messages") { arguments.append("--include-partial-messages") }
        }
        if let selectedModel, !selectedModel.isEmpty { arguments += ["--model", selectedModel] }
        if let selectedEffort {
            guard help.stdout.contains("--effort"), ["low", "medium", "high", "xhigh", "max"].contains(selectedEffort)
            else {
                throw HarnessError(
                    "Esta instalação do Claude não oferece o esforço selecionado. Ajuste a configuração da tarefa.")
            }
            arguments += ["--effort", selectedEffort]
        }
        try Task.checkCancellation()
        let started = Date()
        try process.start(executable: binary, arguments: arguments, cwd: workspace, timeout: 3600, stdin: prompt)
        var outcome = AgentOutcome(status: "failed")
        var model = "indisponível"
        var partialText = ""
        for await line in process.lines {
            guard let data = line.data(using: .utf8), let event = try? JSONDecoder().decode(JSONValue.self, from: data)
            else { continue }
            if event["type"].string == "system", !event["model"].string.isEmpty { model = event["model"].string }
            if let onPartial, event["type"].string == "stream_event" {
                let message = event["event"]
                if message["type"].string == "message_start" { partialText = "" }
                if message["type"].string == "content_block_delta", message["delta"]["type"].string == "text_delta" {
                    partialText += message["delta"]["text"].string
                    await onPartial(ContextFirewall.redact(partialText))
                }
            }
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
            if event["type"].string != "stream_event" { await onEvent?("claude.\(event["type"].string)", event) }
        }
        let result = await process.result(since: started)
        guard result.exitCode == 0 else {
            throw HarnessError(
                result.stderr.isEmpty ? "Claude Code terminou com código \(result.exitCode)." : result.stderr)
        }
        return outcome
    }
    public func interrupt() { process.stop() }
    public nonisolated func requestStop() { process.stop() }
    public func waitForStopConfirmation() async -> Bool { await process.waitForStopConfirmation() }
}
