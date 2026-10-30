import Foundation
import Observation

@MainActor @Observable
final class HomeLayoutStore {
    private(set) var cards: [HomeCardConfiguration]
    private(set) var undoLayouts: [[HomeCardConfiguration]] = []
    private let storageKey = "fronda.home.layout.v1"
    @ObservationIgnored private var editingSnapshot: [HomeCardConfiguration]?

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
            let saved = try? JSONDecoder().decode([HomeCardConfiguration].self, from: data)
        {
            var seen = Set<HomeCardKind>()
            cards = saved.filter { seen.insert($0.kind).inserted }
            cards += HomeCardConfiguration.defaults.filter { !seen.contains($0.kind) }
            if cards.allSatisfy(\.hidden) { cards = HomeCardConfiguration.defaults }
        } else {
            cards = HomeCardConfiguration.defaults
        }
    }

    var visible: [HomeCardConfiguration] { cards.filter { !$0.hidden } }
    var canUndo: Bool { !undoLayouts.isEmpty }

    func beginEditing() {
        guard editingSnapshot == nil else { return }
        editingSnapshot = cards
    }

    func finishEditing(cancelled: Bool = false) {
        guard let original = editingSnapshot else { return }
        editingSnapshot = nil
        if cancelled {
            cards = original
        } else if cards != original {
            remember(original)
            persist()
        }
    }

    func resize(_ kind: HomeCardKind, to size: HomeCardSize) {
        change { cards in
            guard let index = cards.firstIndex(where: { $0.kind == kind }) else { return }
            cards[index].size = size
            cards[index].height = nil
        }
    }

    func resizePhysical(_ kind: HomeCardKind, expanded: Bool, height: Double) {
        change { cards in
            guard let index = cards.firstIndex(where: { $0.kind == kind }) else { return }
            cards[index].size = expanded ? .expanded : height < 280 ? .compact : .regular
            cards[index].height = min(800, max(240, height))
        }
    }

    func toggle(_ kind: HomeCardKind) {
        guard editingSnapshot == nil else { return }
        change { cards in
            guard let index = cards.firstIndex(where: { $0.kind == kind }),
                cards[index].hidden || cards.filter({ !$0.hidden }).count > 1
            else { return }
            cards[index].hidden.toggle()
        }
    }

    func move(_ kind: HomeCardKind, to target: HomeCardKind) {
        guard kind != target else { return }
        change { cards in
            guard let source = cards.firstIndex(where: { $0.kind == kind }),
                let targetIndex = cards.firstIndex(where: { $0.kind == target })
            else { return }
            let card = cards.remove(at: source)
            guard let destination = cards.firstIndex(where: { $0.kind == target }) else { return }
            cards.insert(card, at: destination + (source < targetIndex ? 1 : 0))
        }
    }

    func move(_ kind: HomeCardKind, offset: Int) {
        guard editingSnapshot == nil else { return }
        let visibleKinds = visible.map(\.kind)
        guard let index = visibleKinds.firstIndex(of: kind), visibleKinds.indices.contains(index + offset) else {
            return
        }
        change { cards in
            guard let source = cards.firstIndex(where: { $0.kind == kind }),
                let target = cards.firstIndex(where: { $0.kind == visibleKinds[index + offset] })
            else { return }
            cards.swapAt(source, target)
        }
    }

    func restore() {
        guard editingSnapshot == nil else { return }
        change { $0 = HomeCardConfiguration.defaults }
    }

    func undo() {
        guard editingSnapshot == nil else { return }
        guard let previous = undoLayouts.popLast() else { return }
        cards = previous
        persist()
    }

    private func change(_ edit: (inout [HomeCardConfiguration]) -> Void) {
        var updated = cards
        edit(&updated)
        guard updated != cards else { return }
        if editingSnapshot == nil { remember(cards) }
        cards = updated
        if editingSnapshot == nil { persist() }
    }

    private func remember(_ previous: [HomeCardConfiguration]) {
        undoLayouts.append(previous)
        if undoLayouts.count > 30 { undoLayouts.removeFirst() }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cards) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
