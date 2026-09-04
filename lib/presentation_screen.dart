import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:window_manager/window_manager.dart';
import '../models/drawing_stroke.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/stroke_width_slider.dart';
import '../widgets/slide_thumbnail.dart';
import '../widgets/samsung_menu_item.dart';
import '../services/pptx_converter_libreoffice.dart';
import '../services/export_service.dart';

enum AppMode { preparation, teaching, desktop }

class PresentationScreen extends StatefulWidget {
  const PresentationScreen({Key? key}) : super(key: key);

  @override
  _PresentationScreenState createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen>
    with SingleTickerProviderStateMixin {
  bool _isDrawingMode = true;
  bool _isToolbarVisible = true;
  bool _isSidebarCollapsed = false;
  bool _isMenuVisible = false;
  bool _isModeSubMenuVisible = false;
  AppMode _currentMode = AppMode.preparation;
  
  Color _selectedColor = Colors.red;
  double _strokeWidth = 4.0;
  double _eraserWidth = 30.0;
  DrawingTool _selectedTool = DrawingTool.pen;
  Offset? _hoverPosition;
  
  int _currentPageIndex = 0;
  List<PresentationPage> _pages = [];
  DrawingStroke? _currentStroke;

  final List<List<DrawingStroke>> _undoHistory = [];
  final List<List<DrawingStroke>> _redoHistory = [];

  PdfDocument? _currentPdfDocument;
  bool _isLoadingDocument = false;
  double _loadingProgress = 0.0;
  String _loadingMessage = 'Processing Document...';

  final ScrollController _sidebarScrollController = ScrollController();
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPageIndex);
    _initializePages();
  }

  void _initializePages() {
    setState(() {
      _pages = List.generate(3, (index) => PresentationPage(
        pageNumber: index + 1,
        title: 'Blank Slide ${index + 1}',
        subtitle: 'Start writing or annotate',
        icon: Icons.note_add,
        contentType: PageContentType.image,
        contentPath: null,
        backgroundColor: Colors.white,
      ));
      _currentPageIndex = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _currentPdfDocument?.dispose();
    _sidebarScrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- Drawing State Methods ---

  void _enableDrawingMode() {
    setState(() {
      _isDrawingMode = true;
      _isToolbarVisible = true;
      _undoHistory.clear();
      _redoHistory.clear();
    });
  }

  void _disableDrawingMode() {
    setState(() {
      _isDrawingMode = false;
      _isToolbarVisible = false;
      _currentStroke = null;
      _isMenuVisible = false;
      _isSidebarCollapsed = false;
    });
  }

  void _startStroke(Offset position) {
    setState(() {
      _currentStroke = DrawingStroke(
        points: [position],
        color: _selectedColor,
        width: _selectedTool == DrawingTool.eraser ? _eraserWidth : _strokeWidth,
        tool: _selectedTool,
      );
    });
  }

  void _updateStroke(Offset position) {
    if (_currentStroke != null) {
      setState(() {
        _currentStroke!.points.add(position);
      });
    }
  }

  void _endStroke() {
    if (_currentStroke != null && _currentStroke!.points.length > 1) {
      setState(() {
        _undoHistory.add(List.from(_pages[_currentPageIndex].strokes));
        _redoHistory.clear();

        final updatedStrokes = List<DrawingStroke>.from(_pages[_currentPageIndex].strokes)
          ..add(_currentStroke!);
        _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
        _currentStroke = null;
        _pages = List.from(_pages);
      });
    } else {
      setState(() {
        _currentStroke = null;
      });
    }
  }

  void _undo() {
    if (_pages[_currentPageIndex].strokes.isNotEmpty || _undoHistory.isNotEmpty) {
      setState(() {
        if (_undoHistory.isNotEmpty) {
           _redoHistory.add(List.from(_pages[_currentPageIndex].strokes));
          _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(
            strokes: _undoHistory.removeLast(),
          );
          _pages = List.from(_pages);
        } else {
          _redoHistory.add(List.from(_pages[_currentPageIndex].strokes));
          _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: []);
          _pages = List.from(_pages);
        }
      });
    }
  }

  void _redo() {
    if (_redoHistory.isNotEmpty) {
      setState(() {
        _undoHistory.add(List.from(_pages[_currentPageIndex].strokes));
        _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(
          strokes: _redoHistory.removeLast(),
        );
        _pages = List.from(_pages);
      });
    }
  }

  void _clearStrokes() {
    setState(() {
      _undoHistory.add(List.from(_pages[_currentPageIndex].strokes));
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: []);
      _pages = List.from(_pages);
    });
  }

  // --- Document Loading Methods ---

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'pptx'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final paths = result.files.map((f) => f.path!).toList();
      
      // Check for document files first (PDF or PPTX)
      final pdfPath = paths.firstWhere((p) => p.toLowerCase().endsWith('.pdf'), orElse: () => '');
      final pptxPath = paths.firstWhere((p) => p.toLowerCase().endsWith('.pptx'), orElse: () => '');

      setState(() {
        _isLoadingDocument = true;
        _loadingProgress = 0.0;
        _loadingMessage = 'Processing Document...';
      });

      try {
        if (pdfPath.isNotEmpty) {
          await _loadPdf(pdfPath);
        } else if (pptxPath.isNotEmpty) {
          await _loadPptx(pptxPath);
        } else {
          // Load all selected images
          await _loadImages(paths);
        }
      } catch (e) {
        _showSnackBar('Error loading document: $e', Colors.red, Icons.error);
      } finally {
        setState(() {
          _isLoadingDocument = false;
        });
      }
    }
  }

  Future<void> _loadPdf(String path) async {
    setState(() => _loadingMessage = 'Loading PDF...');
    final document = await PdfDocument.openFile(path);
    _currentPdfDocument?.dispose();
    _currentPdfDocument = document;

    final List<PresentationPage> newPages = [];
    for (int i = 0; i < document.pages.length; i++) {
      final page = document.pages[i];
      newPages.add(PresentationPage(
        pageNumber: i + 1,
        title: 'PDF Page ${i + 1}',
        subtitle: 'From: ${path.split(Platform.pathSeparator).last}',
        icon: Icons.picture_as_pdf,
        contentType: PageContentType.pdf,
        contentPath: path,
        pdfPageIndex: i,
        aspectRatio: page.width / page.height,
      ));
    }

    setState(() {
      _pages = newPages;
      _currentPageIndex = 0;
    });
    _pageController.jumpToPage(0);
  }

  Future<void> _loadImages(List<String> paths) async {
    final List<PresentationPage> newPages = [];
    for (int i = 0; i < paths.length; i++) {
      final bytes = await File(paths[i]).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      newPages.add(PresentationPage(
        pageNumber: i + 1,
        title: 'Image ${i + 1}',
        subtitle: 'From: ${paths[i].split(Platform.pathSeparator).last}',
        icon: Icons.image,
        contentType: PageContentType.image,
        contentPath: paths[i],
        aspectRatio: image.width / image.height,
      ));
    }

    setState(() {
      _pages = newPages;
      _currentPageIndex = 0;
    });
    _pageController.jumpToPage(0);
  }

  Future<void> _loadPptx(String path) async {
    setState(() => _loadingMessage = 'Converting PPTX...');
    try {
      final imagePaths = await PptxConverterLibreOffice.convertPptxToImages(
        path,
        onProgress: (progress) {
          if (mounted) setState(() => _loadingProgress = progress);
        },
      );

      if (imagePaths.isEmpty) return;

      // Get aspect ratio from the first slide
      final firstBytes = await File(imagePaths.first).readAsBytes();
      final codec = await ui.instantiateImageCodec(firstBytes);
      final frame = await codec.getNextFrame();
      final ratio = frame.image.width / frame.image.height;

      final List<PresentationPage> newPages = [];
      for (int i = 0; i < imagePaths.length; i++) {
        newPages.add(PresentationPage(
          pageNumber: i + 1,
          title: 'Slide ${i + 1}',
          subtitle: 'From: ${path.split(Platform.pathSeparator).last}',
          icon: Icons.slideshow,
          contentType: PageContentType.image,
          contentPath: imagePaths[i],
          aspectRatio: ratio,
        ));
      }

      setState(() {
        _pages = newPages;
        _currentPageIndex = 0;
      });
      _pageController.jumpToPage(0);
    } catch (e) {
      _showSnackBar('Error loading PPTX: $e', Colors.red, Icons.error);
    }
  }

  // --- Export Methods ---

  Future<void> _exportAsPdf() async {
    setState(() {
      _isLoadingDocument = true;
      _loadingMessage = 'Preparing PDF...';
      _loadingProgress = 0;
    });
    try {
      final path = await ExportService.exportAsPdf(
        _pages, 
        'Presentation_Export',
        onProgress: (current, total) {
          setState(() {
            _loadingMessage = 'Rendering Page $current of $total...';
            _loadingProgress = current / total;
          });
        },
      );
      if (path != null) _showSnackBar('PDF Exported', Colors.green, Icons.check_circle);
    } finally {
      setState(() => _isLoadingDocument = false);
    }
  }

  Future<void> _exportAsPptx() async {
    setState(() {
      _isLoadingDocument = true;
      _loadingMessage = 'Preparing PPTX...';
      _loadingProgress = 0;
    });
    try {
      final path = await ExportService.exportAsPptx(
        _pages, 
        'Presentation_Export',
        onProgress: (current, total) {
          setState(() {
            _loadingMessage = 'Processing Slide $current of $total...';
            _loadingProgress = current / total;
          });
        },
      );
      if (path != null) _showSnackBar('PPTX Exported', Colors.green, Icons.check_circle);
    } finally {
      setState(() => _isLoadingDocument = false);
    }
  }

  Future<void> _printPresentation() async {
    print('DEBUG: _printPresentation button clicked');
    setState(() {
      _isLoadingDocument = true;
      _loadingMessage = 'Preparing for Print...';
      _loadingProgress = 0;
    });
    
    // Ensure UI is updated and overlay is visible before starting heavy work
    await Future.delayed(const Duration(milliseconds: 300));
    
    try {
      print('DEBUG: Calling ExportService.printPages...');
      // Decouple the call from the current animation frame
      Future.microtask(() async {
        await ExportService.printPages(
          _pages,
          onProgress: (current, total) {
            if (mounted) {
              setState(() {
                _loadingMessage = 'Rendering Page $current of $total...';
                _loadingProgress = current / total;
              });
            }
          },
        );
        if (mounted) setState(() => _isLoadingDocument = false);
      });
      print('DEBUG: Print task scheduled');
    } catch (e) {
      print('DEBUG: Error in _printPresentation schedule: $e');
      if (mounted) setState(() => _isLoadingDocument = false);
    }
  }

  // --- UI Builder Methods ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: _isDrawingMode ? null : _buildDefaultAppBar(),
      body: Stack(
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isSidebarCollapsed ? 0 : 180,
                child: _isSidebarCollapsed ? const SizedBox.shrink() : _buildSidebar(),
              ),
              if (_isDrawingMode && _currentMode != AppMode.teaching)
                GestureDetector(
                  onTap: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                  child: Container(
                    width: 24,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                    ),
                    child: Icon(
                      _isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              Expanded(child: _buildContentPage()),
            ],
          ),

          if (_isDrawingMode && (_isMenuVisible || _isModeSubMenuVisible))
            GestureDetector(
              onTap: () => setState(() {
                _isMenuVisible = false;
                _isModeSubMenuVisible = false;
              }),
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
              ),
            ),

          if (_isDrawingMode && _isMenuVisible)
            Positioned(
              left: 30,
              bottom: 80,
              child: _buildVerticalMenu(),
            ),

          if (_isDrawingMode)
            Positioned(
              left: 0,
              bottom: 20,
              child: _buildBottomLeftMenu(),
            ),

          // Stroke Width Slider
          if (_isDrawingMode && (_selectedTool == DrawingTool.pen || _selectedTool == DrawingTool.eraser || _selectedTool == DrawingTool.highlighter))
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: Center(
                child: SizedBox(
                  width: 300,
                  child: StrokeWidthSlider(
                    strokeWidth: _selectedTool == DrawingTool.eraser ? _eraserWidth : _strokeWidth,
                    selectedColor: _selectedColor,
                    onStrokeWidthChanged: (width) => setState(() {
                      if (_selectedTool == DrawingTool.eraser) {
                        _eraserWidth = width;
                      } else {
                        _strokeWidth = width;
                      }
                    }),
                    min: _selectedTool == DrawingTool.eraser ? 10.0 : 1.0,
                    max: _selectedTool == DrawingTool.eraser ? 100.0 : 15.0,
                    label: _selectedTool == DrawingTool.eraser ? 'Duster Size' : 'Stroke Width',
                  ),
                ),
              ),
            ),

          if (_isDrawingMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: _buildFloatingToolbar(),
            ),

          if (_isDrawingMode)
            Positioned(
              right: 0,
              bottom: 20,
              child: _buildSlideNavigation(),
            ),

          if (_isLoadingDocument) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildDefaultAppBar() {
    return AppBar(
      title: Text('Presentation Pro', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      actions: [
        IconButton(icon: const Icon(Icons.file_open), onPressed: _pickDocument),
        IconButton(icon: const Icon(Icons.palette), onPressed: _showBackgroundColorPicker),
        IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportAsPdf),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.draw),
            label: const Text('Annotate'),
            onPressed: _enableDrawingMode,
          ),
        ),
      ],
    );
  }

  Widget _buildContentPage() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: (index) => setState(() => _currentPageIndex = index),
      itemBuilder: (context, index) => _buildSlideItem(index),
    );
  }

  Widget _buildSlideItem(int index) {
    final page = _pages[index];
    final isCurrentPage = _currentPageIndex == index;
    final hasDrawing = page.strokes.isNotEmpty || (isCurrentPage && _currentStroke != null);
    final isTeachingMode = _currentMode == AppMode.teaching;

    Widget content = Stack(
      children: [
        Positioned.fill(child: _buildPageContent(page, hasDrawing: hasDrawing)),
        DrawingCanvas(
          strokes: page.strokes,
          currentStroke: isCurrentPage ? _currentStroke : null,
          selectedColor: _selectedColor,
          strokeWidth: _strokeWidth,
          eraserWidth: _eraserWidth,
          selectedTool: _selectedTool,
          hoverPosition: isCurrentPage ? _hoverPosition : null,
          onStrokeStart: _startStroke,
          onStrokeUpdate: _updateStroke,
          onStrokeEnd: _endStroke,
          onHoverUpdate: (pos) => setState(() => _hoverPosition = pos),
          onStrokesMoved: _handleStrokesMoved,
        ),
      ],
    );

    if (isTeachingMode) {
      return Container(
        color: page.backgroundColor ?? Colors.white,
        child: content,
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: AspectRatio(
          aspectRatio: page.aspectRatio ?? 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: page.backgroundColor ?? Colors.white,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent(PresentationPage page, {bool hasDrawing = false}) {
    switch (page.contentType) {
      case PageContentType.pdf:
        if (_currentPdfDocument == null) return _buildPlaceholder(page, isHidden: hasDrawing);
        return Center(
          child: PdfPageView(
            document: _currentPdfDocument!,
            pageNumber: page.pdfPageIndex! + 1,
          ),
        );
      case PageContentType.image:
        if (page.contentPath == null) return _buildPlaceholder(page, isHidden: hasDrawing);
        return Image.file(
          File(page.contentPath!),
          fit: _currentMode == AppMode.teaching ? BoxFit.contain : BoxFit.contain,
        );
      default:
        return _buildPlaceholder(page, isHidden: hasDrawing);
    }
  }

  Widget _buildPlaceholder(PresentationPage page, {bool isHidden = false}) {
    if (isHidden) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(page.icon, size: 64, color: Colors.grey),
          Text(page.title, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(page.subtitle, style: GoogleFonts.poppins(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: Colors.grey.shade200,
      child: ListView.builder(
        controller: _sidebarScrollController,
        itemCount: _pages.length,
        itemBuilder: (context, index) => SlideThumbnail(
          page: _pages[index],
          isSelected: _currentPageIndex == index,
          onTap: () => _goToPage(index),
        ),
      ),
    );
  }

  Widget _buildBottomLeftMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.horizontal(right: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.menu), onPressed: () => setState(() => _isMenuVisible = !_isMenuVisible)),
          IconButton(icon: const Icon(Icons.monitor), onPressed: () {}),
          IconButton(icon: const Icon(Icons.build), onPressed: () {}),
          IconButton(icon: const Icon(Icons.cloud_upload), onPressed: _pickDocument),
          IconButton(icon: const Icon(Icons.zoom_in), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildFloatingToolbar() {
    return Center(
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolbarIcon(Icons.near_me, DrawingTool.selector, _selectedTool == DrawingTool.selector),
            _buildToolbarIcon(Icons.edit, DrawingTool.pen, _selectedTool == DrawingTool.pen),
            IconButton(
              icon: const Icon(Icons.format_color_fill, size: 22),
              onPressed: _showBackgroundColorPicker,
              tooltip: 'Background Color',
            ),
            _buildToolbarIcon(Icons.auto_fix_high, DrawingTool.eraser, _selectedTool == DrawingTool.eraser),
            _buildToolbarIcon(Icons.back_hand, null, false),
            _buildToolbarIcon(Icons.text_fields, DrawingTool.highlighter, _selectedTool == DrawingTool.highlighter),
            GestureDetector(
              onTap: _showDrawingColorPicker,
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _selectedColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
              ),
            ),
            const VerticalDivider(width: 20),
            IconButton(icon: const Icon(Icons.undo), onPressed: _undo),
            IconButton(icon: const Icon(Icons.redo), onPressed: _redo),
          ],
        ),
      ),
    );
  }

  void _handleStrokesMoved(List<int> indices, Offset delta) {
    if (indices.isEmpty || delta == Offset.zero) return;

    setState(() {
      _undoHistory.add(List<DrawingStroke>.from(_pages[_currentPageIndex].strokes));
      _redoHistory.clear();

      final updatedStrokes = List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      for (final index in indices) {
        updatedStrokes[index] = updatedStrokes[index].translate(delta);
      }
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
      _pages = List.from(_pages);
    });
  }

  void _showDrawingColorPicker() {
    Color selectedColor = _selectedColor;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Drawing Color', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _buildColorPalette(selectedColor, (color) => setDialogState(() => selectedColor = color)),
                    const SizedBox(height: 12),
                    _buildHueSlider(selectedColor, (color) => setDialogState(() => selectedColor = color)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _selectedColor = selectedColor);
                            Navigator.pop(dialogContext);
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbarIcon(IconData icon, DrawingTool? tool, bool isSelected) {
    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.indigo : Colors.grey),
      onPressed: tool == null ? null : () => setState(() => _selectedTool = tool),
    );
  }

  Widget _buildSlideNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.horizontal(left: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.arrow_left), onPressed: _previousPage),
          Text('${_currentPageIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.arrow_right), onPressed: _nextPage),
          IconButton(icon: const Icon(Icons.add), onPressed: _addNewSlide),
        ],
      ),
    );
  }

  Widget _buildVerticalMenu() {
    return SizedBox(
      width: 300, // Explicit width to allow hit-testing on the sub-menu
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SamsungMenuItem(
                  icon: Icons.note_add,
                  label: 'New',
                  onTap: () {
                    print('DEBUG: New Presentation clicked');
                    setState(() => _isMenuVisible = false);
                    _initializePages();
                  },
                ),
                SamsungMenuItem(
                  icon: Icons.file_open,
                  label: 'Open',
                  onTap: () {
                    print('DEBUG: Open Document clicked');
                    setState(() => _isMenuVisible = false);
                    _pickDocument();
                  },
                ),
                SamsungMenuItem(
                  icon: Icons.delete_outline,
                  label: 'Clear',
                  onTap: () {
                    print('DEBUG: Clear Canvas clicked');
                    setState(() => _isMenuVisible = false);
                    _clearStrokes();
                  },
                ),
                SamsungMenuItem(
                  icon: Icons.print_outlined,
                  label: 'Print',
                  onTap: () {
                    print('DEBUG: Print clicked');
                    setState(() => _isMenuVisible = false);
                    _printPresentation();
                  },
                ),
                const Divider(height: 1),
                SamsungMenuItem(
                  icon: Icons.picture_as_pdf,
                  label: 'Export PDF',
                  onTap: () {
                    print('DEBUG: Export PDF clicked');
                    setState(() => _isMenuVisible = false);
                    _exportAsPdf();
                  },
                ),
                SamsungMenuItem(
                  icon: Icons.slideshow,
                  label: 'Export PPTX',
                  onTap: () {
                    print('DEBUG: Export PPTX clicked');
                    setState(() => _isMenuVisible = false);
                    _exportAsPptx();
                  },
                ),
                const Divider(height: 1),
                SamsungMenuItem(
                  icon: Icons.computer,
                  label: 'Mode',
                  trailingIcon: Icons.arrow_right,
                  onTap: () {
                    print('DEBUG: Mode Menu toggled');
                    setState(() => _isModeSubMenuVisible = !_isModeSubMenuVisible);
                  },
                ),
              ],
            ),
          ),
          if (_isModeSubMenuVisible)
            Positioned(
              left: 155,
              bottom: 0,
              child: Container(
                width: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeItem(
                      icon: Icons.monitor,
                      label: 'Teaching',
                      onTap: () {
                        print('DEBUG: Switching to Teaching Mode');
                        _switchMode(AppMode.teaching);
                      },
                    ),
                    _buildModeItem(
                      icon: Icons.edit_note,
                      label: 'Preparation',
                      onTap: () {
                        print('DEBUG: Switching to Preparation Mode');
                        _switchMode(AppMode.preparation);
                      },
                    ),
                    _buildModeItem(
                      icon: Icons.desktop_windows,
                      label: 'Desktop',
                      onTap: () {
                        print('DEBUG: Switching to Desktop Mode');
                        _switchMode(AppMode.desktop);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeItem({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _switchMode(AppMode mode) async {
    setState(() {
      _currentMode = mode;
      _isMenuVisible = false;
      _isModeSubMenuVisible = false;
      if (mode == AppMode.teaching) {
        _isSidebarCollapsed = true;
      } else if (mode == AppMode.preparation) {
        _isSidebarCollapsed = false;
      }
    });

    if (mode == AppMode.desktop) {
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        await windowManager.minimize();
      }
    }
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              width: 380,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _loadingMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingProgress > 0) ...[
                    Text(
                      '${(_loadingProgress * 100).toInt()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _loadingProgress,
                        minHeight: 8,
                        backgroundColor: Colors.indigo.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigo),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Methods ---

  void _goToPage(int index) {
    setState(() => _currentPageIndex = index);
    _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _addNewSlide() {
    setState(() {
      _pages.add(PresentationPage(
        pageNumber: _pages.length + 1,
        title: 'Slide ${_pages.length + 1}',
        subtitle: 'New Slide',
        icon: Icons.note_add,
      ));
    });
  }

  void _previousPage() {
    if (_currentPageIndex > 0) _goToPage(_currentPageIndex - 1);
  }

  void _nextPage() {
    if (_currentPageIndex < _pages.length - 1) _goToPage(_currentPageIndex + 1);
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [Icon(icon, color: Colors.white), const SizedBox(width: 8), Text(message)]),
      backgroundColor: color,
    ));
  }

  void _showBackgroundColorPicker() {
    final currentPage = _pages[_currentPageIndex];
    final isBlankSlide = currentPage.contentPath == null || currentPage.contentPath!.isEmpty;

    if (!isBlankSlide) {
      _showSnackBar('Background color only for blank slides', Colors.grey, Icons.info);
      return;
    }

    Color selectedColor = currentPage.backgroundColor ?? Colors.white;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.palette, color: Colors.purple, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Background Color',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                          onPressed: () => Navigator.pop(dialogContext),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Text(
                          '#${selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                          style: TextStyle(
                            color: selectedColor.computeLuminance() > 0.5
                                ? Colors.black87
                                : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildColorPalette(selectedColor, (color) {
                      setDialogState(() => selectedColor = color);
                    }),
                    const SizedBox(height: 12),
                    _buildHueSlider(selectedColor, (color) {
                      setDialogState(() => selectedColor = color);
                    }),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildQuickColorDot(Colors.white, dialogContext, (color) {
                           setDialogState(() => selectedColor = color);
                        }),
                        _buildQuickColorDot(Colors.black, dialogContext, (color) {
                           setDialogState(() => selectedColor = color);
                        }),
                        _buildQuickColorDot(const Color(0xFFFEEBEB), dialogContext, (color) {
                           setDialogState(() => selectedColor = color);
                        }),
                        _buildQuickColorDot(const Color(0xFFE8F5E9), dialogContext, (color) {
                           setDialogState(() => selectedColor = color);
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              final updatedPage = _pages[_currentPageIndex].copyWith(
                                backgroundColor: selectedColor,
                              );
                              _pages[_currentPageIndex] = updatedPage;
                              _pages = List.from(_pages);
                            });
                            Navigator.pop(dialogContext);
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorPalette(Color currentColor, Function(Color) onColorChanged) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const height = 150.0;
        final hsv = HSVColor.fromColor(currentColor);

        return GestureDetector(
          onPanUpdate: (details) {
            final dx = (details.localPosition.dx / width).clamp(0.0, 1.0);
            final dy = (details.localPosition.dy / height).clamp(0.0, 1.0);
            final newColor = HSVColor.fromAHSV(1.0, hsv.hue, dx, 1.0 - dy).toColor();
            onColorChanged(newColor);
          },
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: HSVColor.fromAHSV(1.0, hsv.hue, 1.0, 1.0).toColor(),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.white, Colors.transparent],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black],
                    ),
                  ),
                ),
                Positioned(
                  left: (hsv.saturation * width) - 8,
                  top: ((1.0 - hsv.value) * height) - 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHueSlider(Color currentColor, Function(Color) onColorChanged) {
    final currentHue = HSVColor.fromColor(currentColor).hue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return GestureDetector(
          onPanUpdate: (details) {
            final hue = (details.localPosition.dx / width * 360).clamp(0.0, 360.0);
            final hsv = HSVColor.fromColor(currentColor);
            onColorChanged(HSVColor.fromAHSV(1.0, hue, hsv.saturation, hsv.value).toColor());
          },
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [
                  Colors.red,
                  Colors.yellow,
                  Colors.green,
                  Colors.cyan,
                  Colors.blue,
                  Colors.purple,
                  Colors.red,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: (currentHue / 360 * width) - 8,
                  top: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickColorDot(Color color, BuildContext dialogContext, Function(Color) onColorSelected) {
    return GestureDetector(
      onTap: () => onColorSelected(color),
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
      ),
    );
  }
}
