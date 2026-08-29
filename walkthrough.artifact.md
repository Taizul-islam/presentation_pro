# Walkthrough: Loading Indicators for Smoother UX

I have added comprehensive loading indicators throughout the app to provide clear visual feedback during document processing and preview rendering.

## Changes Made

### 1. Global Document Loading Overlay
- **Feedback**: When you pick a new PDF or PPTX file, a central loading overlay now appears with the message "Processing Document...".
- **Visuals**: Features a dimmed background and a white card with a `CircularProgressIndicator`, ensuring you know the app is working even during heavy background tasks like ZIP extraction or PDF parsing.

### 2. Sidebar Thumbnail Spinners
- **Image Previews**: Added a small, centered spinner that appears while images are being decoded and loaded into memory.
- **PDF Previews**: Integrated a loading state into the `PdfDocumentViewBuilder` so that each slide thumbnail shows a spinner while the PDF engine initializes.
- **Polished Feel**: Thumbnails now fade in smoothly once the loading spinner disappears.

### 3. Asynchronous PPTX Slide Rendering
- **On-Demand Loading**: Updated the `PptxSlideRenderer` to use a `FutureBuilder`.
- **User Benefit**: Large PPTX slides that take time to build will now show a centered spinner instead of a blank screen, making the on-demand rendering feel intentional and responsive.

## How to Test
1. **Pick a Large Document**: Tap the folder icon and select a large PDF or PPTX. You will see the global "Processing" card.
2. **Scroll the Sidebar**: Quickly scroll through the slide list. You'll see small spinners appearing and disappearing as thumbnails load.
3. **Navigate PPTX Slides**: When viewing a complex PPTX, notice the brief spinner that appears as the slide is rendered for the first time.
