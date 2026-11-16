import AppKit
import SwiftUI

struct FrondaCommands: Commands {
    let store: AppStore
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        SidebarCommands()
        CommandGroup(replacing: .newItem) {
            Button("Nova conversa") {
                store.newChat()
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }.keyboardShortcut("n")
            Menu("Conversas recentes") {
                ForEach(store.chats.prefix(10)) { chat in
                    Button(chat.title) {
                        store.selectChat(chat.id)
                        openWindow(id: "main")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            }.disabled(store.chats.isEmpty)
            Divider()
            Button("Abrir arquivo…") {
                if case .external(let url) = RunFileSource.chooseExternal() {
                    openWindow(id: "file-reader", value: url)
                }
            }.keyboardShortcut("o")
        }
    }
}
