# 🎓 Presentation Pro

**Presentation Pro** is a modern, interactive presentation, digital whiteboard, and vector annotation application designed for teachers, lecturers, presenters, and annotators. Built with **Flutter**, it delivers high-DPI document rendering, real-time vector ink drawing, ergonomic physical dusters, math geometry shapes, and presentation tools across **Windows, macOS, Linux, iOS, Android, and Web**.

---

## ✨ Key Features & Capabilities

### 📄 1. Document Conversion & High-DPI Rendering
* **High-DPI PDF Viewer**: Renders PDF presentation slides at **300 DPI** on the main stage and **180 DPI** in sidebar thumbnails using `pdfrx` and `pdfium`.
* **PowerPoint (PPTX) Converter**: Automatic background conversion pipeline powered by headless **LibreOffice** and **Poppler** (`pdftoppm -jpeg -jpegopt quality=90 -r 180`).
* **Image Slides**: Import PNG and JPG images with crisp scaling and aspect-ratio preservation.

### 🖊️ 2. Vector Ink Drawing & Highlighting
* **Pen & Marker Tools**: High-precision vector pen drawing with smooth quadratic bezier curves and translucent marker highlighter (`Icons.brush`).
* **Real Physical Dusters**: 3 duster styles (**Classroom Felt Duster**, **Microfiber Sponge**, and **Precision Eraser**) with 3D cursor rendering and 5 ergonomic grip angles (`Right Hand 15°`, `Horizontal 0°`, `Left Hand -15°`, `Vertical 90°`, `Auto`).
* **Active Vector Point-Erasing**: Erasing splits or deletes stroke points in memory so erased lines never reappear when selected or moved.

### 📐 3. Vector Geometric Shapes & Math Tools
* **2D Shapes**: Rectangle, Square, Circle, Oval, Right/Equilateral Triangle, Diamond, and 5-Point Star.
* **Vector Lines & Arrows**: Proportional 25° acute-angle vector arrows (`X → Y`) that scale dynamically with stroke width.
* **Math & 3D Geometry**: Coordinate Axes (X-Y Graph Grid) with clean origin corner, and 3D Wireframe Cubes.
* **1-Tap Direct Selection & Drag-and-Drop**: Tap any shape once to select, scale, rotate, or drag-and-drop it across the slide canvas.

### 📝 4. Text Boxes & Top Sticky Formatting Banner
* **Interactive Text Boxes**: Multi-line vector text with minimalist Figma-style 9px corner handles and cursor feedback.
* **Top Sticky Formatting Banner**: A top-centered 46px pill toolbar providing:
  * Font Family Dropdown (`Roboto`, `Poppins`, `Open Sans`, `Lato`)
  * Font Size Selector (`12` to `72`)
  * Bold, Italic, Underline Toggles
  * Live Color Swatch (opens Smart Color Picker)
  * Alignment Controls (Left, Center, Right, Justify)
  * Delete & Close Actions

### 🎯 5. Presentation & Teaching Tools
* **Laser Pointer**: Smooth 5px quadratic bezier continuous glowing laser beam with a 20px glowing tip cursor.
* **Torch Spotlight**: Dims background overlay with a clear aperture spotlight beam.
* **Teaching Mode**: 1-tap Monitor button (`Icons.monitor`) maximizes the window, expands the presentation stage, and shows toast notifications.
* **Pan & Zoom Navigation**: 500% smooth 2D gesture zoom and pan with a floating zoom control bar (`-`, `100%`, `+`, `Reset 100%`).

### 🎨 6. Smart Color Picker & Themes
* **Smart Color Picker**: Compact 360px dialog featuring live color preview, `#HEX` code badge with 1-tap Copy, preset swatches, 2D saturation/brightness box, and rainbow hue slider.
* **Dark & Light Themes**: Light Theme default with dark slate blackboard (`#181825`) support in Dark Mode. Theme preferences persist via `SharedPreferences`.

### 📄 7. PDF Export & Printing
* **Isolated Canvas Layering**: PDF export and printing wrap strokes in `canvas.saveLayer()`, guaranteeing eraser strokes **never burn holes through PDF pages or background images**.

---

## 🚀 Getting Started

### Prerequisites
* **Flutter SDK**: `^3.12.2` or later
* **Dart SDK**: `^3.12.0`
* **Operating System**: Windows 10/11, macOS 12+, Linux, Android, or iOS

### Local Setup & Running
1. **Clone the repository**:
   ```bash
   git clone https://github.com/Taizul-islam/presentation_pro.git
   cd presentation_pro
   ```
2. **Install dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run the application**:
   ```bash
   flutter run
   ```

---

## 📦 Windows Builds & Installation

The project includes an automated GitHub Actions CI/CD workflow (`.github/workflows/build-windows.yml`) that compiles both **Setup Installer EXE** and **Portable ZIP** packages on every push.

### Download Release Artifacts
1. Visit the [GitHub Actions Dashboard](https://github.com/Taizul-islam/presentation_pro/actions).
2. Select the latest workflow run.
3. Download either build artifact:
   * **`PresentationPro_Setup_Installer`** (`PresentationPro_Setup.exe` — Windows Setup Wizard with Desktop Shortcut, Start Menu entry, and Uninstaller).
   * **`PresentationPro_Portable`** (`PresentationPro_Portable.zip` — Portable Version that runs anywhere without installation).

---

## 🛠️ Project Architecture & Structure

```
lib/
├── main.dart                          # App entrypoint & WindowManager setup
├── presentation_screen.dart           # Main presentation stage & workspace controller
├── splash_screen.dart                 # Splash screen
├── models/
│   └── drawing_stroke.dart            # Vector stroke, shape, text & page data models
├── services/
│   ├── export_service.dart            # PDF export & printing service
│   ├── handwriting_recognizer.dart    # OCR service
│   ├── pptx_converter_libreoffice.dart # LibreOffice PPTX conversion service
│   └── theme_notifier.dart            # Light/Dark theme notifier & preferences
└── widgets/
    ├── color_picker.dart              # Smart Color Picker dialog
    ├── drawing_canvas.dart            # Vector canvas painter & gesture handler
    ├── drawing_text_widget.dart       # Interactive vector text box with handles
    ├── duster_selector.dart           # Real physical duster settings toolbar
    ├── handwriting_toolbar.dart       # Handwriting OCR control panel
    ├── laser_selector.dart            # Laser pointer & torch spotlight toolbar
    ├── samsung_menu_item.dart         # Popover menu item widget
    ├── settings_dialog.dart           # App settings dialog
    ├── shape_selector.dart            # Geometric shapes library popover
    ├── slide_thumbnail.dart           # Sidebar slide thumbnail card & painter
    ├── stroke_width_slider.dart       # Stroke width & color preview slider
    └── text_formatting_dialog.dart    # Top sticky text formatting banner
```

---

## 📜 License & Credits

* **Developer**: Taizul Islam
* **Repository**: [https://github.com/Taizul-islam/presentation_pro](https://github.com/Taizul-islam/presentation_pro)
* Built with [Flutter](https://flutter.dev) and [Dart](https://dart.dev).
