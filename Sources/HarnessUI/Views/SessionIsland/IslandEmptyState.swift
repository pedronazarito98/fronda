import SwiftUI

struct IslandEmptyState: View {
    var body: some View {
        HStack(spacing: 10) {
            FrondaMascot(size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("Tudo tranquilo").font(.system(size: 12, weight: .medium))
                Text("Suas próximas sessões aparecem aqui.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding(.vertical, 8)
    }
}
