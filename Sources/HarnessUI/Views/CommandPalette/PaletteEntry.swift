import Foundation

struct PaletteEntry: Identifiable {
    enum Action {
        case navigate(String)
        case guide(String)
        case compose(String?)
        case addProject
        case toggleQueue
    }

    let id: String
    let title: String
    let detail: String
    let symbol: String
    let section: String
    let shortcut: String
    let action: Action

    func matches(_ query: String) -> Bool {
        let searchable = "\(title) \(detail) \(section)".folding(
            options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace).allSatisfy { searchable.contains($0) }
    }
}

@MainActor
enum PaletteCatalog {
    static let sections = ["Ações", "Navegar", "Guias", "Tarefas", "Projetos", "Fluxos"]

    static func entries(store: AppStore, query: String) -> [PaletteEntry] {
        let actions = [
            PaletteEntry(
                id: "new", title: "Nova tarefa", detail: "Comece com um objetivo", symbol: "plus", section: "Ações",
                shortcut: "⌘N", action: .compose(nil)),
            PaletteEntry(
                id: "add-project", title: "Adicionar projeto", detail: "Escolher um repositório neste Mac",
                symbol: "folder.badge.plus", section: "Ações", shortcut: "⇧⌘N", action: .addProject),
            PaletteEntry(
                id: "queue", title: store.snapshot.preferences.queuePaused ? "Retomar fila" : "Pausar fila",
                detail: "Gerenciar as próximas execuções",
                symbol: store.snapshot.preferences.queuePaused ? "play" : "pause", section: "Ações", shortcut: "",
                action: .toggleQueue),
        ]
        let destinations = WorkspaceDestination.allCases.map {
            PaletteEntry(
                id: "navigate:" + $0.rawValue, title: $0.title, detail: "Workspace", symbol: $0.symbol,
                section: "Navegar", shortcut: "", action: .navigate($0.rawValue))
        }
        let runs = store.snapshot.runs.sorted { $0.updatedAt > $1.updatedAt }.map { run in
            let project = store.snapshot.projects.first { $0.id == run.projectID }?.name ?? "Projeto"
            return PaletteEntry(
                id: "run:" + run.id, title: run.title, detail: "\(project) · \(run.state.label)",
                symbol: run.runbook.symbol, section: "Tarefas", shortcut: "", action: .navigate("run:" + run.id))
        }
        let guides = GuideTopic.topics.map {
            PaletteEntry(
                id: "guide:" + $0.id, title: $0.title, detail: $0.subtitle, symbol: $0.symbol,
                section: "Guias", shortcut: "", action: .guide($0.id))
        }
        let projects = store.snapshot.projects.map {
            PaletteEntry(
                id: "project:" + $0.id, title: $0.name, detail: $0.branch, symbol: "folder", section: "Projetos",
                shortcut: "", action: .navigate("project:" + $0.id))
        }
        let books = store.snapshot.runbooks.map {
            PaletteEntry(
                id: "book:" + $0.id, title: $0.name, detail: $0.subtitle, symbol: $0.symbol, section: "Fluxos",
                shortcut: "", action: .compose($0.id))
        }
        return (actions + destinations + guides + runs + projects + books).filter { $0.matches(query) }
    }
}
