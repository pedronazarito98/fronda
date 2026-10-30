import AppKit

@MainActor
enum FrondaAssets {
    static let wordmark = load("FrondaWordmark")
    static let symbolLight = load("FrondaSymbolLight")
    static let symbolDark = load("FrondaSymbolDark")
    static let mascot = load("FrondaMascot")

    private static func load(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }
}
