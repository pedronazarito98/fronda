import HarnessDomain

extension AppStore {
    func stepActivityPage(runID: String, stepID: String, before: Int = 0) async throws -> [RunEvent] {
        var query = RPCRequest("events")
        query.id = runID
        query.relatedID = stepID
        query.number = before
        let result = try await send(query).events ?? []
        // Older coordinators can return a task-wide page. Never attribute those rows to this step.
        return result.filter { $0.runID == runID && $0.stepID == stepID }
    }
}
