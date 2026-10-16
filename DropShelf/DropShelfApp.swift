import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ShelfManager.shared.start()
    }
}

@main
struct DropShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var manager = ShelfManager.shared

    var body: some Scene {
        MenuBarExtra("DropShelf", systemImage: "tray.and.arrow.down") {
            Button("New Shelf") { ShelfManager.shared.newShelf() }
                .keyboardShortcut("n")
            if !manager.controllers.isEmpty {
                Button("Close All Shelves (\(manager.controllers.count))") { ShelfManager.shared.closeAll() }
            }
            Divider()
            Text("Tip: shake the cursor while dragging a file")
            Divider()
            Button("Settings…") { SettingsWindowController.shared.show() }
                .keyboardShortcut(",")
            Button("Quit DropShelf") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
