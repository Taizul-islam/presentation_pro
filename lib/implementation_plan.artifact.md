# Implementation Plan - Selection and Move Functionality

I will implement a selection tool that allows users to select an area of the canvas and move the contained drawing strokes to a new position, matching the Samsung Note 3 style.

## User Review Required

> [!IMPORTANT]
> **Selection Interaction**: The tool will work by dragging to create a rectangular selection box. Any stroke that is partially or fully inside this box will be selected. Once selected, dragging from inside the box will move all contained strokes together.

## Proposed Changes

### 1. Model Updates
#### [MODIFY] [drawing_stroke.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/models/drawing_stroke.dart)
- Add `selector` to the `DrawingTool` enum.
- Update `DrawingStroke` to potentially include an offset or methods to apply a transformation.
- Add a helper method to calculate the bounding box of a `DrawingStroke`.

### 2. Canvas Logic Enhancements
#### [MODIFY] [drawing_canvas.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/widgets/drawing_canvas.dart)
- **New State Variables**:
    - `Rect? selectionRect`: The current selection area.
    - `List<int> selectedStrokeIndices`: Indices of strokes currently selected.
    - `Offset? dragStartOffset`: To calculate movement delta.
- **Gesture Handling**:
    - If `selectedTool == DrawingTool.selector`:
        - `onPointerDown`: Determine if tapping inside an existing selection (to move) or outside (to start a new selection).
        - `onPointerMove`: Either update the selection box dimensions OR update the position of selected strokes.
        - `onPointerUp`: Finalize selection or confirm move.
- **Visual Feedback**:
    - Draw a dashed blue/indigo border for the selection rectangle.
    - Add corner "handles" to the selection box as seen in the reference screenshot.

### 3. Screen Integration
#### [MODIFY] [presentation_screen.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/presentation_screen.dart)
- Add the **Selector** tool to the floating toolbar.
- Ensure the state is correctly passed down to the `DrawingCanvas`.
- Add an action to delete selected strokes (optional but helpful).

## Verification Plan

### Manual Verification
1.  **Activate Selector**: Select the arrow tool from the bottom toolbar.
2.  **Create Selection**: Drag a box around a set of strokes. A dashed box should appear.
3.  **Move Strokes**: Click inside the box and drag. The strokes should move in real-time.
4.  **Deselect**: Tap outside the box to clear the selection.
5.  **Undo/Redo**: Verify that moving strokes can be undone and redone.
