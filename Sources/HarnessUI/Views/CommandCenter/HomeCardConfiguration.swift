import Foundation

enum HomeCardKind: String, Codable, CaseIterable, Identifiable {
    case attention, progress, recent, projects, start

    var id: String { rawValue }
    var title: String {
        switch self {
        case .attention: "Precisa de você"
        case .progress: "Em andamento"
        case .recent: "Continuar trabalho"
        case .projects: "Seus projetos"
        case .start: "Começar algo"
        }
    }
    var symbol: String {
        switch self {
        case .attention: "hand.raised"
        case .progress: "waveform.path"
        case .recent: "clock.arrow.circlepath"
        case .projects: "folder"
        case .start: "plus"
        }
    }
}

enum HomeCardSize: String, Codable, CaseIterable, Identifiable {
    case compact, regular, expanded
    var id: String { rawValue }
    var title: String {
        switch self {
        case .compact: "Compacto"
        case .regular: "Confortável"
        case .expanded: "Ampliado"
        }
    }
    var span: Int { self == .expanded ? 2 : 1 }
    var rowLimit: Int { self == .compact ? 2 : self == .regular ? 3 : 5 }
    var minimumHeight: CGFloat { self == .compact ? 220 : self == .regular ? 280 : 350 }
    var emptyHeight: CGFloat { self == .compact ? 180 : self == .regular ? 220 : 260 }

    func resized(by translation: CGSize) -> Self {
        let movement = translation.width + translation.height
        let index = Self.allCases.firstIndex(of: self) ?? 1
        let shift = movement > 55 ? 1 : movement < -55 ? -1 : 0
        return Self.allCases[min(2, max(0, index + shift))]
    }
}

struct HomeCardConfiguration: Codable, Equatable, Identifiable {
    let kind: HomeCardKind
    var size: HomeCardSize = .regular
    var hidden = false
    var height: Double?
    var id: HomeCardKind { kind }

    static let defaults: [Self] = [
        .init(kind: .attention, size: .expanded),
        .init(kind: .progress),
        .init(kind: .recent),
        .init(kind: .projects),
        .init(kind: .start),
    ]
}
