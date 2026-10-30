import HarnessDomain
import SwiftUI

struct RunbookDetailView: View {
    let book: Runbook
    @Binding var selectedStepID: String?
    let onUse: () -> Void
    let onEdit: () -> Void

    private var preview: RunbookPreview { RunbookPreview(book: book) }
    private var selectedStep: RunbookStep? {
        preview.steps.first { $0.id == selectedStepID } ?? preview.steps.first
    }
    private var selectedID: String? { selectedStep?.id }

    var body: some View {
        VStack(spacing: 0) {
            heading.fixedSize(horizontal: false, vertical: true)
            Divider()
            if let issue = preview.issue {
                Label(issue, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(FrondaTheme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(FrondaTheme.warning.opacity(0.06))
            }
            GeometryReader { geometry in
                if geometry.size.width >= 600 {
                    HStack(spacing: 0) {
                        journey.frame(width: geometry.size.width >= 850 ? 270 : 235)
                        Divider()
                        stageDetails
                    }
                } else {
                    VStack(spacing: 0) {
                        journey.frame(height: min(240, CGFloat(preview.steps.count * 46 + 48)))
                        Divider()
                        stageDetails
                    }
                }
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: book.symbol).font(.system(size: 19))
                    .foregroundStyle(FrondaTheme.accent).frame(width: 35, height: 35)
                    .background(FrondaTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(book.name).font(.system(size: 20, weight: .semibold)).tracking(-0.4)
                        .lineLimit(2).accessibilityIdentifier("runbooks.detail-title")
                    if !book.subtitle.isEmpty {
                        Text(book.subtitle).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(2).help(book.subtitle)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    Button("Editar", systemImage: "slider.horizontal.3", action: onEdit)
                        .accessibilityLabel("Editar fluxo").accessibilityIdentifier("runbooks.edit")
                    useButton
                }.controlSize(.regular).fixedSize()
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 15) {
                    executionSettings
                    Text("Revisão \(book.version)").foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 12) { executionSettings }
                    Text("Revisão \(book.version)").foregroundStyle(.secondary)
                }
            }.font(.caption2)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrondaTheme.surface)
    }

    @ViewBuilder private var executionSettings: some View {
        Label(book.provider.rawValue, systemImage: "terminal")
        Label(book.mode.rawValue, systemImage: book.mode.writes ? "arrow.triangle.branch" : "eye")
        Label("\(book.budget.formatted()) tokens", systemImage: "circle.hexagongrid")
    }

    private var journey: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(preview.issue == nil ? "Prévia do fluxo" : "Etapas para corrigir")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 4)
                Text("\(preview.steps.count) etapas").font(.caption2).foregroundStyle(.secondary)
            }.padding(.horizontal, 16).padding(.top, 17).padding(.bottom, 10)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(preview.steps.enumerated()), id: \.element.id) { index, step in
                            RunbookStepPreview(
                                book: book, step: step, number: index + 1, total: preview.steps.count,
                                selected: selectedID == step.id, select: { selectedStepID = step.id }
                            ).id(step.id)
                        }
                    }.padding(.horizontal, 8).padding(.bottom, 12)
                }
                .onAppear { if let selectedID { proxy.scrollTo(selectedID, anchor: .center) } }
                .onChange(of: selectedID) { _, id in
                    if let id { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }.background(FrondaTheme.surface.opacity(0.35))
    }

    private var stageDetails: some View {
        ScrollView {
            if let step = selectedStep,
                let index = preview.steps.firstIndex(where: { $0.id == step.id })
            {
                RunbookStepDetail(
                    book: book, step: step, number: index + 1, total: preview.steps.count,
                    selectDependency: { selectedStepID = $0 }
                )
                .padding(24)
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }.id(selectedID)
    }

    private var useButton: some View {
        Button("Usar este fluxo", systemImage: "arrow.up.right", action: onUse)
            .buttonStyle(.borderedProminent)
            .disabled(preview.issue != nil)
            .help(
                preview.issue == nil
                    ? "Definir objetivo e projeto com a revisão \(book.version) de \(book.name)"
                    : "Edite o fluxo para corrigir as etapas"
            )
            .accessibilityIdentifier("runbooks.use")
    }
}

private struct RunbookPreview {
    let steps: [RunbookStep]
    let issue: String?

    init(book: Runbook) {
        do {
            steps = try book.orderedSteps()
            issue = nil
        } catch {
            steps = book.steps
            issue = error.localizedDescription
        }
    }
}
