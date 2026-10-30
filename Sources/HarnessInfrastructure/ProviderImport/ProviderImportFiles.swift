import Darwin
import Foundation
import HarnessDomain

enum ProviderImportFiles {
    static func read(_ url: URL, limit: Int = 128_000) throws -> String {
        let components = url.standardizedFileURL.pathComponents.dropFirst()
        var descriptor = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard descriptor >= 0 else { throw HarnessError("Não foi possível acessar a origem.") }
        for (index, part) in components.enumerated() {
            let isDirectory = index < components.count - 1
            let next = openat(
                descriptor, part, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK | (isDirectory ? O_DIRECTORY : 0))
            close(descriptor)
            guard next >= 0 else {
                throw HarnessError("Origem indisponível ou contém link simbólico. Selecione o arquivo original.")
            }
            descriptor = next
        }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
            info.st_size >= 0, info.st_size <= limit
        else {
            close(descriptor)
            throw HarnessError("Arquivo não textual ou acima de \(limit / 1000) KB.")
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: limit + 1) ?? Data()
        guard data.count <= limit, let text = String(data: data, encoding: .utf8), !text.contains("\0") else {
            throw HarnessError("Arquivo precisa ser texto UTF-8 dentro do limite.")
        }
        return text
    }

    static func documents(in root: URL, filename: String? = nil, depth: Int = 6) -> [URL] {
        guard depth >= 0,
            (try? root.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == false
        else { return [] }
        let children =
            (try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [])) ?? []
        var result = [URL]()
        for url in children.sorted(by: { $0.path < $1.path }) {
            guard result.count < 500, ContextFirewall.exclusion(url.lastPathComponent) == nil,
                !url.lastPathComponent.hasPrefix("."),
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                values.isSymbolicLink != true
            else { continue }
            if values.isDirectory == true {
                result += documents(in: url, filename: filename, depth: depth - 1).prefix(500 - result.count)
            } else if filename.map({ url.lastPathComponent == $0 }) ?? (url.pathExtension == "md") {
                result.append(url)
            }
        }
        return result
    }

    static func sanitized(_ text: String) -> String {
        let redacted = ContextFirewall.redact(text)
        // Config-like secret assignments may use unquoted values. Never preview or persist those lines.
        return redacted.components(separatedBy: .newlines).map { line in
            let pattern = #"(?i)(?:api[_-]?key|access[_-]?token|secret|password|authorization)\s*[=:]"#
            return line.range(of: pattern, options: .regularExpression) == nil ? line : "[REDACTED]"
        }.joined(separator: "\n")
    }
}
