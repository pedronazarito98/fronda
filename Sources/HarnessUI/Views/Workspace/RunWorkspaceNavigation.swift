import HarnessDomain
import SwiftUI

struct RunWorkspaceNavigation: View {
    @Binding var selection: RunWorkspaceSection
    let run: Run

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RunWorkspaceSection.primary) { section in
                    Button {
                        selection = section
                    } label: {
                        HStack(spacing: 5) {
                            Text(section.rawValue)
                            if section == .changes, !run.changedFiles.isEmpty {
                                Text(run.changedFiles.count.formatted()).font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.system(size: 12, weight: selection == section ? .semibold : .medium))
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .foregroundStyle(selection == section ? FrondaTheme.accent : .secondary)
                        .overlay(alignment: .bottom) {
                            if selection == section { Rectangle().fill(FrondaTheme.accent).frame(height: 2) }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("run.tab." + section.rawValue)
                    .help("Abrir \(section.rawValue) desta tarefa")
                    .accessibilityAddTraits(selection == section ? [.isSelected] : [])
                }
                Menu {
                    ForEach(RunWorkspaceSection.additional) { section in
                        Button {
                            selection = section
                        } label: {
                            Label(section.rawValue, systemImage: section.symbol)
                        }.accessibilityIdentifier("run.tab." + section.rawValue)
                    }
                } label: {
                    Text(RunWorkspaceSection.additional.contains(selection) ? selection.rawValue : "Mais")
                        .font(.system(size: 11, weight: .medium))
                }
                .menuStyle(.borderlessButton).fixedSize()
                .padding(.horizontal, 8)
                .foregroundStyle(RunWorkspaceSection.additional.contains(selection) ? FrondaTheme.accent : .secondary)
                .accessibilityIdentifier("run.more-sections")
                .help("Mostrar outras áreas da tarefa")
            }
            .padding(.horizontal, 12).padding(.top, 4)
        }
        .background(FrondaTheme.surface)
        .accessibilityLabel("Áreas da execução")
    }
}
