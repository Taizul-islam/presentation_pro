# Task List - Selection and Move Functionality

- [x] Update `DrawingStroke` model with selection logic
    - [x] Add `selector` to `DrawingTool` enum
    - [x] Implement `boundingBox` for `DrawingStroke`
    - [x] Implement `translate` method for `DrawingStroke`
- [x] Implement selection logic in `DrawingCanvas`
    - [x] Add selection state (rectangle, indices)
    - [x] Update gesture handling for selection and dragging
    - [x] Notify parent when strokes are moved
- [x] Update `DrawingPainter` to render selection UI
    - [x] Draw dashed selection rectangle
    - [x] Draw corner handles (Note 3 style)
- [x] Integrate Selector tool in `PresentationScreen`
    - [x] Add selector icon to central toolbar
    - [x] Handle move updates and undo history
- [x] Verify functionality and cleanup
