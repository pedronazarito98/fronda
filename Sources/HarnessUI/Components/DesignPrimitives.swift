import HarnessDomain
import SwiftUI

struct StatusBadge: View {
    let text: String
    var compact = false
    var color: Color {
        if ["PASS", "READY", "AVAILABLE", "CONFIRMED", "SATISFIED"].contains(text) { return FrondaTheme.success }
        if ["FAIL", "FAILED", "ERROR", "REJECTED"].contains(text) { return FrondaTheme.danger }
        if ["RUNNING", "PREPARING", "INDEXING"].contains(text) { return .blue }
        if ["WAITING_USER", "BLOCKED", "PARTIAL", "STALE", "DEGRADED", "VERSION_UNSUPPORTED", "PREPARED"].contains(text)
        {
            return FrondaTheme.warning
        }
        return .secondary
    }
    var symbol: String {
        if color == FrondaTheme.success { return "checkmark.circle.fill" }
        if color == FrondaTheme.danger { return "xmark.circle.fill" }
        if color == .blue { return "circle.dotted" }
        if color == FrondaTheme.warning { return "exclamationmark.circle.fill" }
        return "circle"
    }
    var body: some View {
        Label(RunState(rawValue: text)?.label ?? text.replacingOccurrences(of: "_", with: " "), systemImage: symbol)
            .font(.system(size: compact ? 10 : 11, weight: .medium))
            .foregroundStyle(color).padding(.horizontal, 8).padding(.vertical, 5)
            .background(color.opacity(0.09), in: Capsule())
            .accessibilityLabel("Estado: \(text)")
    }
}

struct Surface<Content: View>: View {
    var padding: CGFloat = 20
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(FrondaTheme.surface, in: RoundedRectangle(cornerRadius: FrondaTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: FrondaTheme.cornerRadius)
                    .strokeBorder(contrast == .increased ? FrondaTheme.textMuted : FrondaTheme.border, lineWidth: 1)
            }
    }
}

struct PageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(eyebrow.uppercased()).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2)
                .foregroundStyle(FrondaTheme.accent)
            Text(title).font(.system(size: 29, weight: .semibold)).tracking(-0.7)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionHeading: View {
    let title: String
    var detail = ""
    var body: some View {
        HStack {
            Text(title).font(.system(size: 16, weight: .semibold))
            Spacer()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct EmptyPanel: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 30, weight: .light)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 430)
        }.frame(maxWidth: .infinity).padding(38)
    }
}

struct MonospaceBlock: View {
    let text: String
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(text.isEmpty ? "Nenhum conteúdo nesta revisão." : text).font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .topLeading).padding(16)
        }
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct Metric: View {
    let title: String
    let value: String
    let symbol: String
    var color: Color = .secondary
    var body: some View {
        Surface(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: symbol).foregroundStyle(color)
                    Spacer()
                    Text(value).font(.system(size: 25, weight: .medium, design: .rounded)).monospacedDigit()
                }
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
