import Foundation
import HarnessDomain

extension GitWorkspace {
    /// Content identity independent of staging and commit topology. Refuses private/oversized files.
    public static func deliveryContent(path: String, base: String) async throws -> String {
        let state = try await snapshot(path: path, base: base)
        var entries = [String]()
        for file in state.files.sorted(by: { $0.path < $1.path }) {
            if file.status == "D" {
                entries.append(file.path + ":deleted")
                continue
            }
            let url = try ContextFirewall.containedPath(file.path, root: path)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? Int, size <= 4_000_000 else {
                throw HarnessError("Arquivo excede o limite de conferência da entrega: \(file.path)")
            }
            let data = try Data(contentsOf: url)
            let mode = (attributes[.posixPermissions] as? Int ?? 0) & 0o111
            entries.append(file.path + ":" + Coding.hash(data) + ":" + String(mode))
        }
        return Coding.hash(base + entries.joined(separator: "\n"))
    }
}
