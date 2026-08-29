# Add Loading Indicators for Document and Preview Rendering

Improve the user experience by providing visual feedback while documents and thumbnails are being rendered or loaded.

## User Review Required

> [!NOTE]
> **Thumbnail Indicators**: A small, centered `CircularProgressIndicator` will be shown in the sidebar for each slide while its preview image (Image, PDF, or PPTX) is still being generated or decoded.

> [!TIP]
> **Main View Indicator**: When you select a large PDF or PPTX file to load, a centered loading overlay will appear to let you know the app is processing the document.

## Proposed Changes

### [mobile](file:///Users/miurin/Desktop/painting_tool_co_rasel/mobile)

#### [MODIFY] [slide_thumbnail.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/mobile/lib/widgets/slide_thumbnail.dart)

- **Image Preview**: Update `frameBuilder` to show a `CircularProgressIndicator` while `frame` is null.
- **PPTX Preview**: Add a loading state to `PptxSlideRenderer` or its wrapper in `SlideThumbnail` to show a spinner before the slide is ready.

#### [MODIFY] [presentation_screen.dart](file:///Users/miurin/Desktop/painting_tool_co_rasel/mobile/lib/presentation_screen.dart)

- **Global Loader**: In the `build` method of `_PresentationScreenState`, check the `_isLoadingDocument` flag. If true, show a centered `CircularProgressIndicator` overlay with a subtle dimmed background.
- **PPTX Renderer**: Update `PptxSlideRenderer` to show a loading indicator if the slide details are still being processed (especially for the first render).

## Verification Plan

### Manual Verification
1.  **Load a New Document**: Pick a multi-page PDF or a PPTX. Verify that a central loading indicator appears while the document is being processed.
2.  **Sidebar Scrolling**: Scroll the sidebar quickly. Verify that new thumbnails show a small loading spinner before the preview image appears.
3.  **PPTX Slides**: Navigate through PPTX slides. Verify that if a slide takes a moment to render, a spinner is visible.
