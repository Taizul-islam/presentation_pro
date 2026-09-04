# Walkthrough - Selection and Drag Functionality

I have implemented a professional selection tool that allows you to select areas of your drawing and move them to new positions, matching the Note 3 style.

## Key Changes

### 1. New Selection Tool
A new **Selector** (arrow) icon has been added to your central floating toolbar.
- **Select Mode**: Drag a box around any part of your drawing.
- **Visual Feedback**: A dashed blue rectangle with corner and side handles will appear around selected strokes, giving it an authentic "Samsung Note" feel.

### 2. Move and Reposition
- **Drag to Move**: Once a selection is made, simply click and drag from *inside* the dashed box to reposition all contained strokes simultaneously.
- **Real-time Interaction**: The drawings follow your mouse movements smoothly as you drag.

### 3. Integrated History
- **Undo/Redo Support**: Moving strokes is fully tracked in the history system. If you move something to the wrong place, you can simply tap the Undo button to snap it back to its original position.

## Technical Implementation
- **Bounding Box Calculation**: Added logic to `DrawingStroke` to calculate the exact spatial boundaries of each sketch.
- **Dynamic Translation**: Implemented a `translate` method to shift multiple strokes by a movement delta without losing their relative spacing.
- **Sophisticated Canvas Logic**: Updated the `DrawingCanvas` to handle dual-mode gestures (creating a selection vs. dragging a selection).

> [!TIP]
> To clear a selection, simply tap anywhere else on the canvas while the Selector tool is active.

> [!NOTE]
> This tool works on all slide types, including PDF backgrounds and imported images!
