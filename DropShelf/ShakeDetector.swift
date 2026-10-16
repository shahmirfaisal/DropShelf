import AppKit

/// Watches the mouse while something is being dragged anywhere on the Mac,
/// and calls `onShake` when the cursor is shaken left and right.
@MainActor
final class ShakeDetector {
    var onShake: ((NSPoint) -> Void)?
    /// Called when the mouse button is released (any drag has ended).
    var onMouseUp: (() -> Void)?

    private var monitors: [Any] = []
    private let dragPasteboard = NSPasteboard(name: .drag)
    private var changeCountAtMouseDown = 0
    private var firedThisDrag = false

    // Shake tracking
    private var lastX: CGFloat?
    private var direction: CGFloat = 0       // -1 left, +1 right
    private var travelInDirection: CGFloat = 0
    private var reversals: [TimeInterval] = []

    private let minTravel: CGFloat = 18      // px moved before a direction counts
    private let window: TimeInterval = 0.7   // reversals must happen within this time

    func start() {
        guard monitors.isEmpty else { return }
        let handler: (NSEvent) -> Void = { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
        let types: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: types, handler: handler) {
            monitors.append(global)
        }
        // Also see drags that start inside DropShelf's own windows
        if let local = NSEvent.addLocalMonitorForEvents(matching: types, handler: { event in
            handler(event); return event
        }) {
            monitors.append(local)
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            changeCountAtMouseDown = dragPasteboard.changeCount
            firedThisDrag = false
            reset()
        case .leftMouseDragged:
            // Only react to real drags of files/content, not window moves or text selection
            guard AppSettings.shared.shakeEnabled,
                  !firedThisDrag,
                  dragPasteboard.changeCount != changeCountAtMouseDown else { return }
            track(x: NSEvent.mouseLocation.x, time: event.timestamp)
        case .leftMouseUp:
            reset()
            onMouseUp?()
        default:
            break
        }
    }

    private func track(x: CGFloat, time: TimeInterval) {
        defer { lastX = x }
        guard let lastX else { return }
        let dx = x - lastX
        guard dx != 0 else { return }
        let newDirection: CGFloat = dx > 0 ? 1 : -1

        if newDirection == direction {
            travelInDirection += abs(dx)
        } else {
            if travelInDirection >= minTravel { reversals.append(time) }
            direction = newDirection
            travelInDirection = abs(dx)
        }

        reversals.removeAll { time - $0 > window }
        if reversals.count >= AppSettings.shared.sensitivity.requiredReversals {
            firedThisDrag = true
            reset()
            onShake?(NSEvent.mouseLocation)
        }
    }

    private func reset() {
        lastX = nil
        direction = 0
        travelInDirection = 0
        reversals.removeAll()
    }
}
