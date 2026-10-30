import HarnessDomain
import SwiftUI

struct RunBoard: View {
    let store: AppStore
    let runs: [Run]
    let navigation: WorkspaceNavigation

    private var projectIDs: [String] {
        let names = Dictionary(
            store.snapshot.projects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return Set(runs.map(\.projectID)).sorted {
            (names[$0] ?? $0).localizedStandardCompare(names[$1] ?? $1) == .orderedAscending
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = max(160, (geometry.size.width - 48) / 5)
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(projectIDs, id: \.self) { projectID in
                            lane(projectID, columnWidth: columnWidth)
                        }
                    } header: {
                        HStack(spacing: 0) {
                            ForEach(RunBoardStage.allCases) { stage in
                                HStack(spacing: 8) {
                                    Circle().strokeBorder(stage.color, lineWidth: 1.8).frame(width: 13, height: 13)
                                    Text(stage.rawValue).font(.system(size: 12, weight: .medium))
                                    Text(runs.filter { RunBoardStage.stage(for: $0) == stage }.count.formatted())
                                        .font(.system(size: 10)).foregroundStyle(.secondary)
                                    Spacer(minLength: 0)
                                }.padding(.horizontal, 10).frame(width: columnWidth, height: 48)
                            }
                        }.background(FrondaTheme.surface).overlay(alignment: .bottom) { Divider() }
                    }
                }.padding(.horizontal, 24).padding(.bottom, 24)
            }
            .rememberScrollPosition("execution.board")
        }
        .accessibilityIdentifier("runs.board")
    }

    private func lane(_ projectID: String, columnWidth: CGFloat) -> some View {
        let projectRuns = runs.filter { $0.projectID == projectID }
        let projectName = store.snapshot.projects.first { $0.id == projectID }?.name ?? "Projeto indisponível"
        let collapsed = navigation.viewState["board.collapsed." + projectID] == "true"
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                navigation.viewState["board.collapsed." + projectID] = String(!collapsed)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down").font(
                        .system(size: 10, weight: .semibold))
                    Text(projectName).font(.system(size: 13, weight: .semibold))
                    Text("\(projectRuns.count) \(projectRuns.count == 1 ? "tarefa" : "tarefas")")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                }.padding(.horizontal, 8).frame(height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityValue(collapsed ? "Recolhido" : "Expandido")
            .accessibilityIdentifier("board.project." + projectID)
            if !collapsed {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(RunBoardStage.allCases) { stage in
                        VStack(spacing: 10) {
                            ForEach(projectRuns.filter { RunBoardStage.stage(for: $0) == stage }) { run in
                                RunBoardCard(store: store, run: run, navigation: navigation)
                            }
                            if stage == .prepare {
                                Button {
                                    store.composerProjectID = projectID
                                    store.composerText = ""
                                    store.composerSource = nil
                                    store.composerRunbookID = ""
                                    store.showComposer = true
                                } label: {
                                    Label("Nova tarefa", systemImage: "plus").font(.caption)
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                }.buttonStyle(.plain).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 6).padding(.bottom, 20)
                        .frame(width: columnWidth, alignment: .top)
                        .frame(minHeight: 120, alignment: .top)
                    }
                }
            }
            Divider()
        }.frame(width: columnWidth * 5)
    }
}
