import Foundation
import HarnessDomain

extension AppStore {
    var islandRuns: [Run] {
        snapshot.runs.filter { run in
            ![.draft, .archived, .cancelled].contains(run.state)
                && (!run.state.terminal || Date.now.timeIntervalSince(run.updatedAt) < 3600)
        }.sorted {
            let left = islandPriority($0.state)
            let right = islandPriority($1.state)
            return left == right ? $0.updatedAt > $1.updatedAt : left < right
        }
    }

    var visibleExternalSessions: [ExternalSession] {
        let owned = Set(snapshot.runs.flatMap { $0.attempts.map(\.sessionID) })
        return externalSessions.filter { $0.state != .ended && !owned.contains($0.sessionID) }
    }

    var islandActiveCount: Int {
        (connected ? activeRuns.count : 0)
            + visibleExternalSessions.filter {
                $0.state == .running && !$0.isStale(at: .now) && externalSessionError == nil
            }.count
    }

    var islandAttentionCount: Int {
        (connected ? islandRuns.filter { [.waitingUser, .recovering, .blocked, .failed].contains($0.state) }.count : 0)
            + visibleExternalSessions.filter {
                $0.state == .waiting && !$0.isStale(at: .now) && externalSessionError == nil
            }.count
    }

    private func islandPriority(_ state: RunState) -> Int {
        switch state {
        case .waitingUser, .recovering, .blocked, .failed: 0
        case .running, .preparing: 1
        case .queued, .paused: 2
        default: 3
        }
    }
}
