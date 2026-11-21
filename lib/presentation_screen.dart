import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/color_picker.dart';
import '../widgets/duster_selector.dart';
import '../widgets/handwriting_toolbar.dart';
import '../widgets/laser_selector.dart';
import '../widgets/shape_selector.dart';
import '../widgets/settings_dialog.dart';
import '../services/pptx_converter_libreoffice.dart';
import '../services/export_service.dart';
import '../services/handwriting_recognizer.dart';

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
  bool _isColorSubMenuVisible = false;
  bool _isTextFormattingVisible = false;
  bool _isAdjustingThickness = false;
  AppMode _currentMode = AppMode.preparation;
  Rect? _activeSelectionRect;
  List<int> _activeSelectedIndices = [];
  int? _activeTextIndex;
  double _currentSelectionThickness = 4.0;
  String _sourceFileName = 'Presentation';

  Color _selectedColor = Colors.red;
  double _strokeWidth = 4.0;
  double _eraserWidth = 30.0;
  DrawingTool _selectedTool = DrawingTool.pen;
  DusterType _selectedDusterType = DusterType.feltBlock;
  DusterOrientation _selectedDusterOrientation = DusterOrientation.rightHand;
  HandwritingLanguage _selectedHandwritingLang = HandwritingLanguage.english;
  LaserMode _selectedLaserMode = LaserMode.laserDot;
  Color _laserColor = Colors.redAccent;
  double _spotlightRadius = 100.0;
  ShapeType _selectedShape = ShapeType.rectangle;
  Color? _shapeFillColor;
  String _liveRecognizedText = '';
  bool _isAutoHandDusterEnabled = false;
  bool _isHandDusterActive = false;
  DrawingTool? _previousToolBeforeHandDuster;
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
  late TransformationController _transformationController;
  double _currentZoomScale = 1.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPageIndex);
    _transformationController = TransformationController();
    _transformationController.addListener(_onZoomChanged);
    _initializePages();
  }

  void _onZoomChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentZoomScale).abs() > 0.01) {
      setState(() => _currentZoomScale = scale);
    }
  }

  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
      _currentZoomScale = 1.0;
    });
  }

  void _zoomIn() {
    final newScale = (_currentZoomScale + 0.25).clamp(1.0, 5.0);
    _setZoomScale(newScale);
  }

  void _zoomOut() {
    final newScale = (_currentZoomScale - 0.25).clamp(1.0, 5.0);
    _setZoomScale(newScale);
  }

  void _setZoomScale(double targetScale) {
    setState(() {
      _currentZoomScale = targetScale;
      _transformationController.value = Matrix4.diagonal3Values(targetScale, targetScale, 1.0);
    });
  }

  void _initializePages() {
    setState(() {
      _pages = List.generate(
        3,
            (index) => PresentationPage(
          pageNumber: index + 1,
          title: 'Blank Slide ${index + 1}',
          subtitle: 'Start writing or annotate',
          icon: Icons.note_add,
          contentType: PageContentType.image,
          contentPath: null,
          backgroundColor: Colors.white,
        ),
      );
      _currentPageIndex = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onZoomChanged);
    _transformationController.dispose();
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

  void _handleHandTouchDetected(bool isHand, double size) {
    if (!_isAutoHandDusterEnabled) return;

    if (isHand) {
      if (!_isHandDusterActive) {
        _previousToolBeforeHandDuster = _selectedTool;
        setState(() {
          _isHandDusterActive = true;
          _selectedTool = DrawingTool.eraser;
          _selectedDusterType = DusterType.feltBlock;
          _eraserWidth = size;
        });
      } else {
        setState(() {
          _eraserWidth = size;
        });
      }
    } else {
      if (_isHandDusterActive) {
        setState(() {
          _isHandDusterActive = false;
          if (_previousToolBeforeHandDuster != null) {
            _selectedTool = _previousToolBeforeHandDuster!;
            _previousToolBeforeHandDuster = null;
          }
        });
      }
    }
  }

  double get _currentDusterAngle {
    switch (_selectedDusterOrientation) {
      case DusterOrientation.rightHand:
        return 15.0 * 3.141592653589793 / 180.0;
      case DusterOrientation.leftHand:
        return -15.0 * 3.141592653589793 / 180.0;
      case DusterOrientation.vertical:
        return 3.141592653589793 / 2.0;
      case DusterOrientation.horizontal:
        return 0.0;
      case DusterOrientation.auto:
        return 0.0;
    }
  }

  void _startStroke(Offset position) {
    setState(() {
      _currentStroke = DrawingStroke(
        points: [position],
        color: _selectedColor,
        width: _selectedTool == DrawingTool.eraser ? _eraserWidth : _strokeWidth,
        tool: _selectedTool,
        dusterType: _selectedDusterType,
        strokeAngle: _currentDusterAngle,
        shapeType: _selectedTool == DrawingTool.shape ? _selectedShape : null,
        fillColor: _selectedTool == DrawingTool.shape ? _shapeFillColor : null,
      );
    });
  }

  void _updateStroke(Offset position) {
    if (_currentStroke != null) {
      setState(() {
        if (_selectedTool == DrawingTool.shape) {
          if (_currentStroke!.points.length > 1) {
            _currentStroke!.points[1] = position;
          } else {
            _currentStroke!.points.add(position);
          }
        } else {
          _currentStroke!.points.add(position);
        }
      });
    }
  }

  void _endStroke() {
    if (_currentStroke != null && _currentStroke!.points.length > 1) {
      final wasShape = _selectedTool == DrawingTool.shape;
      setState(() {
        _saveToHistory();

        final updatedStrokes =
        List<DrawingStroke>.from(_pages[_currentPageIndex].strokes)
          ..add(_currentStroke!);
        _pages[_currentPageIndex] =
            _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
        _currentStroke = null;
        _pages = List.from(_pages);

        if (wasShape) {
          _activeSelectedIndices = [updatedStrokes.length - 1];
          _activeTextIndex = null;
        }

        if (_selectedTool == DrawingTool.handwriting) {
          _updateHandwritingRecognition();
        }
      });
    } else {
      setState(() {
        _currentStroke = null;
      });
    }
  }

  void _updateHandwritingRecognition() {
    final currentPage = _pages[_currentPageIndex];
    final handwritingStrokes = currentPage.strokes
        .where((s) => s.tool == DrawingTool.handwriting)
        .toList();
    if (handwritingStrokes.isNotEmpty) {
      final res = HandwritingRecognizerService.recognizeStrokes(
        handwritingStrokes,
        _selectedHandwritingLang,
      );
      _liveRecognizedText = res.text;
    }
  }

  void _convertHandwritingToText() {
    final currentPage = _pages[_currentPageIndex];
    final handwritingStrokes = currentPage.strokes
        .where((s) => s.tool == DrawingTool.handwriting)
        .toList();

    if (handwritingStrokes.isEmpty) return;

    final result = HandwritingRecognizerService.recognizeStrokes(
      handwritingStrokes,
      _selectedHandwritingLang,
    );

    if (result.text.trim().isEmpty) return;

    _saveToHistory();

    final remainingStrokes = currentPage.strokes
        .where((s) => s.tool != DrawingTool.handwriting)
        .toList();

    final isBangla = _selectedHandwritingLang == HandwritingLanguage.bangla;
    final newText = DrawingText(
      text: result.text,
      position: Offset(
        result.boundingBox.left * 1920.0,
        result.boundingBox.top * 1080.0,
      ),
      width: (result.boundingBox.width * 1920.0).clamp(160.0, 1000.0),
      fontSize: 32,
      fontFamily: isBangla ? 'Tiro Bangla' : 'Poppins',
      color: _selectedColor,
    );

    final updatedTexts = List<DrawingText>.from(currentPage.texts)..add(newText);

    setState(() {
      _pages[_currentPageIndex] = currentPage.copyWith(
        strokes: remainingStrokes,
        texts: updatedTexts,
      );
      _pages = List.from(_pages);
      _liveRecognizedText = '';
    });

    _showSnackBar(
      'Handwriting converted to text: "${result.text}"',
      Colors.teal.shade700,
      Icons.spellcheck,
    );
  }

  void _clearHandwritingInk() {
    final currentPage = _pages[_currentPageIndex];
    final remainingStrokes = currentPage.strokes
        .where((s) => s.tool != DrawingTool.handwriting)
        .toList();

    setState(() {
      _pages[_currentPageIndex] = currentPage.copyWith(strokes: remainingStrokes);
      _pages = List.from(_pages);
      _liveRecognizedText = '';
    });
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
      _pages[_currentPageIndex] =
          _pages[_currentPageIndex].copyWith(strokes: [], texts: []);
      _pages = List.from(_pages);
    });
  }

  // --- Document Loading Methods ---

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'pptx'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      final paths = result.files.map((f) => f.path!).toList();
      final pdfPath =
      paths.firstWhere((p) => p.toLowerCase().endsWith('.pdf'), orElse: () => '');
      final pptxPath = paths
          .firstWhere((p) => p.toLowerCase().endsWith('.pptx'), orElse: () => '');

      // Warn for large files
      String? largeFilePath;
      if (pdfPath.isNotEmpty) largeFilePath = pdfPath;
      else if (pptxPath.isNotEmpty) largeFilePath = pptxPath;

      if (largeFilePath != null) {
        final fileSize = await File(largeFilePath).length();
        final sizeMB = fileSize / (1024 * 1024);

        if (sizeMB > 50) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Large File'),
              content: Text(
                'This file is ${sizeMB.toStringAsFixed(1)} MB. Loading may take '
                    'several minutes and require significant memory.\n\n'
                    'For best performance with very large files, consider converting '
                    'to PDF first.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Proceed'),
                ),
              ],
            ),
          );
          if (proceed != true) return;
        }
      }

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
          await _loadImages(paths);
        }
      } catch (e, stack) {
        // Detailed error with context
        _showDetailedError(
          title: 'Error Loading Document',
          error: e,
          stackTrace: stack,
          contextInfo: 'File: ${paths.join(", ")}',
        );
      } finally {
        setState(() {
          _isLoadingDocument = false;
        });
      }
    } catch (e, stack) {
      // Error in the file picker itself
      _showDetailedError(
        title: 'File Picker Error',
        error: e,
        stackTrace: stack,
        contextInfo: 'Could not open the file picker dialog.',
      );
    }
  }

  Future<void> _loadPdf(String path) async {
    setState(() {
      _loadingMessage = 'Loading PDF...';
      _sourceFileName =
          path.split(Platform.pathSeparator).last.split('.').first;
    });

    // First, verify the file exists and is readable
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File not found at path: $path');
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      throw Exception('File is empty (0 bytes): $path');
    }

    // Progressive loading
    final document = await PdfDocument.openFile(
      path,
      useProgressiveLoading: true,
    );
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
    setState(() {
      _sourceFileName =
          paths.first.split(Platform.pathSeparator).last.split('.').first;
    });
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
      image.dispose();
    }

    setState(() {
      _pages = newPages;
      _currentPageIndex = 0;
    });
    _pageController.jumpToPage(0);
  }

  Future<void> _loadPptx(String path) async {
    setState(() {
      _loadingMessage = 'Converting PPTX...';
      _sourceFileName =
          path.split(Platform.pathSeparator).last.split('.').first;
    });

    // Verify file exists
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('PPTX file not found at: $path');
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      throw Exception('PPTX file is empty (0 bytes).');
    }

    // Convert with detailed error reporting
    final List<String> imagePaths;
    try {
      imagePaths = await PptxConverterLibreOffice.convertPptxToImages(
        path,
        onProgress: (progress) {
          if (mounted) setState(() => _loadingProgress = progress);
        },
      );
    } catch (e, stack) {
      // Re-throw with specific context
      throw Exception(
        'PPTX conversion failed.\n\n'
            'File: $path\n'
            'Size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB\n'
            'Reason: $e',
      );
    }

    if (imagePaths.isEmpty) {
      throw Exception(
        'PPTX conversion produced no images. The file may be empty or corrupted.',
      );
    }

    final firstBytes = await File(imagePaths.first).readAsBytes();
    final codec = await ui.instantiateImageCodec(firstBytes);
    final frame = await codec.getNextFrame();
    final ratio = frame.image.width / frame.image.height;
    frame.image.dispose();

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
        _generateExportFileName(),
        onProgress: (current, total) {
          setState(() {
            _loadingMessage = 'Rendering Page $current of $total...';
            _loadingProgress = current / total;
          });
        },
      );
      if (path != null) {
        _showSnackBar(
          'PDF Exported to: ${path.split(Platform.pathSeparator).last}',
          Colors.green,
          Icons.check_circle,
        );
      } else {
        _showSnackBar('Export cancelled.', Colors.orange, Icons.warning);
      }
    } catch (e, stack) {
      _showDetailedError(
        title: 'PDF Export Failed',
        error: e,
        stackTrace: stack,
        contextInfo:
        'Slides: ${_pages.length}\nFile name: ${_generateExportFileName()}.pdf',
      );
    } finally {
      setState(() => _isLoadingDocument = false);
    }
  }

  Future<void> _exportAsPptx() async {
    // PPTX export is not supported - use PDF instead.
    final shouldExportPdf = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 10),
            Text('Export as PDF'),
          ],
        ),
        content: const Text(
          'To ensure your presentation opens correctly on every computer '
              'and looks exactly like what you see here, please export as PDF.\n\n'
              'The PDF preserves the slide layout, your annotations, and every '
              'detail without any compatibility issues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Export PDF'),
          ),
        ],
      ),
    );

    if (shouldExportPdf == true) {
      await _exportAsPdf();
    }
  }

  Future<void> _printPresentation() async {
    setState(() {
      _isLoadingDocument = true;
      _loadingMessage = 'Preparing for Print...';
      _loadingProgress = 0;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    try {
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
        } catch (e, stack) {
          if (mounted) {
            _showDetailedError(
              title: 'Printing Failed',
              error: e,
              stackTrace: stack,
              contextInfo: 'Slides: ${_pages.length}',
            );
          }
        } finally {
          if (mounted) setState(() => _isLoadingDocument = false);
        }
      });
    } catch (e, stack) {
      if (mounted) setState(() => _isLoadingDocument = false);
      _showDetailedError(
        title: 'Print Setup Failed',
        error: e,
        stackTrace: stack,
        contextInfo: 'Slides: ${_pages.length}',
      );
    }
  }

  // --- Detailed Error Dialog ---

  void _showDetailedError({
    required String title,
    required dynamic error,
    StackTrace? stackTrace,
    String? contextInfo,
  }) {
    final errorString = error.toString();
    final stackString = stackTrace?.toString() ?? 'No stack trace available.';
    final contextString = contextInfo ?? 'No additional context.';

    showDialog(
      context: context,  // now refers to the widget's BuildContext
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please take a screenshot of this dialog and send it to support.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                _buildErrorSection('Context', contextString),
                _buildErrorSection('Error Message', errorString),
                _buildErrorSection(
                  'Stack Trace (first 20 lines)',
                  stackString.split('\n').take(20).join('\n'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy to Clipboard'),
            onPressed: () {
              final fullReport = '''
=== ERROR REPORT ===
Title: $title
Date: ${DateTime.now().toIso8601String()}

--- CONTEXT ---
$contextString

--- ERROR ---
$errorString

--- STACK TRACE ---
$stackString
''';
              Clipboard.setData(ClipboardData(text: fullReport));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Error report copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection(String label, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SelectableText(
              content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Builder Methods ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _isDrawingMode ? null : _buildDefaultAppBar(),
      body: Stack(
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isSidebarCollapsed ? 0 : 180,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  boxShadow: _isSidebarCollapsed
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                            blurRadius: 10,
                            offset: const Offset(3, 0),
                          ),
                        ],
                ),
                child: _isSidebarCollapsed
                    ? const SizedBox.shrink()
                    : _buildSidebar(),
              ),
              if (_isDrawingMode && _currentMode != AppMode.teaching)
                GestureDetector(
                  onTap: () => setState(
                          () => _isSidebarCollapsed = !_isSidebarCollapsed),
                  child: Container(
                    width: 20,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(10)),
                      border: Border(
                        top: BorderSide(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                        right: BorderSide(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                        bottom: BorderSide(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(2, 0),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isSidebarCollapsed
                          ? Icons.chevron_right
                          : Icons.chevron_left,
                      size: 16,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ),
              Expanded(child: _buildContentPage()),
            ],
          ),
          if (_isDrawingMode && _isMenuVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isMenuVisible = false;
                    _isModeSubMenuVisible = false;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
          if (_isDrawingMode && _isMenuVisible)
            Positioned(
              left: 5,
              bottom: 55,
              child: _buildVerticalMenu(),
            ),
          if (_isDrawingMode)
            Positioned(
              left: 0,
              bottom: 0,
              child: _buildBottomLeftMenu(),
            ),
          if (_isDrawingMode && _selectedTool == DrawingTool.eraser)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Center(
                child: RealDusterToolbar(
                  selectedDusterType: _selectedDusterType,
                  selectedOrientation: _selectedDusterOrientation,
                  dusterSize: _eraserWidth,
                  onDusterTypeChanged: (type) =>
                      setState(() => _selectedDusterType = type),
                  onOrientationChanged: (orientation) =>
                      setState(() => _selectedDusterOrientation = orientation),
                  onDusterSizeChanged: (size) =>
                      setState(() => _eraserWidth = size),
                  onClearSlide: _clearStrokes,
                ),
              ),
            ),
          if (_isDrawingMode &&
              (_selectedTool == DrawingTool.pen ||
                  _selectedTool == DrawingTool.highlighter ||
                  _selectedTool == DrawingTool.shape))
            Positioned(
              left: 0,
              right: 0,
              bottom: _selectedTool == DrawingTool.shape ? 120 : 60,
              child: Center(
                child: SizedBox(
                  width: 440,
                  child: StrokeWidthSlider(
                    strokeWidth: _strokeWidth,
                    selectedColor: _selectedColor,
                    onStrokeWidthChanged: (width) =>
                        setState(() => _strokeWidth = width),
                    onColorTap: _showDrawingColorPicker,
                    min: 1.0,
                    max: 15.0,
                    label: _selectedTool == DrawingTool.shape ? 'Shape Line' : 'Stroke Width',
                  ),
                ),
              ),
            ),
          if (_isDrawingMode && _selectedTool == DrawingTool.shape)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Center(
                child: ShapesToolbar(
                  selectedShape: _selectedShape,
                  fillColor: _shapeFillColor,
                  onShapeChanged: (shape) =>
                      setState(() => _selectedShape = shape),
                  onFillColorChanged: (color) =>
                      setState(() => _shapeFillColor = color),
                ),
              ),
            ),
          if (_isDrawingMode && _selectedTool == DrawingTool.handwriting)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Center(
                child: HandwritingControlPanel(
                  selectedLanguage: _selectedHandwritingLang,
                  recognizedText: _liveRecognizedText,
                  onLanguageChanged: (lang) {
                    setState(() => _selectedHandwritingLang = lang);
                    _updateHandwritingRecognition();
                  },
                  onConvert: _convertHandwritingToText,
                  onClearInk: _clearHandwritingInk,
                ),
              ),
            ),
          if (_isDrawingMode && _selectedTool == DrawingTool.laserPointer)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Center(
                child: LaserPointerToolbar(
                  selectedMode: _selectedLaserMode,
                  laserColor: _laserColor,
                  spotlightRadius: _spotlightRadius,
                  onModeChanged: (mode) =>
                      setState(() => _selectedLaserMode = mode),
                  onColorChanged: (color) =>
                      setState(() => _laserColor = color),
                  onRadiusChanged: (radius) =>
                      setState(() => _spotlightRadius = radius),
                ),
              ),
            ),
          if (_isDrawingMode && _selectedTool == DrawingTool.hand)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade800 : Colors.transparent,
                      width: 1,
                    ),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove,
                            size: 18,
                            color: isDark ? Colors.white : Colors.grey.shade700),
                        onPressed: _zoomOut,
                        tooltip: 'Zoom Out',
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF252536) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? Colors.grey.shade800 : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          '${(_currentZoomScale * 100).toInt()}%',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.indigoAccent : Colors.indigo,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add,
                            size: 18,
                            color: isDark ? Colors.white : Colors.grey.shade700),
                        onPressed: _zoomIn,
                        tooltip: 'Zoom In',
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.center_focus_strong, size: 16),
                        label: Text(
                          'Reset (100%)',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _resetZoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? Colors.indigoAccent : Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isDrawingMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildFloatingToolbar(),
            ),
          if (_isDrawingMode)
            Positioned(
              right: 0,
              bottom: 0,
              child: _buildSlideNavigation(),
            ),
          if (_isHandDusterActive)
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade800,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.back_hand, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Hand Duster Auto-Detected',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isLoadingDocument) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildDefaultAppBar() {
    return AppBar(
      title: Text(
        'Presentation Pro',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.file_open), onPressed: _pickDocument),
        IconButton(
            icon: const Icon(Icons.palette),
            onPressed: _showBackgroundColorPicker),
        IconButton(
            icon: const Icon(Icons.picture_as_pdf), onPressed: _exportAsPdf),
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
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _pages.length,
      allowImplicitScrolling: false,
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

  Color _getEffectiveSlideBackgroundColor(PresentationPage page, bool isDark) {
    if (page.backgroundColor != null && page.backgroundColor != Colors.white) {
      return page.backgroundColor!;
    }
    return isDark ? const Color(0xFF181825) : Colors.white;
  }

  Widget _buildSlideItem(int index) {
    final page = _pages[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slideBgColor = _getEffectiveSlideBackgroundColor(page, isDark);
    final isCurrentPage = _currentPageIndex == index;
    final isNearCurrent = (index - _currentPageIndex).abs() <= 1;
    final hasDrawing = page.strokes.isNotEmpty ||
        page.texts.isNotEmpty ||
        (isCurrentPage && _currentStroke != null);
    final isTeachingMode = _currentMode == AppMode.teaching;

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget buildContent(double slideWidth, double slideHeight) {
          return Stack(
            children: [
              Positioned.fill(
                child: isNearCurrent
                    ? _buildPageContent(page, hasDrawing: hasDrawing, slideBgColor: slideBgColor)
                    : Container(color: slideBgColor),
              ),
              Positioned.fill(
                child: DrawingCanvas(
                  strokes: page.strokes,
                  currentStroke: isCurrentPage ? _currentStroke : null,
                  selectedColor: _selectedColor,
                  strokeWidth: _strokeWidth,
                  eraserWidth: _eraserWidth,
                  selectedTool: _selectedTool,
                  selectedDusterType: _selectedDusterType,
                  selectedDusterOrientation: _selectedDusterOrientation,
                  selectedLaserMode: _selectedLaserMode,
                  laserColor: _laserColor,
                  spotlightRadius: _spotlightRadius,
                  hoverPosition: isCurrentPage ? _hoverPosition : null,
                  onHandTouchDetected: _handleHandTouchDetected,
                  onStrokeStart: _startStroke,
                  onStrokeUpdate: _updateStroke,
                  onStrokeEnd: _endStroke,
                  onHoverUpdate: (pos) =>
                      setState(() => _hoverPosition = pos),
                  onStrokesMoved: _handleStrokesMoved,
                  onStrokesScaled: _handleStrokesScaled,
                  onStrokesRotated: _handleStrokesRotated,
                  onSelectionChanged: (rect, indices) {
                    _cleanupEmptyTexts();
                    setState(() {
                      _activeSelectionRect = rect;
                      _activeSelectedIndices = indices;
                      _activeTextIndex = null;
                      _isContextSubMenuVisible = false;
                      _isThicknessSubMenuVisible = false;
                      _isColorSubMenuVisible = false;

                      if (indices.isNotEmpty) {
                        _currentSelectionThickness = _pages[_currentPageIndex]
                            .strokes[indices.first]
                            .width;
                      }
                    });
                  },
                  onTextCreated: _handleTextCreated,
                  onInteraction: () {
                    _cleanupEmptyTexts();
                    if (_isMenuVisible ||
                        _isModeSubMenuVisible ||
                        _isContextSubMenuVisible ||
                        _isThicknessSubMenuVisible ||
                        _isColorSubMenuVisible) {
                      setState(() {
                        _isMenuVisible = false;
                        _isModeSubMenuVisible = false;
                        _isContextSubMenuVisible = false;
                        _isThicknessSubMenuVisible = false;
                        _isColorSubMenuVisible = false;
                      });
                    }
                  },
                ),
              ),
              ...page.texts.asMap().entries.map((entry) {
                final idx = entry.key;
                final text = entry.value;

                final scaledText = text.copyWith(
                  position: Offset(text.position.dx * slideWidth,
                      text.position.dy * slideHeight),
                  width: text.width * (slideWidth / 1920.0),
                  fontSize: text.fontSize * (slideWidth / 1920.0),
                );

                return DrawingTextWidget(
                  element: scaledText,
                  isSelected: isCurrentPage && _activeTextIndex == idx,
                  onTextChanged: (val) => _updateText(idx, val),
                  onPositionChanged: (delta) => _moveText(
                      idx,
                      Offset(delta.dx / slideWidth, delta.dy / slideHeight)),
                  onWidthChanged: (val) =>
                      _resizeTextWidth(idx, val / (slideWidth / 1920.0)),
                  onScaleChanged: (w, s) => _scaleText(
                      idx,
                      w / (slideWidth / 1920.0),
                      s / (slideWidth / 1920.0)),
                  onInteractionStart: () => _saveToHistory(),
                  onTap: () => setState(() {
                    _activeTextIndex = idx;
                    _activeSelectedIndices = [];
                    _isTextFormattingVisible = true;
                    _activeSelectionRect = Rect.fromLTWH(
                      text.position.dx * slideWidth,
                      text.position.dy * slideHeight,
                      text.width * (slideWidth / 1920.0),
                      50,
                    );
                    _selectedTool = DrawingTool.selector;
                  }),
                );
              }),
              if (isCurrentPage &&
                  _activeSelectionRect != null &&
                  _activeSelectedIndices.isNotEmpty &&
                  _selectedTool == DrawingTool.selector) ...[
                _buildVerticalSelectionToolbar(
                    _activeSelectionRect!, slideWidth, slideHeight),
                if (_isContextSubMenuVisible)
                  _buildExpandedContextMenu(
                      _activeSelectionRect!, slideWidth, slideHeight),
                if (_isContextSubMenuVisible && _isThicknessSubMenuVisible)
                  _buildThicknessSubMenu(
                      _activeSelectionRect!, slideWidth, slideHeight),
              ],
              if (isCurrentPage &&
                  _activeTextIndex != null &&
                  _isTextFormattingVisible &&
                  _activeTextIndex! >= 0 &&
                  _activeTextIndex! < page.texts.length)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 16,
                  child: Center(
                    child: TextFormattingDialog(
                      element: page.texts[_activeTextIndex!],
                      onChanged: (updated) =>
                          _updateTextElement(_activeTextIndex!, updated),
                      onClose: () =>
                          setState(() => _isTextFormattingVisible = false),
                      onDelete: _deleteSelectedText,
                    ),
                  ),
                ),
            ],
          );
        }

        if (isTeachingMode) {
          return Container(
            color: slideBgColor,
            child: buildContent(constraints.maxWidth, constraints.maxHeight),
          );
        }

        return Center(
          child: Padding(
            padding:
            const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 90),
            child: AspectRatio(
              aspectRatio: page.aspectRatio ?? 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: slideBgColor,
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10)
                  ],
                ),
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 5.0,
                  panEnabled: _selectedTool == DrawingTool.hand,
                  scaleEnabled: _selectedTool == DrawingTool.hand,
                  child: LayoutBuilder(
                    builder: (context, slideConstraints) {
                      return buildContent(
                          slideConstraints.maxWidth, slideConstraints.maxHeight);
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

  Widget _buildPageContent(PresentationPage page,
      {bool hasDrawing = false, Color slideBgColor = Colors.white}) {
    switch (page.contentType) {
      case PageContentType.pdf:
        if (_currentPdfDocument == null)
          return _buildPlaceholder(page, isHidden: hasDrawing, bgColor: slideBgColor);
        return Center(
          child: PdfPageView(
            document: _currentPdfDocument!,
            pageNumber: page.pdfPageIndex! + 1,
            maximumDpi: 300,
          ),
        );
      case PageContentType.image:
        if (page.contentPath == null)
          return _buildPlaceholder(page, isHidden: hasDrawing, bgColor: slideBgColor);
        return Image.file(
          File(page.contentPath!),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stack) =>
              _buildPlaceholder(page, bgColor: slideBgColor),
        );
      default:
        return _buildPlaceholder(page, isHidden: hasDrawing, bgColor: slideBgColor);
    }
  }

  Widget _buildPlaceholder(PresentationPage page,
      {bool isHidden = false, Color bgColor = Colors.white}) {
    if (isHidden) return const SizedBox.shrink();
    final isLight = bgColor.computeLuminance() > 0.5;

    return Container(
      color: bgColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              page.icon,
              size: 64,
              color: isLight ? Colors.grey : Colors.white38,
            ),
            Text(
              page.title,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isLight ? Colors.black87 : Colors.white,
              ),
            ),
            Text(
              page.subtitle,
              style: GoogleFonts.poppins(
                color: isLight ? Colors.grey : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181825) : Colors.grey.shade200,
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        controller: _sidebarScrollController,
        itemCount: _pages.length,
        itemBuilder: (context, index) {
          final isCurrent = _currentPageIndex == index;
          return SlideThumbnail(
            page: _pages[index],
            currentStroke: isCurrent ? _currentStroke : null,
            isSelected: isCurrent,
            onTap: () => _goToPage(index),
            pdfDocument: _currentPdfDocument,
          );
        },
      ),
    );
  }

  Widget _buildBottomLeftMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.grey.shade800;
    final isTeaching = _currentMode == AppMode.teaching;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.only(
            topRight: Radius.circular(25), bottomRight: Radius.circular(25)),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.transparent,
          width: 1,
        ),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
              icon: Icon(Icons.menu, color: iconColor),
              onPressed: () =>
                  setState(() => _isMenuVisible = !_isMenuVisible)),
          IconButton(
            icon: Icon(
              Icons.monitor,
              color: isTeaching
                  ? (isDark ? Colors.indigoAccent : Colors.indigo)
                  : iconColor,
            ),
            tooltip: isTeaching ? 'Teaching Mode (Active)' : 'Activate Teaching Mode',
            onPressed: () {
              if (isTeaching) {
                _switchMode(AppMode.preparation);
              } else {
                _switchMode(AppMode.teaching);
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.build, color: iconColor),
            tooltip: 'Settings',
            onPressed: () => SettingsDialog.show(context),
          ),
          IconButton(
              icon: Icon(Icons.cloud_upload, color: iconColor), onPressed: _pickDocument),
          IconButton(
            icon: Icon(
              Icons.zoom_in,
              color: _selectedTool == DrawingTool.hand
                  ? (isDark ? Colors.indigoAccent : Colors.indigo)
                  : iconColor,
            ),
            tooltip: 'Zoom & Pan View',
            onPressed: () {
              if (_selectedTool == DrawingTool.hand) {
                _resetZoom();
              } else {
                setState(() => _selectedTool = DrawingTool.hand);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingToolbar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.grey.shade700;

    return Center(
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.transparent,
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolbarIcon(
                Icons.edit, DrawingTool.pen, _selectedTool == DrawingTool.pen),
            _buildToolbarIcon(Icons.auto_fix_high, DrawingTool.eraser,
                _selectedTool == DrawingTool.eraser),
            _buildToolbarIcon(Icons.category, DrawingTool.shape,
                _selectedTool == DrawingTool.shape),
            IconButton(
              icon: Icon(Icons.format_color_fill, size: 22, color: iconColor),
              onPressed: _showBackgroundColorPicker,
              tooltip: 'Background Color',
            ),
            _buildToolbarIcon(Icons.title, DrawingTool.text,
                _selectedTool == DrawingTool.text),
            _buildToolbarIcon(Icons.near_me, DrawingTool.selector,
                _selectedTool == DrawingTool.selector),
            _buildToolbarIcon(Icons.pan_tool_outlined, DrawingTool.hand,
                _selectedTool == DrawingTool.hand),
            _buildToolbarIcon(Icons.flare, DrawingTool.laserPointer,
                _selectedTool == DrawingTool.laserPointer),
            VerticalDivider(
              width: 20,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
            IconButton(icon: Icon(Icons.undo, color: iconColor), onPressed: _undo),
            IconButton(icon: Icon(Icons.redo, color: iconColor), onPressed: _redo),
          ],
        ),
      ),
    );
  }

  void _handleStrokesMoved(List<int> indices, Offset delta) {
    if (indices.isEmpty || delta == Offset.zero) return;

    setState(() {
      _saveToHistory();

      final updatedStrokes =
      List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      for (final index in indices) {
        updatedStrokes[index] = updatedStrokes[index].translate(delta);
      }
      _pages[_currentPageIndex] =
          _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
      _pages = List.from(_pages);
    });
  }

  void _handleStrokesScaled(
      List<int> indices, double scaleX, double scaleY, Offset pivot) {
    if (indices.isEmpty) return;

    setState(() {
      _saveToHistory();

      final updatedStrokes =
      List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      for (final index in indices) {
        updatedStrokes[index] =
            updatedStrokes[index].scale(scaleX, scaleY, pivot);
      }
      _pages[_currentPageIndex] =
          _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
      _pages = List.from(_pages);
    });
  }

  void _handleStrokesRotated(
      List<int> indices, double angle, Offset center) {
    if (indices.isEmpty) return;

    setState(() {
      _saveToHistory();

      final updatedStrokes =
      List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      for (final index in indices) {
        updatedStrokes[index] = updatedStrokes[index].rotate(angle, center);
      }
      _pages[_currentPageIndex] =
          _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
      _pages = List.from(_pages);
    });
  }

  void _deleteSelectedStrokes() {
    if (_activeSelectedIndices.isEmpty) return;
    setState(() {
      _saveToHistory();

      final updatedStrokes =
      List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      final sortedIndices = List<int>.from(_activeSelectedIndices)
        ..sort((a, b) => b.compareTo(a));
      for (final index in sortedIndices) {
        updatedStrokes.removeAt(index);
      }
      _pages[_currentPageIndex] =
          _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
      _pages = List.from(_pages);
      _activeSelectedIndices = [];
      _activeSelectionRect = null;
    });
  }

  void _showDrawingColorPicker() async {
    final newColor = await SmartColorPickerDialog.show(
      context: context,
      initialColor: _selectedColor,
      title: 'Drawing Color',
      icon: Icons.palette_outlined,
    );
    if (newColor != null) {
      setState(() => _selectedColor = newColor);
    }
  }

  void _cleanupEmptyTexts() {
    final currentPage = _pages[_currentPageIndex];
    if (currentPage.texts.any((t) => t.text.trim().isEmpty)) {
      setState(() {
        final updatedTexts =
        currentPage.texts.where((t) => t.text.trim().isNotEmpty).toList();
        _pages[_currentPageIndex] = currentPage.copyWith(texts: updatedTexts);
        _pages = List.from(_pages);
        _activeTextIndex = null;
        _isTextFormattingVisible = false;
      });
    }
  }

  Widget _buildToolbarIcon(IconData icon, DrawingTool? tool, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(
        icon,
        color: isSelected
            ? (isDark ? Colors.indigoAccent : Colors.indigo)
            : (isDark ? Colors.white : Colors.grey.shade700),
      ),
      onPressed: tool == null
          ? null
          : () {
        _cleanupEmptyTexts();
        setState(() => _selectedTool = tool);
      },
    );
  }

  Widget _buildSlideNavigation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.grey.shade700;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(25),bottomLeft: Radius.circular(25)),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.transparent,
          width: 1,
        ),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_left, color: iconColor),
            onPressed: _previousPage,
          ),
          Text(
            '${_currentPageIndex + 1}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_right, color: iconColor),
            onPressed: _nextPage,
          ),
          IconButton(
            icon: Icon(Icons.add, color: iconColor),
            tooltip: 'Add Slide',
            onPressed: _addNewSlide,
          ),
          IconButton(
            icon: Icon(Icons.remove, color: iconColor),
            tooltip: 'Delete Slide',
            onPressed: _deleteCurrentSlide,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return SizedBox(
      width: 300,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 150,
            decoration: BoxDecoration(
              color: menuBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.transparent,
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 15)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SamsungMenuItem(
                    icon: Icons.note_add,
                    label: 'New',
                    onTap: () {
                      setState(() => _isMenuVisible = false);
                      _initializePages();
                    },
                  ),
                  SamsungMenuItem(
                    icon: Icons.file_open,
                    label: 'Open',
                    onTap: () {
                      setState(() => _isMenuVisible = false);
                      _pickDocument();
                    },
                  ),
                  SamsungMenuItem(
                    icon: Icons.print_outlined,
                    label: 'Print',
                    onTap: () {
                      setState(() => _isMenuVisible = false);
                      _printPresentation();
                    },
                  ),
                  Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                  SamsungMenuItem(
                    icon: Icons.picture_as_pdf,
                    label: 'Export PDF',
                    onTap: () {
                      setState(() => _isMenuVisible = false);
                      _exportAsPdf();
                    },
                  ),
                  Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                  SamsungMenuItem(
                    icon: Icons.computer,
                    label: 'Mode',
                    trailingIcon: Icons.arrow_right,
                    onTap: () {
                      setState(() =>
                      _isModeSubMenuVisible = !_isModeSubMenuVisible);
                    },
                  ),
                  Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                  SamsungMenuItem(
                    icon: Icons.close,
                    label: 'Close',
                    onTap: () {
                      setState(() {
                        _isMenuVisible = false;
                        _isModeSubMenuVisible = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_isModeSubMenuVisible)
            Positioned(
              left: 155,
              bottom: 0,
              child: Container(
                width: 140,
                decoration: BoxDecoration(
                  color: menuBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 15)
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModeItem(
                        icon: Icons.monitor,
                        label: 'Teaching',
                        onTap: () => _switchMode(AppMode.teaching),
                      ),
                      _buildModeItem(
                        icon: Icons.edit_note,
                        label: 'Preparation',
                        onTap: () => _switchMode(AppMode.preparation),
                      ),
                      _buildModeItem(
                        icon: Icons.desktop_windows,
                        label: 'Desktop',
                        onTap: () => _switchMode(AppMode.desktop),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerticalSelectionToolbar(
      Rect rect, double slideWidth, double slideHeight) {
    const double toolbarWidth = 45.0;
    const double toolbarHeight = 135.0; // 3 action buttons (Delete, Color, More)
    const double expandedMenuWidth = 220.0;
    const double subMenuWidth = 240.0;
    const double horizontalPadding = 10.0;
    const double verticalPadding = 10.0;

    double totalChainWidth = toolbarWidth +
        horizontalPadding +
        expandedMenuWidth +
        horizontalPadding +
        subMenuWidth;
    bool hasSpaceOnRight = (rect.right + totalChainWidth + 20) < slideWidth;

    double left;
    if (hasSpaceOnRight) {
      left = rect.right + horizontalPadding;
    } else {
      left = (rect.left - horizontalPadding - toolbarWidth)
          .clamp(horizontalPadding, slideWidth - toolbarWidth);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    double top = rect.top.clamp(verticalPadding,
        (slideHeight - toolbarHeight - verticalPadding).clamp(verticalPadding, slideHeight));

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: toolbarWidth,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10)
            ],
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildContextAction(
                  Icons.delete_outline, _deleteSelectedStrokes, Colors.redAccent),
              _buildContextAction(
                  Icons.palette_outlined, _showDrawingColorPicker, Colors.indigoAccent),
              _buildContextAction(Icons.menu, () {
                setState(() {
                  _isContextSubMenuVisible = !_isContextSubMenuVisible;
                  if (!_isContextSubMenuVisible) {
                    _isThicknessSubMenuVisible = false;
                    _isColorSubMenuVisible = false;
                  }
                });
              }, isDark ? Colors.white : Colors.grey.shade700),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContextMenu(
      Rect rect, double slideWidth, double slideHeight) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const double toolbarWidth = 45.0;
    const double toolbarHeight = 135.0;
    const double expandedMenuWidth = 220.0;
    const double maxMenuHeight = 220.0;
    const double subMenuWidth = 240.0;
    const double horizontalPadding = 10.0;
    const double verticalPadding = 10.0;

    double totalChainWidth = toolbarWidth +
        horizontalPadding +
        expandedMenuWidth +
        horizontalPadding +
        subMenuWidth;
    bool hasSpaceOnRight = (rect.right + totalChainWidth + 20) < slideWidth;

    double toolbarLeft = hasSpaceOnRight
        ? (rect.right + horizontalPadding)
        : (rect.left - horizontalPadding - toolbarWidth);
    double toolbarTop = rect.top.clamp(verticalPadding,
        (slideHeight - toolbarHeight - verticalPadding).clamp(verticalPadding, slideHeight));

    double left = hasSpaceOnRight
        ? (toolbarLeft + toolbarWidth + horizontalPadding)
        : (toolbarLeft - horizontalPadding - expandedMenuWidth);

    bool spaceBelow =
        (slideHeight - toolbarTop) > (maxMenuHeight + verticalPadding);
    double? top = spaceBelow ? toolbarTop : null;
    double? bottom = spaceBelow
        ? null
        : (slideHeight - (toolbarTop + toolbarHeight))
        .clamp(verticalPadding, slideHeight);

    return Positioned(
      left: left,
      top: top,
      bottom: bottom,
      child: GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: expandedMenuWidth,
          constraints: BoxConstraints(maxHeight: maxMenuHeight),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 15)
            ],
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
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
                    _buildExpandedMenuItem(
                      _isSelectionLocked() ? Icons.lock : Icons.lock_open,
                      _isSelectionLocked() ? 'Unlock' : 'Lock',
                      _toggleLockSelected,
                    ),
                    _buildExpandedMenuItem(
                      Icons.line_weight,
                      'Line thickness',
                          () => setState(() {
                        _isThicknessSubMenuVisible =
                        !_isThicknessSubMenuVisible;
                      }),
                      hasSubmenu: true,
                      isActive: _isThicknessSubMenuVisible,
                    ),
                    _buildExpandedMenuItem(
                      Icons.format_color_fill,
                      'Fill color',
                      () async {
                        setState(() {
                          _isContextSubMenuVisible = false;
                          _isThicknessSubMenuVisible = false;
                        });
                        Color initial = _selectedColor;
                        if (_activeSelectedIndices.isNotEmpty) {
                          final page = _pages[_currentPageIndex];
                          initial = page.strokes[_activeSelectedIndices.first].color;
                        }
                        final newColor = await SmartColorPickerDialog.show(
                          context: context,
                          initialColor: initial,
                          title: 'Stroke Fill Color',
                          icon: Icons.format_color_fill,
                        );
                        if (newColor != null) {
                          _updateSelectedStrokesColor(newColor);
                        }
                      },
                      hasSubmenu: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThicknessSubMenu(
      Rect rect, double slideWidth, double slideHeight) {
    const double toolbarWidth = 45.0;
    const double toolbarHeight = 225.0;
    const double expandedMenuWidth = 220.0;
    const double thicknessSubMenuWidth = 180.0;
    const double thicknessSubMenuHeight = 50.0;
    const double subMenuWidth = 240.0;
    const double horizontalPadding = 10.0;
    const double verticalPadding = 10.0;

    double totalChainWidth = toolbarWidth +
        horizontalPadding +
        expandedMenuWidth +
        horizontalPadding +
        subMenuWidth;
    bool hasSpaceOnRight = (rect.right + totalChainWidth + 20) < slideWidth;

    double toolbarLeft = hasSpaceOnRight
        ? (rect.right + horizontalPadding)
        : (rect.left - horizontalPadding - toolbarWidth);
    double toolbarTop = rect.top.clamp(verticalPadding,
        (slideHeight - toolbarHeight - verticalPadding).clamp(verticalPadding, slideHeight));

    double left = hasSpaceOnRight
        ? (toolbarLeft + toolbarWidth + horizontalPadding + expandedMenuWidth + 5)
        : (toolbarLeft -
        horizontalPadding -
        expandedMenuWidth -
        5 -
        thicknessSubMenuWidth);

    double top = (toolbarTop + 45.0).clamp(
        verticalPadding, slideHeight - thicknessSubMenuHeight - verticalPadding);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: thicknessSubMenuWidth,
          height: thicknessSubMenuHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10)
            ],
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.line_weight, size: 16, color: isDark ? Colors.grey.shade300 : Colors.grey.shade600),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6),
                    overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: _currentSelectionThickness,
                    min: 1.0,
                    max: 30.0,
                    activeColor: Colors.indigoAccent,
                    inactiveColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
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

  Widget _buildExpandedMenuItem(
      IconData icon, String label, VoidCallback onTap,
      {bool hasSubmenu = false, bool isActive = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        onTap();
        if (!hasSubmenu) setState(() => _isContextSubMenuVisible = false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.indigo.withOpacity(0.12)
              : Colors.transparent,
          border: Border(
              bottom: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: isActive ? Colors.indigoAccent : (isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ),
            if (hasSubmenu)
              Icon(Icons.arrow_right,
                  size: 18,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  bool _isSelectionLocked() {
    final page = _pages[_currentPageIndex];
    if (_activeTextIndex != null && _activeTextIndex! < page.texts.length) {
      return page.texts[_activeTextIndex!].isLocked;
    }
    if (_activeSelectedIndices.isNotEmpty) {
      return _activeSelectedIndices.any(
              (idx) => idx < page.strokes.length && page.strokes[idx].isLocked);
    }
    return false;
  }

  void _toggleLockSelected() {
    if (_activeSelectedIndices.isEmpty && _activeTextIndex == null) return;

    final bool currentlyLocked = _isSelectionLocked();

    setState(() {
      _saveToHistory();
      final page = _pages[_currentPageIndex];

      final updatedStrokes = List<DrawingStroke>.from(page.strokes);
      for (final index in _activeSelectedIndices) {
        if (index < updatedStrokes.length) {
          updatedStrokes[index] =
              updatedStrokes[index].copyWith(isLocked: !currentlyLocked);
        }
      }

      final updatedTexts = List<DrawingText>.from(page.texts);
      if (_activeTextIndex != null && _activeTextIndex! < updatedTexts.length) {
        updatedTexts[_activeTextIndex!] =
            updatedTexts[_activeTextIndex!].copyWith(isLocked: !currentlyLocked);
      }

      _pages[_currentPageIndex] =
          page.copyWith(strokes: updatedStrokes, texts: updatedTexts);
      _pages = List.from(_pages);
    });
  }

  void _handleTextCreated(Offset position) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTextColor = isDark ? Colors.white : Colors.black;

    setState(() {
      _saveToHistory();

      final newText = DrawingText(
        position: position,
        color: defaultTextColor,
      );
      final updatedTexts =
      List<DrawingText>.from(_pages[_currentPageIndex].texts)
        ..add(newText);
      _pages[_currentPageIndex] =
          _pages[_currentPageIndex].copyWith(texts: updatedTexts);
      _pages = List.from(_pages);
      _activeTextIndex = updatedTexts.length - 1;
      _isTextFormattingVisible = true;
    });
  }

  void _updateText(int index, String text) {
    setState(() {
      final updatedTexts =
      List<DrawingText>.from(_pages[_currentPageIndex].texts);
      updatedTexts[index] = updatedTexts[index].copyWith(text: text);
      _pages[_currentPageIndex] =
          _pages[_currentPageIndex].copyWith(texts: updatedTexts);
      _pages = List.from(_pages);
    });
  }

  void _moveText(int index, Offset delta) {
    setState(() {
      final updatedTexts =
      List<DrawingText>.from(_pages[_currentPageIndex].texts);
      updatedTexts[index] = updatedTexts[index].translate(delta);
      _pages[_currentPageIndex] =
          _pages[_currentPageIndex].copyWith(texts: updatedTexts);
      _pages = List.from(_pages);
    });
  }

  void _resizeTextWidth(int index, double width) {
    setState(() {
      final updatedTexts =
      List<DrawingText>.from(_pages[_currentPageIndex].texts);
      updatedTexts[index] =
          updatedTexts[index].copyWith(width: width.clamp(50.0, 2000.0));
      _pages[_currentPageIndex] =
          _pages[_currentPageIndex].copyWith(texts: updatedTexts);
      _pages = List.from(_pages);
    });
  }

  void _scaleText(int index, double width, double fontSize) {
    setState(() {
      final updatedTexts =
      List<DrawingText>.from(_pages[_currentPageIndex].texts);
      updatedTexts[index] = updatedTexts[index].copyWith(
        width: width.clamp(40.0, 2000.0),
        fontSize: fontSize,
      );
      _pages[_currentPageIndex] =
          _pages[_currentPageIndex].copyWith(texts: updatedTexts);
      _pages = List.from(_pages);
    });
  }

  void _updateTextElement(int index, DrawingText updated) {
    setState(() {
      final updatedTexts =
      List<DrawingText>.from(_pages[_currentPageIndex].texts);
      updatedTexts[index] = updated;
      _pages[_currentPageIndex] =
          _pages[_currentPageIndex].copyWith(texts: updatedTexts);
      _pages = List.from(_pages);
    });
  }

  void _deleteSelectedText() {
    if (_activeTextIndex == null) return;
    setState(() {
      _saveToHistory();
      final updatedTexts =
          List<DrawingText>.from(_pages[_currentPageIndex].texts);
      if (_activeTextIndex! < updatedTexts.length) {
        updatedTexts.removeAt(_activeTextIndex!);
      }
      _pages[_currentPageIndex] =
          _pages[_currentPageIndex].copyWith(texts: updatedTexts);
      _pages = List.from(_pages);
      _activeTextIndex = null;
      _isTextFormattingVisible = false;
    });
    _showSnackBar(
        'Text box deleted.', Colors.red.shade700, Icons.delete_outline);
  }

  void _updateSelectedStrokesWidth(double width) {
    if (_activeSelectedIndices.isEmpty) return;
    setState(() {
      final updatedStrokes =
      List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      for (final index in _activeSelectedIndices) {
        updatedStrokes[index] = updatedStrokes[index].copyWith(width: width);
      }
      _pages[_currentPageIndex] =
          _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
      _pages = List.from(_pages);
    });
  }

  void _updateSelectedStrokesColor(Color color) {
    if (_activeSelectedIndices.isEmpty) return;
    setState(() {
      _saveToHistory();
      final updatedStrokes =
      List<DrawingStroke>.from(_pages[_currentPageIndex].strokes);
      for (final index in _activeSelectedIndices) {
        updatedStrokes[index] = updatedStrokes[index].copyWith(color: color);
      }
      _pages[_currentPageIndex] =
          _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
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

  Widget _buildModeItem(
      {required IconData icon,
        required String label,
        required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.grey.shade800,
              ),
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

    _showSnackBar(
      mode == AppMode.teaching
          ? 'Teaching Mode Activated'
          : (mode == AppMode.desktop
              ? 'Desktop Mode Activated'
              : 'Preparation Mode Activated'),
      mode == AppMode.teaching ? Colors.indigo : Colors.grey.shade800,
      Icons.monitor,
    );
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
              padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
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
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.indigo),
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
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.indigo),
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
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut);
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

  Future<void> _deleteCurrentSlide() async {
    if (_pages.length <= 1) {
      _showSnackBar(
        'Cannot delete the only remaining slide.',
        Colors.orange.shade800,
        Icons.warning_amber_rounded,
      );
      return;
    }

    final int slideNumberToDelete = _currentPageIndex + 1;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Text(
              'Delete Slide $slideNumberToDelete',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete Slide $slideNumberToDelete?\nThis action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _saveToHistory();

      _pages.removeAt(_currentPageIndex);

      final List<PresentationPage> updatedPages = [];
      for (int i = 0; i < _pages.length; i++) {
        final p = _pages[i];
        updatedPages.add(PresentationPage(
          pageNumber: i + 1,
          title: 'Slide ${i + 1}',
          subtitle: p.subtitle,
          icon: p.icon,
          strokes: p.strokes,
          texts: p.texts,
          contentType: p.contentType,
          contentPath: p.contentPath,
          pdfPageIndex: p.pdfPageIndex,
          extraData: p.extraData,
          backgroundColor: p.backgroundColor,
          aspectRatio: p.aspectRatio,
        ));
      }
      _pages = updatedPages;

      int targetIndex = _currentPageIndex;
      if (targetIndex >= _pages.length) {
        targetIndex = _pages.length - 1;
      }

      _currentPageIndex = targetIndex;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(_currentPageIndex);
    }

    _showSnackBar(
      'Slide $slideNumberToDelete deleted.',
      Colors.red.shade700,
      Icons.delete_outline,
    );
  }

  void _previousPage() {
    if (_currentPageIndex > 0) _goToPage(_currentPageIndex - 1);
  }

  void _nextPage() {
    if (_currentPageIndex < _pages.length - 1)
      _goToPage(_currentPageIndex + 1);
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color snackBg = isDark
        ? (color == Colors.red || color == Colors.red.shade700
            ? const Color(0xFF3B1E2B)
            : (color == Colors.orange || color == Colors.orange.shade800
                ? const Color(0xFF3D2B1E)
                : const Color(0xFF2A2A3C)))
        : color;

    final Color iconColor = isDark
        ? (color == Colors.red || color == Colors.red.shade700
            ? Colors.redAccent
            : (color == Colors.orange || color == Colors.orange.shade800
                ? Colors.orangeAccent
                : (color == Colors.indigo ? Colors.indigoAccent : Colors.white)))
        : Colors.white;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 70, left: 20, right: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: snackBg,
      elevation: 6,
    ));
  }

  void _showBackgroundColorPicker() async {
    final currentPage = _pages[_currentPageIndex];
    final isBlankSlide =
        currentPage.contentPath == null || currentPage.contentPath!.isEmpty;

    if (!isBlankSlide) {
      _showSnackBar(
          'Background color only for blank slides', Colors.grey, Icons.info);
      return;
    }

    final initialColor = currentPage.backgroundColor ?? Colors.white;

    final newColor = await SmartColorPickerDialog.show(
      context: context,
      initialColor: initialColor,
      title: 'Slide Background Color',
      icon: Icons.format_color_fill_outlined,
    );

    if (newColor != null) {
      setState(() {
        final updatedPage = _pages[_currentPageIndex].copyWith(
          backgroundColor: newColor,
        );
        _pages[_currentPageIndex] = updatedPage;
        _pages = List.from(_pages);
      });
    }
  }

  String _generateExportFileName() {
    final now = DateTime.now();
    final timestamp =
        "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}";
    return "${_sourceFileName}_$timestamp";
  }
}