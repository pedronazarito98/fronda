import HarnessDomain
import SwiftUI

extension RunStepActivityEvent.Category {
    var appearance: (symbol: String, color: Color) {
        switch self {
        case .stage: ("point.3.connected.trianglepath.dotted", FrondaTheme.textMuted)
        case .provider: ("cpu", FrondaTheme.running)
        case .file: ("doc.text", FrondaTheme.clay)
        case .tool: ("wrench.and.screwdriver", FrondaTheme.accent)
        case .validation: ("checklist", FrondaTheme.running)
        case .attention: ("hand.raised", FrondaTheme.warning)
        case .success: ("checkmark.circle", FrondaTheme.success)
        case .failure: ("exclamationmark.circle", FrondaTheme.danger)
        }
    }
}
