import SwiftUI
import Combine

class HoverCoordinator: ObservableObject {
    @Published var hoveredPointIndex: Int?
    @Published var dragSelection: DragSelection?

    func setHoveredPoint(_ index: Int?) {
        hoveredPointIndex = index
    }

    func startDragSelection(at index: Int) {
        dragSelection = DragSelection(startIndex: index, endIndex: index)
    }

    func updateDragSelection(to index: Int) {
        guard let selection = dragSelection else { return }
        dragSelection = DragSelection(startIndex: selection.startIndex, endIndex: index)
    }

    func endDragSelection() {
        // Keep the selection but mark it as complete
    }

    func clearDragSelection() {
        dragSelection = nil
    }
}

struct DragSelection {
    let startIndex: Int
    let endIndex: Int

    var range: ClosedRange<Int> {
        if startIndex <= endIndex {
            return startIndex...endIndex
        } else {
            return endIndex...startIndex
        }
    }

    var duration: TimeInterval? = nil
    var elevationChange: Double? = nil
}
