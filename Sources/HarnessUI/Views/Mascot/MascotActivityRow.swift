import SwiftUI

struct MascotActivityRow: View {
    let activity: MascotActivity
    var prominent = false
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: symbol).font(.system(size: 16)).foregroundStyle(color).frame(width: 22)
                VStack(alignment: .leading, spacing: 6) {
                    Text(activity.title).font(.callout.weight(.semibold)).lineLimit(2).foregroundStyle(.primary)
                    Text(activity.detail).font(.caption).lineLimit(2).foregroundStyle(.secondary)
                    Text(activity.action).font(.caption.weight(.medium)).foregroundStyle(color)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(13).frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(prominent ? 0.08 : 0.025), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain).help(activity.action)
        .accessibilityLabel(activity.title + ". " + activity.detail + ". " + activity.action)
        .accessibilityIdentifier("mascot.activity." + activity.id)
    }

    private var color: Color {
        switch activity.state {
        case .attention: FrondaTheme.clay
        case .error: FrondaTheme.danger
        case .success: FrondaTheme.success
        default: FrondaTheme.accent
        }
    }
    private var symbol: String {
        switch activity.state {
        case .attention: "hand.raised"
        case .error: "exclamationmark.circle"
        case .success: "checkmark.circle"
        case .working: "waveform.path"
        default: "clock"
        }
    }
}
