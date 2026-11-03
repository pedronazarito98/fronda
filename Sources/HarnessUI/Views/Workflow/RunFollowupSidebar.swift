import HarnessDomain
import SwiftUI

struct RunFollowupSidebar: View {
    let run: Run
    var isConnected = true
    let isBusy: Bool
    let userAction: RunUserAction?
    let onUserAction: (RunUserAction) -> Void
    let onOpen: (RunWorkspaceSection) -> Void

    private var model: RunFollowupModel { RunFollowupModel(run: run, isConnected: isConnected) }

    var body: some View {
        let projection = model
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Acompanhamento")
                    .font(.system(size: 18, weight: .semibold)).tracking(-0.3)
                    .accessibilityAddTraits(.isHeader)
                current(projection)
                Divider()
                explanation(
                    title: "Por que repetiu", symbol: projection.loop.didRepeat ? "arrow.clockwise" : "info.circle",
                    color: projection.loop.didRepeat ? FrondaTheme.warning : FrondaTheme.textMuted
                ) {
                    Text(projection.loop.repetitionReason)
                        .accessibilityIdentifier("followup.repetition-reason")
                }
                Divider()
                explanation(title: "O que falta", symbol: "clock", color: FrondaTheme.textMuted) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(projection.remaining.enumerated()), id: \.offset) { _, item in
                            Text(item)
                        }
                    }
                    .accessibilityIdentifier("followup.remaining")
                }
                if userAction != .reviewChecks,
                    !run.validations.isEmpty || projection.currentStep?.step.kind == "validation"
                {
                    Button("Ver checagens") { onOpen(.validation) }
                        .buttonStyle(.link).accessibilityIdentifier("followup.open-validation")
                }
                if userAction != .reviewChanges && !run.changedFiles.isEmpty {
                    Button("Ver alterações") { onOpen(.changes) }
                        .buttonStyle(.link).accessibilityIdentifier("followup.open-changes")
                }
                Divider()
                RunFollowupHistory(items: projection.loop.history)
                Divider()
                RunFollowupCriteria(criteria: run.criteria, limits: projection.loop.limits)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(FrondaTheme.surface)
        .accessibilityIdentifier("run.followup")
    }

    private func current(_ projection: RunFollowupModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                RunFollowupStatusIcon(appearance: projection.currentAppearance)
                Text(isConnected ? "AGORA" : "ÚLTIMO REGISTRO")
                    .font(.system(size: 11, weight: .semibold)).tracking(0.7)
                if isConnected && userAction != nil {
                    Spacer()
                    Label("Sua vez", systemImage: "hand.raised")
                        .font(.caption.weight(.semibold)).foregroundStyle(FrondaTheme.warning)
                }
            }
            .foregroundStyle(projection.currentAppearance.color)
            Text(projection.currentSummary(for: userAction))
                .font(.system(size: 23, weight: .semibold)).tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("followup.current-summary")
            if isConnected, let userAction {
                Text(userAction.detail)
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(userAction.title) { onUserAction(userAction) }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
                    .accessibilityIdentifier("followup.user-action")
            }
            if userAction == nil || !isConnected || [.blocked, .failed, .partial, .recovering].contains(run.state) {
                Text(projection.currentDetail)
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            if let summary = projection.loopSummary {
                Label(summary, systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("followup.loop-summary")
            }
        }
    }

    private func explanation<Content: View>(
        title: String, symbol: String, color: Color, @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 21)).foregroundStyle(color)
                .frame(width: 23).padding(.top, 1).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.callout.weight(.semibold)).accessibilityAddTraits(.isHeader)
                content()
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RunFollowupStatusIcon: View {
    let appearance: RunFlowAppearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if appearance == .running && !reduceMotion {
                ProgressView().controlSize(.small).tint(appearance.color)
            } else {
                Image(systemName: appearance.symbol)
                    .font(.system(size: 20)).foregroundStyle(appearance.color)
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }
}
