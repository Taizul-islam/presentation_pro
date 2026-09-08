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
import '../widgets/drawing_text_widget.dart';
import '../widgets/text_formatting_dialog.dart';
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
  bool _isContextSubMenuVisible = false;
  bool _isThicknessSubMenuVisible = false;
  bool _isTextFormattingVisible = false;
  bool _isAdjustingThickness = false;
  AppMode _currentMode = AppMode.preparation;
  Rect? _activeSelectionRect;
  List<int> _activeSelectedIndices = [];
  int? _activeTextIndex;
  double _currentSelectionThickness = 4.0;
  
  Color _selectedColor = Colors.red;
  double _strokeWidth = 4.0;
  double _eraserWidth = 30.0;
  DrawingTool _selectedTool = DrawingTool.pen;
  Offset? _hoverPosition;
  
  int _currentPageIndex = 0;
  List<PresentationPage> _pages = [];
  DrawingStroke? _currentStroke;

  final List<PresentationPage> _undoHistory = [];
  final List<PresentationPage> _redoHistory = [];

  PdfDocument? _currentPdfDocument;
  bool _isLoadingDocument = false;
  double _loadingProgress = 0.0;
  String _loadingMessage = 'Processing Document...';

  final ScrollController _sidebarScrollController = ScrollController();
  final ScrollController _contextMenuScrollController = ScrollController();
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
    _contextMenuScrollController.dispose();
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
        _saveToHistory();

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

  void _saveToHistory() {
    _undoHistory.add(_pages[_currentPageIndex]);
    _redoHistory.clear();
    if (_undoHistory.length > 50) _undoHistory.removeAt(0);
  }

  void _undo() {
    if (_undoHistory.isNotEmpty) {
      setState(() {
        _redoHistory.add(_pages[_currentPageIndex]);
        _pages[_currentPageIndex] = _undoHistory.removeLast();
        _pages = List.from(_pages);
        _activeTextIndex = null;
        _activeSelectionRect = null;
      });
    }
  }

  void _redo() {
    if (_redoHistory.isNotEmpty) {
      setState(() {
        _undoHistory.add(_pages[_currentPageIndex]);
        _pages[_currentPageIndex] = _redoHistory.removeLast();
        _pages = List.from(_pages);
      });
    }
  }

  void _clearStrokes() {
    setState(() {
      _saveToHistory();
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: [], texts: []);
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
      if (path != null) {
        _showSnackBar('PDF Exported to: ${path.split(Platform.pathSeparator).last}', Colors.green, Icons.check_circle);
      } else {
        _showSnackBar('Export cancelled or failed. Check permissions.', Colors.orange, Icons.warning);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red, Icons.error);
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
      if (path != null) {
        _showSnackBar('PPTX Exported to: ${path.split(Platform.pathSeparator).last}', Colors.green, Icons.check_circle);
      } else {
        _showSnackBar('Export failed. Make sure the file isn\'t open elsewhere.', Colors.orange, Icons.warning);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red, Icons.error);
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
        try {
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
        } catch (e) {
           _showSnackBar('Printing failed: $e', Colors.red, Icons.error);
        } finally {
          if (mounted) setState(() => _isLoadingDocument = false);
        }
      });
      print('DEBUG: Print task scheduled');
    } catch (e) {
      print('DEBUG: Error in _printPresentation schedule: $e');
      if (mounted) setState(() => _isLoadingDocument = false);
      _showSnackBar('Error: ${e.toString()}', Colors.red, Icons.error);
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
      onPageChanged: (index) {
        setState(() {
          _currentPageIndex = index;
          _activeTextIndex = null;
          _activeSelectionRect = null;
          _isContextSubMenuVisible = false;
          _isThicknessSubMenuVisible = false;
          _isTextFormattingVisible = false;
        });
      },
      itemBuilder: (context, index) => _buildSlideItem(index),
    );
  }

  Widget _buildSlideItem(int index) {
    final page = _pages[index];
    final isCurrentPage = _currentPageIndex == index;
    final hasDrawing = page.strokes.isNotEmpty || page.texts.isNotEmpty || (isCurrentPage && _currentStroke != null);
    final isTeachingMode = _currentMode == AppMode.teaching;

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget buildContent(double slideWidth, double slideHeight) {
          return Stack(
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
                onStrokesScaled: _handleStrokesScaled,
                onStrokesRotated: _handleStrokesRotated,
                onSelectionChanged: (rect, indices) {
                  _cleanupEmptyTexts();
                  setState(() {
                    _activeSelectionRect = rect;
                    _activeSelectedIndices = indices;
                    _isContextSubMenuVisible = false;
                    _isThicknessSubMenuVisible = false;
                    
                    if (indices.isNotEmpty) {
                      _currentSelectionThickness = _pages[_currentPageIndex].strokes[indices.first].width;
                    }
                  });
                },
                onTextCreated: _handleTextCreated,
                onInteraction: () {
                  _cleanupEmptyTexts();
                  if (_isMenuVisible || _isModeSubMenuVisible || _isContextSubMenuVisible || _isThicknessSubMenuVisible) {
                    setState(() {
                      _isMenuVisible = false;
                      _isModeSubMenuVisible = false;
                      _isContextSubMenuVisible = false;
                      _isThicknessSubMenuVisible = false;
                    });
                  }
                },
              ),
              ...page.texts.asMap().entries.map((entry) {
                final idx = entry.key;
                final text = entry.value;

                // Scale normalized text to current slide pixels
                final scaledText = text.copyWith(
                  position: Offset(text.position.dx * slideWidth, text.position.dy * slideHeight),
                  width: text.width * (slideWidth / 1920.0), // Use 1920 as base width for text box
                  fontSize: text.fontSize * (slideWidth / 1920.0),
                );

                return DrawingTextWidget(
                  element: scaledText,
                  isSelected: isCurrentPage && _activeTextIndex == idx,
                  onTextChanged: (val) => _updateText(idx, val),
                  onPositionChanged: (delta) => _moveText(idx, Offset(delta.dx / slideWidth, delta.dy / slideHeight)),
                  onWidthChanged: (val) => _resizeTextWidth(idx, val / (slideWidth / 1920.0)),
                  onScaleChanged: (w, s) => _scaleText(idx, w / (slideWidth / 1920.0), s / (slideWidth / 1920.0)),
                  onInteractionStart: () => _saveToHistory(),
                  onTap: () => setState(() {
                    _activeTextIndex = idx;
                    _isTextFormattingVisible = true;
                  }),
                );
              }),
              if (isCurrentPage && _activeSelectionRect != null && _selectedTool == DrawingTool.selector) ...[
                _buildVerticalSelectionToolbar(_activeSelectionRect!, slideWidth, slideHeight),
                if (_isContextSubMenuVisible)
                  _buildExpandedContextMenu(_activeSelectionRect!, slideWidth, slideHeight),
                if (_isContextSubMenuVisible && _isThicknessSubMenuVisible)
                  _buildThicknessSubMenu(_activeSelectionRect!, slideWidth, slideHeight),
              ],
              if (isCurrentPage && 
                  _activeTextIndex != null && 
                  _isTextFormattingVisible && 
                  _activeTextIndex! >= 0 && 
                  _activeTextIndex! < page.texts.length)
                Positioned(
                  right: 20,
                  top: 20,
                  child: TextFormattingDialog(
                    element: page.texts[_activeTextIndex!],
                    onChanged: (updated) => _updateTextElement(_activeTextIndex!, updated),
                    onClose: () => setState(() => _isTextFormattingVisible = false),
                  ),
                ),
            ],
          );
        }

        if (isTeachingMode) {
          return Container(
            color: page.backgroundColor ?? Colors.white,
            child: buildContent(constraints.maxWidth, constraints.maxHeight),
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
                  panEnabled: _selectedTool == DrawingTool.hand,
                  scaleEnabled: _selectedTool == DrawingTool.hand,
                  child: LayoutBuilder(
                    builder: (context, slideConstraints) {
                      return buildContent(slideConstraints.maxWidth, slideConstraints.maxHeight);
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
            _buildToolbarIcon(Icons.title, DrawingTool.text, _selectedTool == DrawingTool.text),
            _buildToolbarIcon(Icons.back_hand, DrawingTool.hand, _selectedTool == DrawingTool.hand),
            _buildToolbarIcon(Icons.highlight, DrawingTool.highlighter, _selectedTool == DrawingTool.highlighter),
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
      _saveToHistory();

      final updatedStrokes = List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      for (final index in indices) {
        updatedStrokes[index] = updatedStrokes[index].translate(delta);
      }
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
      _pages = List.from(_pages);
    });
  }

  void _handleStrokesScaled(List<int> indices, double scaleX, double scaleY, Offset pivot) {
    if (indices.isEmpty) return;

    setState(() {
      _saveToHistory();

      final updatedStrokes = List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      for (final index in indices) {
        updatedStrokes[index] = updatedStrokes[index].scale(scaleX, scaleY, pivot);
      }
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
      _pages = List.from(_pages);
    });
  }

  void _handleStrokesRotated(List<int> indices, double angle, Offset center) {
    if (indices.isEmpty) return;

    setState(() {
      _saveToHistory();

      final updatedStrokes = List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      for (final index in indices) {
        updatedStrokes[index] = updatedStrokes[index].rotate(angle, center);
      }
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
      _pages = List.from(_pages);
    });
  }

  void _deleteSelectedStrokes() {
    print('DEBUG: _deleteSelectedStrokes activeSelectedIndices=${_activeSelectedIndices.length}');
    if (_activeSelectedIndices.isEmpty) return;
    setState(() {
      _saveToHistory();

      final updatedStrokes = List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      final sortedIndices = List<int>.from(_activeSelectedIndices)..sort((a, b) => b.compareTo(a));
      for (final index in sortedIndices) {
        updatedStrokes.removeAt(index);
      }
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
      _pages = List.from(_pages);
      _activeSelectedIndices = [];
      _activeSelectionRect = null;
    });
  }

  void _duplicateSelectedStrokes() {
    if (_activeSelectedIndices.isEmpty) return;
    setState(() {
      _saveToHistory();

      final updatedStrokes = List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      final offset = const Offset(20, 20);
      for (final index in _activeSelectedIndices) {
        updatedStrokes.add(_pages[_currentPageIndex].strokes[index].translate(offset));
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

  void _cleanupEmptyTexts() {
    final currentPage = _pages[_currentPageIndex];
    if (currentPage.texts.any((t) => t.text.trim().isEmpty)) {
      setState(() {
        final updatedTexts = currentPage.texts.where((t) => t.text.trim().isNotEmpty).toList();
        _pages[_currentPageIndex] = currentPage.copyWith(texts: updatedTexts);
        _pages = List.from(_pages);
        _activeTextIndex = null;
        _isTextFormattingVisible = false;
      });
    }
  }

  Widget _buildToolbarIcon(IconData icon, DrawingTool? tool, bool isSelected) {
    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.indigo : Colors.grey),
      onPressed: tool == null ? null : () {
        _cleanupEmptyTexts();
        setState(() => _selectedTool = tool);
      },
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

  Widget _buildVerticalSelectionToolbar(Rect rect, double slideWidth, double slideHeight) {
    const double toolbarWidth = 45.0;
    const double toolbarHeight = 225.0;
    const double expandedMenuWidth = 220.0;

    bool hasSpaceOnRight = (rect.right + 10 + toolbarWidth + expandedMenuWidth + 20) < slideWidth;
    double left = hasSpaceOnRight ? (rect.right + 10) : (rect.left - 10 - toolbarWidth);
    double top = rect.top.clamp(10.0, (slideHeight - toolbarHeight - 20).clamp(10.0, slideHeight));

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () {}, // Shield
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: toolbarWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildContextAction(Icons.delete_outline, _deleteSelectedStrokes, Colors.red),
              _buildContextAction(Icons.palette_outlined, _showDrawingColorPicker, Colors.indigo),
              _buildContextAction(Icons.layers_outlined, () {}, Colors.grey.shade700),
              _buildContextAction(Icons.copy_outlined, _duplicateSelectedStrokes, Colors.grey.shade700),
              _buildContextAction(Icons.menu, () {
                setState(() {
                  _isContextSubMenuVisible = !_isContextSubMenuVisible;
                  if (!_isContextSubMenuVisible) _isThicknessSubMenuVisible = false;
                });
              }, Colors.grey.shade700),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContextMenu(Rect rect, double slideWidth, double slideHeight) {
    const double toolbarWidth = 45.0;
    const double toolbarHeight = 225.0;
    const double expandedMenuWidth = 220.0;
    const double maxMenuHeight = 350.0;

    bool hasSpaceOnRight = (rect.right + 10 + toolbarWidth + expandedMenuWidth + 20) < slideWidth;
    double toolbarTop = rect.top.clamp(10.0, (slideHeight - toolbarHeight - 20).clamp(10.0, slideHeight));
    bool spaceBelow = (slideHeight - toolbarTop) > (maxMenuHeight + 20);

    double left = hasSpaceOnRight ? (rect.right + 10 + toolbarWidth + 10) : (rect.left - 10 - toolbarWidth - 10 - expandedMenuWidth);
    double? top = spaceBelow ? toolbarTop : null;
    double? bottom = spaceBelow ? null : (slideHeight - (toolbarTop + toolbarHeight)); // Align with toolbar bottom

    return Positioned(
      left: left,
      top: top,
      bottom: bottom,
      child: GestureDetector(
        onTap: () {}, // Shield
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: expandedMenuWidth,
          constraints: BoxConstraints(maxHeight: maxMenuHeight),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Scrollbar(
              controller: _contextMenuScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _contextMenuScrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildExpandedMenuItem(Icons.lock_outline, 'Lock', _toggleLockSelected),
                    _buildExpandedMenuItem(
                      Icons.line_weight,
                      'Line thickness',
                      () => setState(() => _isThicknessSubMenuVisible = !_isThicknessSubMenuVisible),
                      hasSubmenu: true,
                      isActive: _isThicknessSubMenuVisible,
                    ),
                    _buildExpandedMenuItem(Icons.format_color_fill, 'Fill color', () {}, hasSubmenu: true),
                    _buildExpandedMenuItem(Icons.add_to_photos_outlined, 'Add to resource library', () {}),
                    _buildExpandedMenuItem(Icons.link, 'Edit hyperlink', () {}),
                    _buildExpandedMenuItem(Icons.compare_arrows, 'Mirror', _mirrorSelected),
                    _buildExpandedMenuItem(Icons.unfold_more, 'Flip', _flipSelected),
                    _buildExpandedMenuItem(Icons.copy_all, 'Copy', _duplicateSelectedStrokes),
                    _buildExpandedMenuItem(Icons.content_cut, 'Shear', () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThicknessSubMenu(Rect rect, double slideWidth, double slideHeight) {
    const double toolbarWidth = 45.0;
    const double toolbarHeight = 225.0;
    const double expandedMenuWidth = 220.0;
    const double thicknessSubMenuWidth = 180.0;

    bool hasSpaceOnRight = (rect.right + 10 + toolbarWidth + expandedMenuWidth + 20) < slideWidth;
    double toolbarTop = rect.top.clamp(10.0, (slideHeight - toolbarHeight - 20).clamp(10.0, slideHeight));

    // Horizontal position: outside the expanded menu
    double left = hasSpaceOnRight 
        ? (rect.right + 10 + toolbarWidth + 10 + expandedMenuWidth + 5)
        : (rect.left - 10 - toolbarWidth - 10 - expandedMenuWidth - 5 - thicknessSubMenuWidth);

    // Vertical position: align with the "Line thickness" item in the context menu
    // The items are ~45px high, and it's the 2nd item.
    double top = toolbarTop + 45.0;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () {}, // Shield
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: thicknessSubMenuWidth,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.line_weight, size: 16, color: Colors.grey.shade600),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: _currentSelectionThickness,
                    min: 1.0,
                    max: 30.0,
                    activeColor: Colors.indigo,
                    inactiveColor: Colors.grey.shade200,
                    onChangeStart: (val) {
                      _isAdjustingThickness = true;
                      _saveToHistory();
                    },
                    onChanged: (val) {
                      setState(() => _currentSelectionThickness = val);
                      _updateSelectedStrokesWidth(val);
                    },
                    onChangeEnd: (val) {
                      _isAdjustingThickness = false;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedMenuItem(IconData icon, String label, VoidCallback onTap, {bool hasSubmenu = false, bool isActive = false}) {
    return InkWell(
      onTap: () {
        onTap();
        if (!hasSubmenu) setState(() => _isContextSubMenuVisible = false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.indigo.withOpacity(0.05) : Colors.transparent,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.indigo : Colors.grey.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12, 
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.indigo : Colors.grey.shade800,
                ),
              ),
            ),
            if (hasSubmenu) Icon(Icons.arrow_right, size: 16, color: isActive ? Colors.indigo : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _toggleLockSelected() {
    if (_activeSelectedIndices.isEmpty) return;
    setState(() {
      _saveToHistory();
      final updatedStrokes = List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      for (final index in _activeSelectedIndices) {
        updatedStrokes[index] = updatedStrokes[index].copyWith(isLocked: !updatedStrokes[index].isLocked);
      }
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
      _pages = List.from(_pages);
    });
  }

  void _mirrorSelected() {
    if (_activeSelectedIndices.isEmpty || _activeSelectionRect == null) return;
    setState(() {
      _saveToHistory();
      final updatedStrokes = List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      final center = _activeSelectionRect!.center;
      for (final index in _activeSelectedIndices) {
        updatedStrokes[index] = updatedStrokes[index].flip(true, center);
      }
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
      _pages = List.from(_pages);
    });
  }

  void _flipSelected() {
    if (_activeSelectedIndices.isEmpty || _activeSelectionRect == null) return;
    setState(() {
      _saveToHistory();
      final updatedStrokes = List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      final center = _activeSelectionRect!.center;
      for (final index in _activeSelectedIndices) {
        updatedStrokes[index] = updatedStrokes[index].flip(false, center);
      }
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
      _pages = List.from(_pages);
    });
  }

  void _handleTextCreated(Offset position) {
    setState(() {
      _saveToHistory();
      
      final newText = DrawingText(position: position);
      final updatedTexts = List<DrawingText>.from(_pages[_currentPageIndex].texts)..add(newText);
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(texts: updatedTexts);
      _pages = List.from(_pages);
      _activeTextIndex = updatedTexts.length - 1;
      _isTextFormattingVisible = true;
    });
  }

  void _updateText(int index, String text) {
    setState(() {
      final updatedTexts = List<DrawingText>.from(_pages[_currentPageIndex].texts);
      updatedTexts[index] = updatedTexts[index].copyWith(text: text);
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(texts: updatedTexts);
      _pages = List.from(_pages);
    });
  }

  void _moveText(int index, Offset delta) {
    setState(() {
      final updatedTexts = List<DrawingText>.from(_pages[_currentPageIndex].texts);
      updatedTexts[index] = updatedTexts[index].translate(delta);
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(texts: updatedTexts);
      _pages = List.from(_pages);
    });
  }

  void _resizeTextWidth(int index, double width) {
    setState(() {
      final updatedTexts = List<DrawingText>.from(_pages[_currentPageIndex].texts);
      updatedTexts[index] = updatedTexts[index].copyWith(width: width.clamp(50.0, 2000.0));
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(texts: updatedTexts);
      _pages = List.from(_pages);
    });
  }

  void _scaleText(int index, double width, double fontSize) {
    setState(() {
      final updatedTexts = List<DrawingText>.from(_pages[_currentPageIndex].texts);
      updatedTexts[index] = updatedTexts[index].copyWith(
        width: width.clamp(40.0, 2000.0),
        fontSize: fontSize,
      );
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(texts: updatedTexts);
      _pages = List.from(_pages);
    });
  }

  void _updateTextElement(int index, DrawingText updated) {
    setState(() {
      final updatedTexts = List<DrawingText>.from(_pages[_currentPageIndex].texts);
      updatedTexts[index] = updated;
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(texts: updatedTexts);
      _pages = List.from(_pages);
    });
  }

  void _updateSelectedStrokesWidth(double width) {
    if (_activeSelectedIndices.isEmpty) return;
    setState(() {
      final updatedStrokes = List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      for (final index in _activeSelectedIndices) {
        updatedStrokes[index] = updatedStrokes[index].copyWith(width: width);
      }
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
      _pages = List.from(_pages);
    });
  }

  Widget _buildContextAction(IconData icon, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: Icon(icon, size: 20, color: color),
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

    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      if (mode == AppMode.teaching) {
        await windowManager.maximize();
      } else if (mode == AppMode.preparation) {
        await windowManager.unmaximize();
      } else if (mode == AppMode.desktop) {
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
