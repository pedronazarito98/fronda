import Darwin
import Foundation
import HarnessDomain

public struct ProcessResult: Sendable {
    public var exitCode: Int32
    public var stdout: String
    public var stderr: String
    public var duration: Double
    public var timedOut: Bool
    public var output: String { [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n") }
}

/// UTF-8 argv is passed directly to posix_spawn; Foundation's path conversion can
/// normalize Unicode arguments on macOS and change an approved command.
public final class RunningProcess: @unchecked Sendable {
    private var pid: pid_t = 0
    private let input = Pipe()
    private let lock = NSLock()
    private var finished = false
    private var killedByTimeout = false
    public let lines: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation
    private var output = Data()
    private var errors = Data()
    private let readers = DispatchGroup()
    private var exitCode: Int32?
    private var waiters = [CheckedContinuation<ProcessResult, Never>]()
    private var startedAt = Date()
    public init() {
        let stream = AsyncStream<String>.makeStream()
        lines = stream.stream
        continuation = stream.continuation
    }
    public static var environment: [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        var result = [
            "PATH":
                "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin",
            "HOME": FileManager.default.homeDirectoryForCurrentUser.path, "LANG": "en_US.UTF-8",
            "TMPDIR": NSTemporaryDirectory(), "GIT_TERMINAL_PROMPT": "0",
        ]
        if let developer = inherited["DEVELOPER_DIR"] { result["DEVELOPER_DIR"] = developer }
        return result
    }
    public func start(
        executable: String, arguments: [String], cwd: String, timeout: Int = 300, stdin: String? = nil,
        interactive: Bool = false
    ) throws {
        let stdout = Pipe()
        let stderr = Pipe()
        startedAt = Date()
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        posix_spawn_file_actions_init(&actions)
        posix_spawnattr_init(&attributes)
        defer {
            posix_spawn_file_actions_destroy(&actions)
            posix_spawnattr_destroy(&attributes)
        }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT))
        posix_spawnattr_setpgroup(&attributes, 0)
        if #available(macOS 26.0, *) {
            posix_spawn_file_actions_addchdir(&actions, cwd)
        } else {
            posix_spawn_file_actions_addchdir_np(&actions, cwd)
        }
        posix_spawn_file_actions_adddup2(&actions, input.fileHandleForReading.fileDescriptor, STDIN_FILENO)
        posix_spawn_file_actions_adddup2(&actions, stdout.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, stderr.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        let environment = Self.environment.sorted { $0.key < $1.key }.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            for pointer in argv { free(pointer) }
            for pointer in environment { free(pointer) }
        }
        read(stdout.fileHandleForReading, isError: false)
        read(stderr.fileHandleForReading, isError: true)
        var child: pid_t = 0
        let code = argv.withUnsafeBufferPointer { args in
            environment.withUnsafeBufferPointer { env in
                posix_spawn(&child, executable, &actions, &attributes, args.baseAddress!, env.baseAddress!)
            }
        }
        guard code == 0 else {
            try? stdout.fileHandleForWriting.close()
            try? stderr.fileHandleForWriting.close()
            try? input.fileHandleForReading.close()
            try? input.fileHandleForWriting.close()
            continuation.finish()
            throw HarnessError("Não foi possível iniciar \(executable): \(String(cString: strerror(code)))")
        }
        lock.withLock { pid = child }
        try? stdout.fileHandleForWriting.close()
        try? stderr.fileHandleForWriting.close()
        try? input.fileHandleForReading.close()
        let childPID = child
        DispatchQueue.global(qos: .utility).async { [self] in
            var status: Int32 = 0
            var result: pid_t
            repeat { result = waitpid(childPID, &status, 0) } while result == -1 && errno == EINTR
            let signal = status & 0x7f
            terminated(code: result == -1 ? -1 : (signal == 0 ? (status >> 8) & 0xff : 128 + signal))
        }
        if let stdin { try send(stdin) }
        if !interactive { try? input.fileHandleForWriting.close() }
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(timeout)) { [weak self] in
            self?.stop(timeout: true)
        }
    }
    private func read(_ handle: FileHandle, isError: Bool) {
        readers.enter()
        DispatchQueue.global(qos: .utility).async { [self] in
            defer {
                readers.leave()
                try? handle.close()
            }
            var pending = Data()
            while true {
                let data = handle.availableData
                if data.isEmpty { break }
                lock.withLock {
                    if isError {
                        if errors.count < 4_000_000 { errors.append(data.prefix(4_000_000 - errors.count)) }
                    } else {
                        if output.count < 4_000_000 { output.append(data.prefix(4_000_000 - output.count)) }
                    }
                }
                if !isError {
                    pending.append(data)
                    while let end = pending.firstIndex(of: 10) {
                        continuation.yield(String(decoding: pending[..<end], as: UTF8.self))
                        pending.removeSubrange(...end)
                    }
                    if pending.count > 8_000_000 {
                        stop()
                        break
                    }
                }
            }
            if !isError {
                if !pending.isEmpty { continuation.yield(String(decoding: pending, as: UTF8.self)) }
                continuation.finish()
            }
        }
    }
    public func send(_ value: String) throws { try input.fileHandleForWriting.write(contentsOf: Data(value.utf8)) }
    public func stop(timeout: Bool = false) {
        lock.withLock {
            guard !finished, pid > 0 else { return }
            killedByTimeout = timeout
            let targetPID = pid
            kill(-targetPID, SIGTERM)
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self else { return }
                self.lock.withLock {
                    if !self.finished, self.pid == targetPID { kill(-targetPID, SIGKILL) }
                }
            }
        }
    }
    public func result(since start: Date) async -> ProcessResult {
        await withCheckedContinuation { reply in
            let result: ProcessResult? = lock.withLock {
                if finished { return makeResult() }
                waiters.append(reply)
                return nil
            }
            if let result { reply.resume(returning: result) }
        }
    }
    private func terminated(code: Int32) {
        readers.notify(queue: .global(qos: .utility)) { [self] in
            let values: (ProcessResult, [CheckedContinuation<ProcessResult, Never>]) = lock.withLock {
                exitCode = code
                finished = true
                pid = 0
                let pending = waiters
                waiters.removeAll()
                return (makeResult(), pending)
            }
            for waiter in values.1 { waiter.resume(returning: values.0) }
        }
    }
    private func makeResult() -> ProcessResult {
        ProcessResult(
            exitCode: exitCode ?? -1, stdout: ContextFirewall.redact(String(decoding: output, as: UTF8.self)),
            stderr: ContextFirewall.redact(String(decoding: errors, as: UTF8.self)),
            duration: Date().timeIntervalSince(startedAt), timedOut: killedByTimeout)
    }
}

public enum ProcessRunner {
    public static func resolve(_ name: String) -> String? {
        if name.hasPrefix("/") { return FileManager.default.isExecutableFile(atPath: name) ? name : nil }
        for folder in (RunningProcess.environment["PATH"] ?? "").split(separator: ":") {
            let path = "\(folder)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }
    public static func run(
        _ executable: String, _ arguments: [String], cwd: String, timeout: Int = 300, stdin: String? = nil
    ) async throws -> ProcessResult {
        guard let path = resolve(executable) else { throw HarnessError("Executável não encontrado: \(executable)") }
        let process = RunningProcess()
        let start = Date()
        try process.start(executable: path, arguments: arguments, cwd: cwd, timeout: timeout, stdin: stdin)
        return await withTaskCancellationHandler {
            await process.result(since: start)
        } onCancel: {
            process.stop()
        }
    }
}
