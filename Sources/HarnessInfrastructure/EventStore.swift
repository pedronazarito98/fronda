import CSQLite
import Foundation
import HarnessDomain

/// Accessed exclusively by RunCoordinator. No UI or CLI opens the database.
public final class EventStore {
    private var database: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    public init(paths: StoragePaths) throws {
        guard
            sqlite3_open_v2(
                paths.database.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
                == SQLITE_OK
        else { throw HarnessError("Não foi possível abrir o armazenamento do Harness.") }
        sqlite3_busy_timeout(database, 5000)
        try execute("PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA synchronous=FULL;")
        let version = try rows("PRAGMA user_version;").first?.first ?? "0"
        guard ["0", "1", "2"].contains(version) else { throw HarnessError("Versão de banco não suportada: \(version)") }
        if version == "1" {
            let folder = paths.root.appendingPathComponent("backups", isDirectory: true)
            try FileManager.default.createDirectory(
                at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try backup(to: folder.appendingPathComponent("pre-schema-2-\(Int(Date().timeIntervalSince1970)).sqlite"))
        }
        try execute(
            """
            BEGIN IMMEDIATE;
            CREATE TABLE IF NOT EXISTS projects(id TEXT PRIMARY KEY, payload TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS runbooks(id TEXT PRIMARY KEY, payload TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS runbook_revisions(id TEXT, version INTEGER, payload TEXT NOT NULL, PRIMARY KEY(id,version));
            CREATE TABLE IF NOT EXISTS runs(id TEXT PRIMARY KEY, sequence INTEGER NOT NULL, payload TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS run_events(id TEXT PRIMARY KEY, run_id TEXT NOT NULL REFERENCES runs(id), sequence INTEGER NOT NULL, payload TEXT NOT NULL, UNIQUE(run_id,sequence));
            CREATE TABLE IF NOT EXISTS run_snapshots(run_id TEXT NOT NULL, sequence INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(run_id,sequence));
            CREATE TABLE IF NOT EXISTS run_deltas(run_id TEXT NOT NULL, sequence INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(run_id,sequence));
            CREATE TRIGGER IF NOT EXISTS immutable_deltas_update BEFORE UPDATE ON run_deltas BEGIN SELECT RAISE(ABORT,'append-only'); END;
            CREATE TRIGGER IF NOT EXISTS immutable_deltas_delete BEFORE DELETE ON run_deltas BEGIN SELECT RAISE(ABORT,'append-only'); END;
            CREATE TRIGGER IF NOT EXISTS immutable_events_update BEFORE UPDATE ON run_events BEGIN SELECT RAISE(ABORT,'append-only'); END;
            CREATE TRIGGER IF NOT EXISTS immutable_events_delete BEFORE DELETE ON run_events BEGIN SELECT RAISE(ABORT,'append-only'); END;
            CREATE TABLE IF NOT EXISTS preferences(id TEXT PRIMARY KEY, payload TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS file_fingerprints(project_id TEXT NOT NULL, path TEXT NOT NULL, hash TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(project_id,path));
            CREATE VIRTUAL TABLE IF NOT EXISTS fts_chunks USING fts5(project_id UNINDEXED,path,content,tokenize='unicode61');
            CREATE TABLE IF NOT EXISTS commands(id TEXT PRIMARY KEY,payload TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS workspace_leases(path TEXT PRIMARY KEY,run_id TEXT UNIQUE NOT NULL,base_sha TEXT NOT NULL);
            PRAGMA user_version=2;
            COMMIT;
            """)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: paths.database.path)
        guard try rows("PRAGMA quick_check").first?.first == "ok" else {
            throw HarnessError(
                "Falha de integridade no armazenamento. Preserve o diretório e restaure um backup local.")
        }
    }
    deinit { sqlite3_close(database) }
    private func backup(to url: URL) throws {
        var destination: OpaquePointer?
        guard sqlite3_open_v2(url.path, &destination, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK
        else { throw HarnessError("Não foi possível criar backup antes da migração.") }
        defer { sqlite3_close(destination) }
        guard let backup = sqlite3_backup_init(destination, "main", database, "main") else { throw failure() }
        let status = sqlite3_backup_step(backup, -1)
        sqlite3_backup_finish(backup)
        guard status == SQLITE_DONE else {
            throw HarnessError("Backup da migração não concluído; banco original preservado.")
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    private func failure() -> HarnessError {
        HarnessError(database.map { String(cString: sqlite3_errmsg($0)) } ?? "Armazenamento fechado")
    }
    public func execute(_ sql: String, _ bindings: [String] = []) throws {
        if bindings.isEmpty {
            guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
            return
        }
        let statement = try prepare(sql, bindings)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
    }
    private func prepare(_ sql: String, _ bindings: [String]) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { throw failure() }
        for (index, value) in bindings.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), value, -1, transient)
        }
        return statement
    }
    public func rows(_ sql: String, _ bindings: [String] = []) throws -> [[String]] {
        let statement = try prepare(sql, bindings)
        defer { sqlite3_finalize(statement) }
        var result = [[String]]()
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW else { throw failure() }
            result.append(
                (0..<sqlite3_column_count(statement)).map {
                    sqlite3_column_text(statement, $0).map { String(cString: $0) } ?? ""
                })
        }
    }
    public func load<T: Decodable>(_ type: T.Type, table: String) throws -> [T] {
        guard ["projects", "runbooks", "runs", "preferences"].contains(table) else {
            throw HarnessError("Tabela inválida")
        }
        return try rows("SELECT payload FROM \(table)").map { try Coding.decode(type, from: Data($0[0].utf8)) }
    }
    public func save<T: Encodable>(_ value: T, id: String, table: String) throws {
        guard ["projects", "runbooks", "preferences"].contains(table) else { throw HarnessError("Tabela inválida") }
        try execute(
            "INSERT INTO \(table)(id,payload) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload",
            [id, try Coding.string(value)])
    }
    public func append(run: Run, event: RunEvent, previousSequence: Int) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            let sequence =
                try rows("SELECT sequence FROM runs WHERE id=?", [run.id]).first?.first.flatMap(Int.init) ?? 0
            guard sequence == previousSequence else { throw HarnessError("REVISION_CONFLICT: atualize a run.") }
            let payload = try Coding.string(run)
            let oldPayload = try rows("SELECT payload FROM runs WHERE id=?", [run.id]).first?.first ?? "{}"
            let before = try JSONDecoder().decode(JSONValue.self, from: Data(oldPayload.utf8)).object
            let after = try JSONDecoder().decode(JSONValue.self, from: Data(payload.utf8)).object
            var delta = after.filter { before[$0.key] != $0.value }
            for key in before.keys where after[key] == nil { delta[key] = .null }
            try execute(
                "INSERT INTO runs(id,sequence,payload) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET sequence=excluded.sequence,payload=excluded.payload",
                [run.id, String(run.sequence), payload])
            try execute(
                "INSERT INTO run_events(id,run_id,sequence,payload) VALUES(?,?,?,?)",
                [event.id, run.id, String(event.sequence), try Coding.string(event)])
            try execute(
                "INSERT INTO run_deltas(run_id,sequence,payload) VALUES(?,?,?)",
                [run.id, String(run.sequence), try Coding.string(JSONValue.object(delta))])
            if previousSequence == 0 || run.sequence % 100 == 0 || before["state"] != after["state"]
                || before["pack"] != after["pack"] || before["planRevision"] != after["planRevision"]
            {
                try execute(
                    "INSERT INTO run_snapshots(run_id,sequence,payload) VALUES(?,?,?)",
                    [run.id, String(run.sequence), payload])
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }
    public func events(_ id: String, before: Int = 0, limit: Int = 1000) throws -> [RunEvent] {
        try rows(
            "SELECT payload FROM run_events WHERE run_id=? AND sequence<? ORDER BY sequence DESC LIMIT ?",
            [id, String(before > 0 ? before : Int.max), String(limit)]
        ).map { try Coding.decode(RunEvent.self, from: Data($0[0].utf8)) }.reversed()
    }
    public func replay(_ id: String, sequence: Int) throws -> Run {
        guard
            let snapshot = try rows(
                "SELECT sequence,payload FROM run_snapshots WHERE run_id=? AND sequence<=? ORDER BY sequence DESC LIMIT 1",
                [id, String(sequence)]
            ).first
        else { throw HarnessError("Snapshot não encontrado") }
        var value = try JSONDecoder().decode(JSONValue.self, from: Data(snapshot[1].utf8)).object
        for row in try rows(
            "SELECT payload FROM run_deltas WHERE run_id=? AND sequence>? AND sequence<=? ORDER BY sequence",
            [id, snapshot[0], String(sequence)])
        {
            let delta = try JSONDecoder().decode(JSONValue.self, from: Data(row[0].utf8)).object
            for (key, field) in delta { value[key] = field == .null ? nil : field }
        }
        return try Coding.decode(Run.self, from: Coding.encode(JSONValue.object(value)))
    }
    public func index(_ items: [ContextItem], projectID: String) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            for item in items {
                let previous = try rows(
                    "SELECT hash,payload FROM file_fingerprints WHERE project_id=? AND path=?", [projectID, item.path]
                ).first
                if previous?.first == item.hash, let old = previous?[1],
                    let decoded = try? Coding.decode(ContextItem.self, from: Data(old.utf8)),
                    decoded.parserRevision == item.parserRevision, decoded.associatedTests == item.associatedTests
                {
                    continue
                }
                try execute(
                    "INSERT INTO file_fingerprints(project_id,path,hash,payload) VALUES(?,?,?,?) ON CONFLICT(project_id,path) DO UPDATE SET hash=excluded.hash,payload=excluded.payload",
                    [projectID, item.path, item.hash, try Coding.string(item)])
                try execute("DELETE FROM fts_chunks WHERE project_id=? AND path=?", [projectID, item.path])
                try execute(
                    "INSERT INTO fts_chunks(project_id,path,content) VALUES(?,?,?)",
                    [projectID, item.path, item.content])
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }
    public func pruneIndex(projectID: String, keeping paths: Set<String>) throws {
        let previous = try rows("SELECT path FROM file_fingerprints WHERE project_id=?", [projectID])
        try execute("BEGIN IMMEDIATE")
        do {
            for row in previous where !paths.contains(row[0]) {
                try execute("DELETE FROM file_fingerprints WHERE project_id=? AND path=?", [projectID, row[0]])
                try execute("DELETE FROM fts_chunks WHERE project_id=? AND path=?", [projectID, row[0]])
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }
    public func parseErrorCount(projectID: String) throws -> Int {
        Int(
            try rows(
                "SELECT COUNT(*) FROM file_fingerprints WHERE project_id=? AND payload LIKE ?",
                [projectID, "%Tree-sitter: árvore parcial com erros de sintaxe%"]
            ).first?.first ?? "0") ?? 0
    }
    public func search(projectID: String, query: String, limit: Int = 100) throws -> [ContextItem] {
        let words = query.split { !$0.isLetter && !$0.isNumber && $0 != "_" }.prefix(12)
        let search = words.map { "\"\($0)\"*" }.joined(separator: " OR ")
        let data: [[String]]
        if search.isEmpty {
            data = try rows(
                "SELECT payload FROM file_fingerprints WHERE project_id=? ORDER BY path LIMIT ?",
                [projectID, String(limit)])
        } else {
            data = try rows(
                "SELECT f.payload FROM fts_chunks JOIN file_fingerprints f ON f.project_id=fts_chunks.project_id AND f.path=fts_chunks.path WHERE fts_chunks MATCH ? AND f.project_id=? ORDER BY rank LIMIT ?",
                [search, projectID, String(limit)])
        }
        return try data.map { try Coding.decode(ContextItem.self, from: Data($0[0].utf8)) }
    }
    public func lease(path: String, runID: String, base: String) throws {
        if let old = try rows("SELECT run_id,base_sha FROM workspace_leases WHERE path=?", [path]).first {
            guard old == [runID, base] else {
                throw HarnessError("WORKSPACE_LEASE_CONFLICT: outro proprietário usa esta worktree.")
            }
            return
        }
        try execute("INSERT INTO workspace_leases(path,run_id,base_sha) VALUES(?,?,?)", [path, runID, base])
    }
    public func cachedResponse(_ id: String) throws -> RPCResponse? {
        guard let payload = try rows("SELECT payload FROM commands WHERE id=?", [id]).first?.first else { return nil }
        return try Coding.decode(RPCResponse.self, from: Data(payload.utf8))
    }
    public func cache(_ response: RPCResponse, id: String) throws {
        try execute("INSERT OR IGNORE INTO commands(id,payload) VALUES(?,?)", [id, try Coding.string(response)])
    }
}
