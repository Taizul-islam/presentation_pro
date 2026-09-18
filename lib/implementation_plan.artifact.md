# Implementation Plan - Robust Windows Desktop Export Fix

I will implement a "Safety First" export engine that handles Windows paths correctly, provides detailed error reports, and ensures compatibility with various PC hardware.

## User Review Required

> [!IMPORTANT]
> **Windows Compatibility**: On some Windows touch systems, file saving can fail if the app doesn't have explicit permission or if the process times out. I am increasing the processing timeouts and adding comprehensive error logging to capture any "silent" failures on the client's machine.
> **Fallback Save Method**: If the native Windows "Save File" dialog fails, the app will now automatically attempt to save the file to the user's "Documents" folder with a clear notification.

## Proposed Changes

### 1. Windows-Safe Path Handling
#### [MODIFY] [export_service.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/services/export_service.dart)
- **Universal Separators**: Use `Platform.pathSeparator` everywhere to ensure paths work on both Windows (`\`) and Mac (`/`).
- **Improved Save Dialog**: Refine the `FilePicker` logic to handle Windows "File Type" filters more strictly, which prevents the dialog from failing to open on some Windows builds.

### 2. High-Resolution Hardware Optimization
#### [MODIFY] [export_service.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/services/export_service.dart)
- **Extended Timeout**: Increase the wait time for Windows to **60 seconds** for the heavy 4000px image generation.
- **Explicit Memory Cleanup**: Add more aggressive garbage collection hints and object disposal during the multi-slide rendering loop to prevent Windows "Low Memory" crashes.

### 3. Detailed Error Reporting
#### [MODIFY] [presentation_screen.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/presentation_screen.dart)
- **Technical Error Dialog**: If an export fails, show a modal dialog with the technical error details instead of a simple SnackBar. This allows the client to provide actionable feedback.

### 4. PPTX Stability
#### [MODIFY] [export_service.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/services/export_service.dart)
- Ensure the PPTX archive stream is fully flushed and verified before the final write operation.

## Verification Plan

### Manual Verification
1.  **Windows Save Test**: Export a slide and verify the "Save As" dialog defaults to the correct extension and works smoothly.
2.  **Timeout Test**: Verify that a slide with many drawings (100+) finishes exporting without timing out.
3.  **Error Dialog**: Simulate a "Disk Full" or "No Permission" state and verify the detailed error dialog appears.
4.  **PowerPoint Verification**: Open the result in Windows PowerPoint to ensure slide master and media alignment.
