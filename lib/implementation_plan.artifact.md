# Implementation Plan - Fix Syntax & Corruption Errors in Export Service

I will resolve the critical syntax errors and code corruption in `export_service.dart` caused by a previous malformed edit. This will restore the build and ensure export functionality works as intended.

## Proposed Changes

### 1. Fix `export_service.dart`
#### [MODIFY] [export_service.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/services/export_service.dart)
- **Remove Corrupted Code**: Delete the redundant and broken code block between lines 296 and 307.
- **Fix `Paint` Initialization**: Update `Paint(filterQuality: ...)` to `Paint()..filterQuality = ...` as the `Paint` constructor does not accept named parameters in standard Flutter versions.
- **Restore Method Integrity**: Ensure `_renderPageToImage` and `_getRenderTextStyle` are properly defined and closed.

### 2. Minor Stability Fixes
#### [MODIFY] [presentation_screen.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/presentation_screen.dart)
- Fix the `toList` spread warning to keep the codebase clean.

## Verification Plan

### Automated Tests
- Run `analyze_file` on `lib/services/export_service.dart` and `lib/presentation_screen.dart`.
- Success criteria: **0 Errors**.

### Manual Verification
1.  **Build App**: Ensure the application compiles without kernel snapshot failures.
2.  **Export Test**: Perform a PDF export. Verify that the 4K resolution and content alignment are still correct.
