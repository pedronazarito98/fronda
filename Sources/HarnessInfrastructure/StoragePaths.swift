import CryptoKit
import Foundation
import HarnessDomain

public enum Coding {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
    public static func string<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try encode(value), as: UTF8.self)
    }
    public static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    public static func hash(_ string: String) -> String { hash(Data(string.utf8)) }
}

public struct StoragePaths: Sendable {
    public let root: URL
    public var database: URL { root.appendingPathComponent("harness.sqlite") }
    public var endpoint: URL { root.appendingPathComponent("coordinator.endpoint") }
    public var serviceName: String { "com.harness.coordinator." + Coding.hash(root.path).prefix(12) }
    public var artifacts: URL { root.appendingPathComponent("artifacts", isDirectory: true) }
    public var worktrees: URL { root.appendingPathComponent("worktrees", isDirectory: true) }
    public var exports: URL { root.appendingPathComponent("exports", isDirectory: true) }
    public init(root: URL? = nil) throws {
        self.root =
            root
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Harness", isDirectory: true)
        for url in [self.root, artifacts, worktrees, exports] {
            try FileManager.default.createDirectory(
                at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        }
    }
    public func putArtifact(_ text: String) throws -> String {
        let data = Data(ContextFirewall.redact(text).utf8)
        let hash = Coding.hash(data)
        let path = artifacts.appendingPathComponent(hash)
        if !FileManager.default.fileExists(atPath: path.path) { try atomicWrite(data, to: path) }
        return hash
    }
    public func atomicWrite(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        let handle = try FileHandle(forWritingTo: url)
        try handle.synchronize()
        try handle.close()
    }
}
