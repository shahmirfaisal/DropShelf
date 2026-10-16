import SwiftUI
import AppKit
import ServiceManagement

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "DropShelf Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Shake to open a shelf") {
                Toggle("Open a shelf when I shake the cursor while dragging", isOn: $settings.shakeEnabled)
                Picker("Shake sensitivity", selection: $settings.sensitivity) {
                    ForEach(ShakeSensitivity.allCases) { Text($0.title).tag($0) }
                }
                .disabled(!settings.shakeEnabled)
                Text("Start dragging a file, then quickly move the cursor left and right. Higher sensitivity needs fewer shakes.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Shelves") {
                Toggle("Remove items from the shelf after dragging them out", isOn: $settings.removeAfterDragOut)
                Text("When a shelf is empty, it closes by itself. Dragging files into Finder moves them; hold ⌥ while dropping to copy.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            loginError = nil
                        } catch {
                            loginError = "Couldn't change this: \(error.localizedDescription)"
                        }
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}
