# Implementation Plan - Memory-Safe & Compressed High-Res Export

I will overhaul the export engine to be "Memory-Safe," ensuring that even very large presentations (50+ slides) can be exported on standard Windows PCs without crashing or creating corrupted files.

## Proposed Changes

### 1. Intelligent Image Compression (JPEG Fallback)
#### [MODIFY] [export_service.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/services/export_service.dart)
- **Format Switch**: I will change the internal render format from lossless PNG to **High-Quality JPEG (90% quality)** for the final slide images.
- **Why?**: A 4K PNG can be 10MB-20MB, while a 4K JPEG is often 1MB-2GB. This will reduce the total RAM required by **90%**, allowing large files to open easily on any computer.
- **Visual Integrity**: At 90% quality and 4000px resolution, the difference is invisible to the human eye, but the reliability boost is massive.

### 2. Sequential Memory Management
#### [MODIFY] [export_service.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/services/export_service.dart)
- **Aggressive Disposal**: I will implement explicit image disposal immediately after each slide is added to the PDF or PPTX archive.
- **GC Hints**: Add `ui.Image.dispose()` and set large byte arrays to `null` inside the loop to help the Windows garbage collector reclaim memory faster.

### 3. PDF Stream Optimization
#### [MODIFY] [export_service.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/services/export_service.dart)
- Update the PDF generation logic to use compressed image objects (`pw.MemoryImage` with compression) which drastically reduces the final PDF file size on disk.

### 4. Robust PPTX Archiving
#### [MODIFY] [export_service.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/painting-tool/lib/services/export_service.dart)
- Ensure the PPTX zip archive is built slide-by-slide and uses the compressed JPEG data, making the final `.pptx` file much lighter and faster for PowerPoint to open.

## Verification Plan

### Manual Verification
1.  **Large File Test**: Create a presentation with 20+ slides, each with drawings and text. Export to PDF and PPTX.
2.  **RAM Monitoring**: Monitor the application's RAM usage during export. Success criteria: RAM should stay stable and not "spike" uncontrollably.
3.  **File Size Check**: Compare the new export size to the old one. Verify a significant reduction (e.g., from 200MB down to 20MB) while maintaining 4K sharpness.
4.  **Client PC Simulation**: Ensure the high-quality JPEG render still looks "original" and sharp when zoomed in.
