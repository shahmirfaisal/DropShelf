import AppKit
import SwiftUI

/// An invisible layer that starts a real macOS drag of one or more items
/// (so they can be dropped into Finder, Mail, browsers, other shelves…),
/// and reports a plain click when the mouse didn't move.
struct DragSource: NSViewRepresentable {
    let shelfID: UUID
    let items: () -> [ShelfItem]
    var onClick: (() -> Void)? = nil
    var onDragEnded: (_ draggedIDs: [UUID], _ succeeded: Bool) -> Void

    func makeNSView(context: Context) -> DragSourceNSView {
        let view = DragSourceNSView()
        update(view)
        return view
    }

    func updateNSView(_ view: DragSourceNSView, context: Context) {
        update(view)
    }

    private func update(_ view: DragSourceNSView) {
        view.shelfID = shelfID
        view.items = items
        view.onClick = onClick
        view.onDragEnded = onDragEnded
    }
}

final class DragSourceNSView: NSView, NSDraggingSource {
    /// The shelf currently being dragged from, so it ignores its own items.
    static var activeShelfID: UUID?
    var shelfID = UUID()
    var items: () -> [ShelfItem] = { [] }
    var onClick: (() -> Void)?
    var onDragEnded: ((_ draggedIDs: [UUID], _ succeeded: Bool) -> Void)?

    private var mouseDownEvent: NSEvent?
    private var dragging = false
    private var draggedIDs: [UUID] = []

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        dragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragging, let down = mouseDownEvent else { return }
        let a = down.locationInWindow, b = event.locationInWindow
        guard hypot(b.x - a.x, b.y - a.y) > 4 else { return }
        startDrag(with: down)
    }

    override func mouseUp(with event: NSEvent) {
        if !dragging { onClick?() }
        mouseDownEvent = nil
    }

    private func startDrag(with event: NSEvent) {
        let list = items()
        guard !list.isEmpty else { return }
        dragging = true
        draggedIDs = list.map(\.id)
        Self.activeShelfID = shelfID

        let start = convert(event.locationInWindow, from: nil)
        let size: CGFloat = 64
        let draggingItems = list.enumerated().map { index, item -> NSDraggingItem in
            let d = NSDraggingItem(pasteboardWriter: item.pasteboardWriter)
            let shift = CGFloat(min(index, 4)) * 6
            let frame = NSRect(x: start.x - size / 2 + shift, y: start.y - size / 2 - shift,
                               width: size, height: size)
            d.setDraggingFrame(frame, contents: ThumbnailCache.cachedImage(for: item) ?? item.icon)
            return d
        }
        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .pile
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Finder moves files by default (like Dropover); hold ⌥ to copy instead
        context == .outsideApplication ? [.copy, .move, .link, .generic] : [.copy, .move, .generic]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        Self.activeShelfID = nil
        onDragEnded?(draggedIDs, !operation.isEmpty)
        dragging = false
        draggedIDs = []
    }
}

/// Lets the shelf window be moved by dragging this area.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowDragNSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class WindowDragNSView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
