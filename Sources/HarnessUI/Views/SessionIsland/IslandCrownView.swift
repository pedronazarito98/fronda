import SwiftUI

/// Both wings stay outside the physical camera housing, including during expansion.
struct IslandCrownView: View {
    let controller: SessionIslandController
    let activeCount: Int
    let attentionCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasActivity: Bool { activeCount > 0 || attentionCount > 0 }

    var body: some View {
        Button {
            controller.expand(focus: true)
        } label: {
            HStack(spacing: 0) {
                HStack(spacing: 5) {
                    if attentionCount > 0 {
                        Image(systemName: "hand.raised.fill").font(.system(size: 10, weight: .semibold))
                    } else {
                        Image(nsImage: FrondaMenuBarIcon.image).renderingMode(.template)
                            .resizable().scaledToFit().frame(width: 13, height: 13)
                    }
                    if hasActivity {
                        Text("\(attentionCount > 0 ? attentionCount : activeCount)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .contentTransition(.numericText())
                    }
                }
                .foregroundStyle(attentionCount > 0 ? Color.orange : FrondaTheme.sage)
                .frame(maxWidth: .infinity)
                Color.clear.frame(width: controller.cameraWidth)
                Group {
                    if attentionCount > 0 {
                        Circle().fill(.orange).frame(width: 5, height: 5)
                    } else if activeCount > 0 {
                        Image(systemName: "waveform")
                            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(FrondaTheme.sage)
                    } else {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold)).foregroundStyle(.white.opacity(0.45))
                    }
                }.frame(maxWidth: .infinity)
            }
            .opacity(hasActivity || controller.revealed || controller.cameraWidth == 0 ? 1 : 0)
            .frame(height: controller.crownHeight).contentShape(.rect)
        }.buttonStyle(.plain)
            .accessibilityLabel("Abrir central de sessões")
            .accessibilityValue("\(activeCount) em execução, \(attentionCount) aguardando atenção")
            .accessibilityIdentifier("island.expand")
    }
}
