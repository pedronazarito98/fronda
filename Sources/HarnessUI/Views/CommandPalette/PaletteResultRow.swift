import SwiftUI

struct PaletteResultRow: View {
    let entry: PaletteEntry
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: entry.symbol).font(.system(size: 15)).frame(width: 22)
                    .foregroundStyle(FrondaTheme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    Text(entry.detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if !entry.shortcut.isEmpty {
                    Text(entry.shortcut).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                if selected { Image(systemName: "return").font(.caption).foregroundStyle(FrondaTheme.accent) }
            }
            .padding(.horizontal, 12).padding(.vertical, 10).contentShape(Rectangle())
            .background(selected ? FrondaTheme.accent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain).accessibilityLabel(entry.title).accessibilityHint(entry.detail)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
