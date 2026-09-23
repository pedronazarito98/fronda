import Darwin
import Foundation
import HarnessCore
import HarnessDomain
import HarnessIPC
import HarnessInfrastructure
import Security

@main
struct ServiceMain {
    static func main() async {
        do {
            let args = CommandLine.arguments
            let root = args.firstIndex(of: "--root").flatMap {
                args.indices.contains($0 + 1) ? URL(fileURLWithPath: args[$0 + 1]) : nil
            }
            let paths = try StoragePaths(root: root)
            let fd = open(paths.root.appendingPathComponent("coordinator.lock").path, O_CREAT | O_RDWR, 0o600)
            guard fd >= 0, flock(fd, LOCK_EX | LOCK_NB) == 0 else { return }
            let coordinator = try RunCoordinator(paths: paths)
            let delegate = ServiceDelegate(coordinator: coordinator)
            let listener = NSXPCListener(machServiceName: paths.serviceName)
            listener.delegate = delegate
            listener.resume()
            await coordinator.start()
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(5))
                await coordinator.maintenance()
                withExtendedLifetime((listener, delegate, fd)) {}
            }
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }
}

private final class ServiceDelegate: NSObject, NSXPCListenerDelegate, CoordinatorProtocol, @unchecked Sendable {
    let coordinator: RunCoordinator
    init(coordinator: RunCoordinator) { self.coordinator = coordinator }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier == getuid(), trustedProcess(connection.processIdentifier) else {
            return false
        }
        connection.exportedInterface = NSXPCInterface(with: CoordinatorProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }
    private func trustedProcess(_ pid: pid_t) -> Bool {
        var code: SecCode?
        guard
            SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributePid: pid] as CFDictionary, [], &code)
                == errSecSuccess, let code,
            SecCodeCheckValidity(code, [], nil) == errSecSuccess
        else { return false }
        var information: CFDictionary?
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
            SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
                == errSecSuccess,
            let info = information as? [String: Any],
            let executable = info[kSecCodeInfoMainExecutable as String] as? URL
        else { return false }
        let name = executable.lastPathComponent
        guard ["Harness", "harness", "HarnessCLI"].contains(name) else { return false }
        var ownCode: SecCode?
        var ownStatic: SecStaticCode?
        var ownInformation: CFDictionary?
        if SecCodeCopySelf([], &ownCode) == errSecSuccess, let ownCode,
            SecCodeCopyStaticCode(ownCode, [], &ownStatic) == errSecSuccess, let ownStatic,
            SecCodeCopySigningInformation(ownStatic, SecCSFlags(rawValue: kSecCSSigningInformation), &ownInformation)
                == errSecSuccess,
            let own = ownInformation as? [String: Any], let team = own[kSecCodeInfoTeamIdentifier as String] as? String,
            !team.isEmpty
        {
            guard info[kSecCodeInfoTeamIdentifier as String] as? String == team,
                let identifier = info[kSecCodeInfoIdentifier as String] as? String,
                ["com.harness.app", "com.harness.cli"].contains(identifier)
            else { return false }
        }
        let ownDirectory = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
            .deletingLastPathComponent()
        // Local ad-hoc builds trust only verified binaries shipped beside this helper.
        let allowedDirectories = [
            ownDirectory, ownDirectory.deletingLastPathComponent().appendingPathComponent("Helpers"),
        ]
        guard allowedDirectories.contains(executable.resolvingSymlinksInPath().deletingLastPathComponent()) else {
            return false
        }
        return true
    }
    func handle(_ request: Data, reply: @escaping @Sendable (Data) -> Void) {
        Task {
            let response: RPCResponse
            do {
                let command = try Coding.decode(RPCRequest.self, from: request)
                if command.action == "service.shutdown" {
                    try await coordinator.prepareShutdown(force: command.flag)
                    reply((try? Coding.encode(RPCResponse())) ?? Data())
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { exit(0) }
                    return
                } else {
                    response = await coordinator.handle(command)
                }
            } catch {
                var failure = RPCResponse()
                failure.error = error.localizedDescription
                response = failure
            }
            reply((try? Coding.encode(response)) ?? Data())
        }
    }
}
