import AppKit
import Combine

/// Creates and keeps track of all open shelves.
@MainActor
final class ShelfManager: ObservableObject {
    static let shared = ShelfManager()

    @Published private(set) var controllers: [ShelfController] = []
    private let detector = ShakeDetector()

    func start() {
        detector.onShake = { [weak self] point in self?.newShelf(at: point, closesIfLeftEmpty: true) }
        detector.onMouseUp = { [weak self] in self?.closeUnusedShelvesSoon() }
        detector.start()
    }

    func newShelf(at point: NSPoint? = nil, closesIfLeftEmpty: Bool = false) {
        let center = point ?? NSEvent.mouseLocation
        let controller = ShelfController(shelf: Shelf(closesIfLeftEmpty: closesIfLeftEmpty), center: center)
        controllers.append(controller)
        controller.show()
    }

    func close(_ controller: ShelfController) {
        controller.dismiss()
        controllers.removeAll { $0 === controller }
    }

    func closeAll() {
        controllers.forEach { $0.dismiss() }
        controllers.removeAll()
    }

    /// After a drag ends, shelves opened by a shake that got nothing dropped on them disappear.
    /// If the mouse was released over the shelf, wait longer: the drop can take a moment to arrive.
    private func closeUnusedShelvesSoon() {
        let mouse = NSEvent.mouseLocation
        for c in controllers where c.shelf.closesIfLeftEmpty && c.shelf.items.isEmpty {
            let delay: TimeInterval = c.panel.frame.contains(mouse) ? 3 : 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak c] in
                guard let self, let c, c.shelf.closesIfLeftEmpty, c.shelf.items.isEmpty,
                      self.controllers.contains(where: { $0 === c }) else { return }
                self.close(c)
            }
        }
    }
}
