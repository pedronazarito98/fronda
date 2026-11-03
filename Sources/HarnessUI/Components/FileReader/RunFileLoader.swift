import Darwin
import Foundation
import HarnessDomain
import HarnessInfrastructure

enum RunFileLoader {
    static let byteLimit = 512 * 1024
    private static let protectedNames: Set<String> = [
        ".netrc", ".npmrc", ".pypirc", ".git-credentials", ".zsh_history", ".bash_history",
        ".python_history", ".psql_history", "id_rsa", "id_ed25519", "id_ecdsa",
        "history", "history.json", "history.jsonl", "conversations.json", "pastecache", "paste_cache",
    ]

    static func load(_ source: RunFileSource) throws -> RunFileDocument {
        let input: String
        switch source {
        case .workspace(let root, let path):
            guard root.hasPrefix("/"), !path.isEmpty else {
                throw HarnessError("O arquivo da tarefa está indisponível.")
            }
            try allow(path)
            _ = try ContextFirewall.containedPath(path, root: root)
            input = try read(URL(fileURLWithPath: root).appendingPathComponent(path))
        case .external(let url), .artifact(let url, _):
            guard url.isFileURL else { throw HarnessError("Selecione um arquivo local.") }
            try allow(source.name)
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            input = try read(url)
        case .snapshot(let name, let content):
            try allow(name)
            guard content.utf8.count <= byteLimit else { throw tooLarge }
            input = content
        }
        guard
            !input.unicodeScalars.contains(where: {
                ($0.value < 32 && ![9, 10, 13].contains($0.value)) || $0.value == 127
            })
        else { throw unsupported }
        let sanitized = ContextFirewall.redact(input)
        return RunFileDocument(format: source.format, source: sanitized, isRedacted: sanitized != input)
    }

    private static var tooLarge: HarnessError {
        HarnessError("Este arquivo excede o limite de leitura de 512 KiB. Selecione um trecho menor.")
    }

    private static var unsupported: HarnessError {
        HarnessError(
            "O leitor aceita texto UTF-8 ou UTF-16 com marca de ordem de bytes. Este conteúdo não pôde ser lido como texto."
        )
    }

    private static func allow(_ path: String) throws {
        let lower = path.lowercased()
        guard ContextFirewall.exclusion(path) == nil,
            !lower.split(separator: "/").contains(where: { protectedNames.contains(String($0)) }),
            ![".db-wal", ".db-shm", ".sqlite-wal", ".sqlite-shm", ".sqlite3-wal", ".sqlite3-shm"].contains(
                where: lower.hasSuffix)
        else { throw HarnessError("Este caminho está protegido pela política de arquivos do Fronda.") }
    }

    private static func read(_ selection: URL) throws -> String {
        try allow(selection.path)
        _ = try ContextFirewall.localFile(selection.path)
        // Foundation may abbreviate these system aliases. Keep every user-controlled component no-follow at open.
        let path =
            selection.path.hasPrefix("/tmp/") || selection.path.hasPrefix("/var/")
            ? "/private" + selection.path : selection.path
        var info = stat()
        guard lstat(path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else {
            throw HarnessError("O arquivo não está disponível. Selecione um arquivo regular no disco.")
        }
        guard info.st_size <= Int64(byteLimit) else { throw tooLarge }
        let descriptor = open(path, O_RDONLY | O_NOFOLLOW_ANY | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw HarnessError("Não foi possível abrir este arquivo para leitura.") }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var opened = stat()
        guard fstat(descriptor, &opened) == 0, opened.st_mode & S_IFMT == S_IFREG,
            opened.st_dev == info.st_dev, opened.st_ino == info.st_ino
        else { throw HarnessError("O arquivo mudou durante a abertura. Selecione-o novamente.") }
        var data = Data()
        while data.count <= byteLimit {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: min(65_536, byteLimit + 1 - data.count)), !chunk.isEmpty else {
                break
            }
            data.append(chunk)
        }
        guard data.count <= byteLimit else { throw tooLarge }
        let decoded: String?
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            decoded = String(data: data.dropFirst(3), encoding: .utf8)
        } else if data.starts(with: [0xFF, 0xFE]) {
            decoded = String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        } else if data.starts(with: [0xFE, 0xFF]) {
            decoded = String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        } else {
            decoded = String(data: data, encoding: .utf8)
        }
        guard let decoded else { throw unsupported }
        return decoded
    }
}
