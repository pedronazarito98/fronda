import Foundation

enum WorkspaceDestination: String, CaseIterable, Identifiable {
    case center, runs, decisions, projects, runbooks, diary, guide

    var id: String { rawValue }
    var title: String {
        switch self {
        case .center: "Visão geral"
        case .runs: "Tarefas"
        case .decisions: "Decisões"
        case .projects: "Projetos"
        case .runbooks: "Fluxos"
        case .diary: "Diário"
        case .guide: "Guia Fronda"
        }
    }
    var symbol: String {
        switch self {
        case .center: "square.grid.2x2"
        case .runs: "rectangle.stack"
        case .decisions: "checkmark.bubble"
        case .projects: "folder"
        case .runbooks: "point.3.connected.trianglepath.dotted"
        case .diary: "book.closed"
        case .guide: "leaf"
        }
    }
    static let workspace: [Self] = [.center, .runs, .decisions]
    static let library: [Self] = [.projects, .runbooks, .diary, .guide]
}
