import SwiftUI

struct NewRunJourney: ViewModifier {
    let store: AppStore
    @Binding var draft: NewRunDraft
    var focusedField: FocusState<NewRunField?>.Binding
    let working: Bool
    @State private var participating = false

    private var journey: FirstTaskJourney { store.firstTaskJourney }
    private var checkpoint: Data? {
        guard participating else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(draft)
    }

    func body(content: Content) -> some View {
        content
            .modifier(
                GuideOverlay(
                    journey: journey, presented: journey.isComposing, confirmation: journey.step.confirmation,
                    canConfirm: canConfirm && !working, confirm: confirm, pause: pause)
            )
            .safeAreaInset(edge: .top, spacing: 0) {
                if participating && journey.status == .paused {
                    HStack {
                        Label("Seu guia está pausado. O rascunho continua salvo.", systemImage: "leaf")
                        Spacer()
                        Button("Retomar") { journey.begin() }.accessibilityIdentifier("guide.resume-composer")
                    }.font(.caption).padding(12).background(FrondaTheme.accent.opacity(0.06))
                }
            }
            .onChange(of: journey.isComposing, initial: true) { _, active in
                if active { participating = true }
            }
            .task(id: journey.isComposing ? journey.step : nil) {
                guard journey.isComposing else { return }
                await Task.yield()
                focusedField.wrappedValue = journey.step.field
            }
            .task(id: checkpoint) {
                guard participating else { return }
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                journey.checkpoint(draft)
            }
            .onChange(of: draft.projectID) { _, _ in
                if journey.step == .project && focusedField.wrappedValue == .project { confirm() }
            }
            .onChange(of: draft.bookID) { _, _ in
                if journey.step == .flow && focusedField.wrappedValue == .flow { confirm() }
            }
            .onChange(of: draft.provider) { _, _ in
                if journey.step == .executor && draft.providerIsCustomized { confirm() }
            }
            .onChange(of: focusedField.wrappedValue) { old, new in
                guard old != new, let old,
                    (old == .objective && journey.step == .objective)
                        || (old == .criteria && journey.step == .criteria)
                else { return }
                confirm()
            }
            .onDisappear {
                if participating {
                    journey.checkpoint(draft)
                    if journey.isComposing { journey.pause() }
                }
            }
    }

    private var canConfirm: Bool {
        switch journey.step {
        case .project: store.snapshot.projects.contains { $0.id == draft.projectID }
        case .flow:
            store.snapshot.runbooks.first { $0.id == draft.bookID }.flatMap { try? $0.orderedSteps() }?.isEmpty == false
        case .executor: true
        case .objective: draft.hasObjective
        case .criteria: !draft.criteriaLines.isEmpty
        case .prepare, .context: false
        }
    }

    private func confirm() {
        guard journey.isComposing, canConfirm, !working else { return }
        journey.checkpoint(draft)
        journey.advance()
    }
    private func pause() {
        journey.checkpoint(draft)
        journey.pause()
    }
}
