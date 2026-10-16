import AppKit
import SwiftUI
import Combine

/// The data for one shelf.
@MainActor
final class Shelf: ObservableObject, Identifiable {
    let id = UUID()
    @Published var items: [ShelfItem] = []
    @Published var isExpanded = false
    @Published var isDropTargeted = false
    /// Shelves opened by a shake close themselves if nothing gets dropped.
    var closesIfLeftEmpty: Bool

    init(closesIfLeftEmpty: Bool) {
        self.closesIfLeftEmpty = closesIfLeftEmpty
    }

    func add(_ new: [ShelfItem]) {
        // Skip files that are already on this shelf
        let existing = Set(items.compactMap(\.fileURL))
        items += new.filter { item in
            guard let url = item.fileURL else { return true }
            return !existing.contains(url)
        }
        if !new.isEmpty { closesIfLeftEmpty = false }
    }

    func remove(_ ids: [UUID]) {
        items.removeAll { ids.contains($0.id) }
    }
}

/// Owns the floating window for one shelf.
@MainActor
final class ShelfController: NSObject, NSWindowDelegate {
    let shelf: Shelf
    let panel: ShelfPanel
    private var cancellables = Set<AnyCancellable>()

    static let collapsedSize = NSSize(width: 184, height: 214)
    static let expandedSize = NSSize(width: 300, height: 380)

    init(shelf: Shelf, center: NSPoint) {
        self.shelf = shelf
        self.panel = ShelfPanel()
        super.init()

        let hosting = ShelfHostingView(rootView: ShelfView(shelf: shelf, controller: self))
        panel.contentView = hosting
        panel.delegate = self

        let size = Self.collapsedSize
        var frame = NSRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                           width: size.width, height: size.height)
        frame = Self.clamp(frame)
        panel.setFrame(frame, display: false)

        // Grow / shrink the window when expanding, keeping its top edge in place
        shelf.$isExpanded
            .dropFirst()
            .sink { [weak self] expanded in self?.resize(expanded: expanded) }
            .store(in: &cancellables)

        // Close automatically once the last item has been dragged out
        shelf.$items
            .dropFirst()
            .sink { [weak self] items in
                guard let self, items.isEmpty, !self.shelf.closesIfLeftEmpty else { return }
                DispatchQueue.main.async { ShelfManager.shared.close(self) }
            }
            .store(in: &cancellables)
    }

    func show() {
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    func dismiss() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [panel] in
            panel.orderOut(nil)
        })
    }

    private func resize(expanded: Bool) {
        let size = expanded ? Self.expandedSize : Self.collapsedSize
        let old = panel.frame
        var frame = NSRect(x: old.minX, y: old.maxY - size.height, width: size.width, height: size.height)
        frame = Self.clamp(frame)
        panel.setFrame(frame, display: true, animate: true)
    }

    /// Keeps the shelf fully on screen.
    private static func clamp(_ frame: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return frame }
        var f = frame
        f.origin.x = min(max(f.minX, visible.minX + 8), visible.maxX - f.width - 8)
        f.origin.y = min(max(f.minY, visible.minY + 8), visible.maxY - f.height - 8)
        return f
    }
}

/// Floating, borderless window that stays above other apps without stealing focus.
final class ShelfPanel: NSPanel {
    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Hosts the SwiftUI shelf. Buttons work on the first click even though the shelf isn't the active window.
final class ShelfHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
