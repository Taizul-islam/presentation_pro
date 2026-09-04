# Implementation Plan - Multi-Mode System (Teaching, Preparation, Desktop)

I will implement a mode-switching system that allows users to toggle between **Preparation**, **Teaching**, and **Desktop** modes, matching the Samsung Note 3 workflow.

## User Review Required

> [!IMPORTANT]
> **Mode Definitions**:
> 1.  **Preparation Mode (Default)**: Full interface with collapsible sidebar (current behavior).
> 2.  **Teaching Mode**: Immersive full-screen view. The sidebar is completely hidden, and the focus is entirely on the canvas and bottom toolbars.
> 3.  **Desktop Mode**: Minimizes the main window to allow interaction with the desktop while keeping a floating tool overlay (simulated as window minimization on desktop platforms).

## Proposed Changes

### State Management
#### [MODIFY] [presentation_screen.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/presentation_screen.dart)
- **New Enum**: `AppMode { preparation, teaching, desktop }`.
- **New State Variable**: `AppMode _currentMode = AppMode.preparation`.
- **Logic**:
    - `Teaching Mode`: Set `_isSidebarCollapsed = true` and hide the toggle chevron.
    - `Desktop Mode`: Implement window minimization logic.

### UI Components
#### [MODIFY] [presentation_screen.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/presentation_screen.dart)
- **Vertical Menu Update**:
    - Add a "Mode" sub-menu item.
    - Implement a slide-out or secondary pop-up to select between the three modes.
- **Layout Adjustments**:
    - Condition the visibility of the sidebar toggle button based on `_currentMode`.
    - Adjust `_buildSlideItem` padding and aspect ratio behavior for Teaching mode to ensure a "borderless" feel.

### Desktop Integration
#### [MODIFY] [pubspec.yaml](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/pubspec.yaml)
- Add `window_manager` or `screen_retriever` if needed for window state control (I will check existing dependencies first).

## Verification Plan

### Automated Tests
- Verify that switching to `teaching` mode correctly collapses the sidebar and hides the toggle.
- Verify that state (drawings) is preserved when switching between modes.

### Manual Verification
- **Preparation -> Teaching**: Sidebar should disappear smoothly, and the canvas should expand.
- **Teaching -> Preparation**: Sidebar toggle should reappear.
- **Mode Switcher**: Ensure the vertical menu sub-options are clearly visible and tappable.
