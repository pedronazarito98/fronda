import SwiftUI

struct FrondaWordmark: View {
    var width: CGFloat = 180

    var body: some View {
        Group {
            if let image = FrondaAssets.wordmark {
                Image(nsImage: image).resizable().renderingMode(.original).interpolation(.high).scaledToFit()
            } else {
                Text("Fronda").font(.title2.weight(.semibold))
            }
        }.frame(width: width, height: width * 819 / 1920)
            .accessibilityElement(children: .ignore).accessibilityLabel("Fronda")
    }
}
