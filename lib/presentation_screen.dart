import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/drawing_stroke.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/stroke_width_slider.dart';
import '../widgets/slide_thumbnail.dart';
import '../services/pptx_converter_libreoffice.dart';
import '../services/export_service.dart';

class PresentationScreen extends StatefulWidget {
  const PresentationScreen({Key? key}) : super(key: key);

  @override
  _PresentationScreenState createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen>
    with SingleTickerProviderStateMixin {
  bool _isDrawingMode = false;
  bool _isToolbarVisible = true;
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

  late AnimationController _toolbarAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  PdfDocument? _currentPdfDocument;
  bool _isLoadingDocument = false;
  double _pptxAspectRatio = 1.5;
  double _loadingProgress = 0.0;
  String _loadingMessage = 'Processing Document...';

  final ScrollController _sidebarScrollController = ScrollController();
  late PageController _pageController;

  double _darkOverlayOpacity = 0.0;
  static const double MAX_DARK_OVERLAY = 0.2;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPageIndex);
    _initializePages();
    _initToolbarAnimation();
  }

  void _initToolbarAnimation() {
    _toolbarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toolbarAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _toolbarAnimationController,
      curve: Curves.easeIn,
    ));
  }

  void _initializePages() {
    _pages = [
      PresentationPage(
        pageNumber: 1,
        title: 'Blank Slide 1',
        subtitle: 'Start writing or annotate',
        icon: Icons.note_add,
        contentType: PageContentType.image,
        contentPath: null,
        backgroundColor: Colors.white,
      ),
      PresentationPage(
        pageNumber: 2,
        title: 'Blank Slide 2',
        subtitle: 'Start writing or annotate',
        icon: Icons.note_add,
        contentType: PageContentType.image,
        contentPath: null,
        backgroundColor: Colors.white,
      ),
      PresentationPage(
        pageNumber: 3,
        title: 'Blank Slide 3',
        subtitle: 'Start writing or annotate',
        icon: Icons.note_add,
        contentType: PageContentType.image,
        contentPath: null,
        backgroundColor: Colors.white,
      ),
    ];
  }

  void _createNewPresentation() {
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
            width: 400,
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_circle_outline, color: Colors.teal, size: 30),
                ),
                SizedBox(height: 16),
                Text(
                  'New Presentation',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This will clear all current slides and create 3 new blank slides.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Are you sure?',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Text('Cancel', style: TextStyle(fontSize: 13)),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        setState(() {
                          _isDrawingMode = false;
                          _isToolbarVisible = false;
                          _darkOverlayOpacity = 0.0;
                          _currentStroke = null;
                          _currentPageIndex = 0;
                          _undoHistory.clear();
                          _redoHistory.clear();
                          _currentPdfDocument?.dispose();
                          _currentPdfDocument = null;
                          _initializePages();
                          if (_pageController.hasClients) {
                            _pageController.jumpToPage(0);
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text('Create New', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNewPresentationDialog() {
    Future.delayed(Duration(milliseconds: 800), () {
      if (mounted) {
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
                width: 400,
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle, color: Colors.green, size: 30),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Export Successful',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Do you want to create a new presentation?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Text('No, Continue', style: TextStyle(fontSize: 13)),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            setState(() {
                              _isDrawingMode = false;
                              _isToolbarVisible = false;
                              _darkOverlayOpacity = 0.0;
                              _currentStroke = null;
                              _currentPageIndex = 0;
                              _undoHistory.clear();
                              _redoHistory.clear();
                              _currentPdfDocument?.dispose();
                              _currentPdfDocument = null;
                              _initializePages();
                              if (_pageController.hasClients) {
                                _pageController.jumpToPage(0);
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text('Yes, New', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _toolbarAnimationController.dispose();
    _currentPdfDocument?.dispose();
    _sidebarScrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Presentation Pro v1.0.1',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Slide ${_currentPageIndex + 1} of ${_pages.length}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isDrawingMode) ...[
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
              onPressed: _createNewPresentation,
              tooltip: 'New Presentation',
            ),
            IconButton(
              icon: const Icon(Icons.file_open, color: Colors.indigo),
              onPressed: _pickDocument,
              tooltip: 'Load Document',
            ),
            IconButton(
              icon: const Icon(Icons.palette, color: Colors.purple),
              onPressed: _showBackgroundColorPicker,
              tooltip: 'Background Color',
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.green),
              onPressed: _exportAsPdf,
              tooltip: 'Export as PDF',
            ),
            IconButton(
              icon: const Icon(Icons.slideshow, color: Colors.orange),
              onPressed: _exportAsPptx,
              tooltip: 'Export as PPTX',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.draw, size: 18),
                label: const Text('Annotate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: _enableDrawingMode,
              ),
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                _darkOverlayOpacity > 0 ? Icons.brightness_high : Icons.brightness_low,
                color: _darkOverlayOpacity > 0 ? Colors.amber : Colors.grey.shade600,
                size: 20,
              ),
              onPressed: _toggleDarkOverlay,
              tooltip: _darkOverlayOpacity > 0 ? 'Remove Dark Overlay' : 'Add Dark Overlay',
            ),
            IconButton(
              icon: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: _toolbarAnimationController,
                color: Colors.indigo,
              ),
              onPressed: _toggleToolbar,
              tooltip: 'Toggle Toolbar',
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: _disableDrawingMode,
              tooltip: 'Close Drawing',
            ),
          ],
        ],
      ),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Horizontal Drawing Toolbar
                    // Horizontal Drawing Toolbar
                    // Horizontal Drawing Toolbar
                    if (_isDrawingMode && _isToolbarVisible)
                      Container(
                        height: 56,
                        color: Colors.white,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              // Tools group
                              Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    _buildCompactToolButton(Icons.edit, 'Pen', DrawingTool.pen, Colors.indigo),
                                    SizedBox(width: 4),
                                    _buildCompactToolButton(Icons.border_color, 'Highlight', DrawingTool.highlighter, Colors.orange),
                                    SizedBox(width: 4),
                                    _buildCompactToolButton(Icons.auto_fix_high, 'Eraser', DrawingTool.eraser, Colors.red),
                                  ],
                                ),
                              ),

                              SizedBox(width: 12),

                              // Color picker button
                              GestureDetector(
                                onTap: _showDrawingColorPicker,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: _selectedColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.15),
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey.shade600),
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(width: 12),

                              // Stroke width indicator
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.line_weight, size: 14, color: Colors.grey.shade600),
                                    SizedBox(width: 4),
                                    Container(
                                      width: 24,
                                      height: (_selectedTool == DrawingTool.eraser ? _eraserWidth : _strokeWidth).clamp(2.0, 20.0),
                                      decoration: BoxDecoration(
                                        color: _selectedColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(width: 12),

                              // Actions
                              _buildCompactActionButton(Icons.undo, 'Undo', _undo),
                              SizedBox(width: 4),
                              _buildCompactActionButton(Icons.redo, 'Redo', _redo),
                              SizedBox(width: 4),
                              _buildCompactActionButton(Icons.delete_outline, 'Clear', _clearStrokes),
                              SizedBox(width: 8),
                              Container(width: 1, height: 28, color: Colors.grey.shade200),
                              SizedBox(width: 8),
                              _buildCompactActionButton(Icons.close, 'Close', _disableDrawingMode, isClose: true),
                            ],
                          ),
                        ),
                      ),

                    Expanded(
                      child: _buildContentPage(),
                    ),
                    _buildBottomNavigation(),
                  ],
                ),

                // Stroke Width Slider
                if (_isDrawingMode && _isToolbarVisible)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 60,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

                if (_isLoadingDocument)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.4),
                      child: Center(
                        child: Container(
                          width: 380,
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 35,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TweenAnimationBuilder(
                                tween: Tween<double>(begin: 0.8, end: 1.0),
                                duration: Duration(milliseconds: 800),
                                builder: (context, scale, child) {
                                  return Transform.scale(scale: scale, child: child);
                                },
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.indigo.withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _loadingMessage.contains('PDF')
                                        ? Icons.picture_as_pdf
                                        : _loadingMessage.contains('PPTX')
                                        ? Icons.slideshow
                                        : Icons.description,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(
                                _loadingProgress > 0
                                    ? '${(_loadingProgress * 100).toStringAsFixed(0)}%'
                                    : 'Processing...',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                              SizedBox(height: 20),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _loadingProgress > 0 ? _loadingProgress : null,
                                  minHeight: 10,
                                  backgroundColor: Colors.grey.shade100,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildProcessingStep(0, 'Reading', _loadingProgress),
                                  _buildProcessingDot(),
                                  _buildProcessingStep(1, 'Converting', _loadingProgress),
                                  _buildProcessingDot(),
                                  _buildProcessingStep(2, 'Finalizing', _loadingProgress),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactToolButton(IconData icon, String label, DrawingTool tool, Color color) {
    final isSelected = _selectedTool == tool;

    return GestureDetector(
      onTap: () => setState(() => _selectedTool = tool),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? color : Colors.grey.shade500),
            SizedBox(width: 3),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactActionButton(IconData icon, String label, VoidCallback onTap, {bool isClose = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isClose ? Colors.red.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isClose ? Colors.red.shade200 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isClose ? Colors.red : Colors.grey.shade600,
            ),
            SizedBox(width: 3),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isClose ? Colors.red : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }



  void _showDrawingColorPicker() {
    Color selectedColor = _selectedColor;

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
            padding: EdgeInsets.all(16),
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
                            color: Colors.indigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.brush, color: Colors.indigo, size: 16),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Drawing Color',
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
                    SizedBox(height: 12),
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
                    SizedBox(height: 12),
                    _buildColorPalette(selectedColor, (color) {
                      setDialogState(() => selectedColor = color);
                    }),
                    SizedBox(height: 12),
                    _buildHueSlider(selectedColor, (color) {
                      setDialogState(() => selectedColor = color);
                    }),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildQuickColorDotForDrawing(Colors.black, dialogContext),
                        _buildQuickColorDotForDrawing(Colors.red, dialogContext),
                        _buildQuickColorDotForDrawing(Colors.orange, dialogContext),
                        _buildQuickColorDotForDrawing(Colors.yellow, dialogContext),
                        _buildQuickColorDotForDrawing(Colors.green, dialogContext),
                        _buildQuickColorDotForDrawing(Colors.blue, dialogContext),
                        _buildQuickColorDotForDrawing(Colors.indigo, dialogContext),
                        _buildQuickColorDotForDrawing(Colors.purple, dialogContext),
                        _buildQuickColorDotForDrawing(Colors.white, dialogContext),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Text('Cancel', style: TextStyle(fontSize: 11)),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedColor = selectedColor;
                            });
                            Navigator.pop(dialogContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          child: Text('Apply', style: TextStyle(fontSize: 11)),
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

  Widget _buildQuickColorDotForDrawing(Color color, BuildContext dialogContext) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(dialogContext);
        setState(() {
          _selectedColor = color;
        });
      },
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingStep(int stepIndex, String label, double progress) {
    final stepProgress = (progress * 3) - stepIndex;
    final isActive = stepProgress > 0;
    final isCompleted = stepProgress > 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.green
                : isActive
                ? Colors.indigo
                : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: isCompleted
              ? Icon(Icons.check, size: 14, color: Colors.white)
              : isActive
              ? SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : null,
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? Colors.indigo : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingDot() {
    return Container(
      width: 20,
      height: 2,
      margin: EdgeInsets.only(bottom: 14),
      color: Colors.grey.shade200,
    );
  }

  Widget _buildContentPage() {
    if (_pages.isEmpty) return Container();

    return Container(
      color: Colors.grey.shade200,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _pages.length,
        physics: _isDrawingMode ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentPageIndex = index;
            _currentStroke = null;
          });
          _scrollToCurrentThumbnail();
        },
        itemBuilder: (context, index) {
          return _buildSlideItem(index);
        },
      ),
    );
  }

  Widget _buildSlideItem(int index) {
    final page = _pages[index];
    final isBlankSlide = page.contentPath == null || page.contentPath!.isEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          panEnabled: !_isDrawingMode,
          scaleEnabled: !_isDrawingMode,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildPageContent(page),
                ),
              ),
              if (_isDrawingMode && _darkOverlayOpacity > 0 && _currentPageIndex == index)
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _darkOverlayOpacity,
                          child: Container(color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.transparent,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: IgnorePointer(
                      ignoring: !_isDrawingMode || _currentPageIndex != index,
                      child: DrawingCanvas(
                        strokes: page.strokes,
                        currentStroke: _currentPageIndex == index ? _currentStroke : null,
                        selectedColor: _selectedColor,
                        strokeWidth: _strokeWidth,
                        eraserWidth: _eraserWidth,
                        selectedTool: _selectedTool,
                        hoverPosition: _currentPageIndex == index ? _hoverPosition : null,
                        onStrokeStart: _startStroke,
                        onStrokeUpdate: _updateStroke,
                        onStrokeEnd: _endStroke,
                        onHoverUpdate: (pos) => setState(() => _hoverPosition = pos),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageContent(PresentationPage page) {
    switch (page.contentType) {
      case PageContentType.pdf:
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: PdfPageView(
              document: _currentPdfDocument,
              pageNumber: (page.pdfPageIndex ?? 0) + 1,
              backgroundColor: Colors.white,
            ),
          ),
        );
      case PageContentType.image:
        if (page.contentPath == null || page.contentPath!.isEmpty) {
          final bgColor = page.backgroundColor ?? Colors.white;

          if (page.strokes.isNotEmpty || _isDrawingMode) {
            return Center(
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.gesture,
                      size: 64,
                      color: bgColor.computeLuminance() > 0.5 ? Colors.grey.shade300 : Colors.white.withOpacity(0.5),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Blank Slide',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: bgColor.computeLuminance() > 0.5 ? Colors.grey.shade400 : Colors.white.withOpacity(0.7),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Click "Annotate" to start drawing',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: bgColor.computeLuminance() > 0.5 ? Colors.grey.shade400 : Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Image.file(
              File(page.contentPath!),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 48),
                      SizedBox(height: 8),
                      Text('Failed to load image'),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      case PageContentType.placeholder:
      default:
        final bgColor = page.backgroundColor ?? Colors.white;

        if (page.strokes.isNotEmpty || _isDrawingMode) {
          return Center(
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ),
          );
        }
        return Center(
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.gesture,
                    size: 64,
                    color: bgColor.computeLuminance() > 0.5 ? Colors.grey.shade300 : Colors.white.withOpacity(0.5),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Blank Slide',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: bgColor.computeLuminance() > 0.5 ? Colors.grey.shade400 : Colors.white.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Click "Annotate" to start drawing',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: bgColor.computeLuminance() > 0.5 ? Colors.grey.shade400 : Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  Widget _buildBottomNavigation() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPageIndex > 0 ? _previousPage : null,
            tooltip: 'Previous Slide',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              '${_currentPageIndex + 1} / ${_pages.length}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPageIndex < _pages.length - 1 ? _nextPage : null,
            tooltip: 'Next Slide',
          ),
        ],
      ),
    );
  }

  void _toggleDarkOverlay() {
    setState(() {
      if (_darkOverlayOpacity > 0) {
        _darkOverlayOpacity = 0.0;
      } else {
        _darkOverlayOpacity = MAX_DARK_OVERLAY;
      }
    });
  }

  void _enableDrawingMode() {
    setState(() {
      _isDrawingMode = true;
      _isToolbarVisible = true;
      _darkOverlayOpacity = 0.0;
      _undoHistory.clear();
      _redoHistory.clear();
    });
    _toolbarAnimationController.forward();
  }

  void _disableDrawingMode() {
    _toolbarAnimationController.reverse().then((_) {
      setState(() {
        _isDrawingMode = false;
        _isToolbarVisible = false;
        _darkOverlayOpacity = 0.0;
        _currentStroke = null;
      });
    });
  }

  void _toggleToolbar() {
    setState(() {
      _isToolbarVisible = !_isToolbarVisible;
    });
    if (_isToolbarVisible) {
      _toolbarAnimationController.forward();
    } else {
      _toolbarAnimationController.reverse();
    }
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
    if (_undoHistory.isNotEmpty) {
      setState(() {
        _redoHistory.add(List.from(_pages[_currentPageIndex].strokes));
        _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(
          strokes: _undoHistory.removeLast(),
        );
        _pages = List.from(_pages);
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

  Widget _buildSidebar() {
    return Container(
      width: 180,
      color: Colors.grey.shade200,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Icon(Icons.layers, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'SLIDES',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 1,
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: _addNewSlide,
                  child: Icon(
                    Icons.add_circle,
                    size: 18,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _sidebarScrollController,
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return SlideThumbnail(
                  page: _pages[index],
                  isSelected: _currentPageIndex == index,
                  onTap: () => _goToPage(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addNewSlide() {
    setState(() {
      _pages.add(
        PresentationPage(
          pageNumber: _pages.length + 1,
          title: 'Blank Slide ${_pages.length + 1}',
          subtitle: 'Start writing or annotate',
          icon: Icons.note_add,
          contentType: PageContentType.image,
          contentPath: null,
          backgroundColor: Colors.white,
        ),
      );
    });
  }

  void _goToPage(int index) {
    setState(() {
      _currentPageIndex = index;
      _currentStroke = null;
    });
    _scrollToCurrentThumbnail();

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollToCurrentThumbnail() {
    final targetOffset = _currentPageIndex * 120.0;
    if (_sidebarScrollController.hasClients) {
      _sidebarScrollController.animateTo(
        targetOffset.clamp(0, _sidebarScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPageIndex > 0) {
      _goToPage(_currentPageIndex - 1);
    }
  }

  void _nextPage() {
    if (_currentPageIndex < _pages.length - 1) {
      _goToPage(_currentPageIndex + 1);
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
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
            padding: EdgeInsets.all(16),
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
                          child: Icon(Icons.palette, color: Colors.purple, size: 16),
                        ),
                        SizedBox(width: 8),
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
                    SizedBox(height: 12),
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
                    SizedBox(height: 12),
                    _buildColorPalette(selectedColor, (color) {
                      setDialogState(() => selectedColor = color);
                    }),
                    SizedBox(height: 12),
                    _buildHueSlider(selectedColor, (color) {
                      setDialogState(() => selectedColor = color);
                    }),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildQuickColorDot(Colors.white, dialogContext),
                        _buildQuickColorDot(Colors.black, dialogContext),
                        _buildQuickColorDot(Color(0xFFFEEBEB), dialogContext),
                        _buildQuickColorDot(Color(0xFFE8F5E9), dialogContext),
                        _buildQuickColorDot(Color(0xFFE3F2FD), dialogContext),
                        _buildQuickColorDot(Color(0xFFFFFDE7), dialogContext),
                        _buildQuickColorDot(Color(0xFFFFF3E0), dialogContext),
                        _buildQuickColorDot(Color(0xFFF3E5F5), dialogContext),
                        _buildQuickColorDot(Color(0xFFF5F5F5), dialogContext),
                        _buildQuickColorDot(Color(0xFFE0F2F1), dialogContext),
                        _buildQuickColorDot(Color(0xFFFCE4EC), dialogContext),
                        _buildQuickColorDot(Color(0xFFE8EAF6), dialogContext),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Text('Cancel', style: TextStyle(fontSize: 11)),
                        ),
                        SizedBox(width: 8),
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          child: Text('Apply', style: TextStyle(fontSize: 11)),
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
        final height = 150.0;
        final hsv = HSVColor.fromColor(currentColor);

        return GestureDetector(
          onTapDown: (details) {
            final dx = (details.localPosition.dx / width).clamp(0.0, 1.0);
            final dy = (details.localPosition.dy / height).clamp(0.0, 1.0);
            final newColor = HSVColor.fromAHSV(1.0, hsv.hue, dx, 1.0 - dy).toColor();
            onColorChanged(newColor);
          },
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
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.white, Colors.transparent],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
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
          onTapDown: (details) {
            final hue = (details.localPosition.dx / width * 360).clamp(0.0, 360.0);
            final hsv = HSVColor.fromColor(currentColor);
            onColorChanged(HSVColor.fromAHSV(1.0, hue, hsv.saturation, hsv.value).toColor());
          },
          onPanUpdate: (details) {
            final hue = (details.localPosition.dx / width * 360).clamp(0.0, 360.0);
            final hsv = HSVColor.fromColor(currentColor);
            onColorChanged(HSVColor.fromAHSV(1.0, hue, hsv.saturation, hsv.value).toColor());
          },
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
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

  Widget _buildQuickColorDot(Color color, BuildContext dialogContext) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(dialogContext);
        setState(() {
          final updatedPage = _pages[_currentPageIndex].copyWith(
            backgroundColor: color,
          );
          _pages[_currentPageIndex] = updatedPage;
          _pages = List.from(_pages);
        });
      },
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAsPdf() async {
    setState(() {
      _isLoadingDocument = true;
      _loadingProgress = 0.0;
      _loadingMessage = 'Exporting as PDF...';
    });

    try {
      final filePath = await ExportService.exportAsPdf(
        _pages,
        'Presentation_Export',
      );

      if (filePath != null) {
        _showSnackBar('PDF exported', Colors.green, Icons.check_circle);
        _showNewPresentationDialog();
      } else {
        _showSnackBar('Failed to export PDF', Colors.red, Icons.error);
      }
    } catch (e) {
      print('Error exporting PDF: $e');
      _showSnackBar('Error: $e', Colors.red, Icons.error);
    } finally {
      setState(() {
        _isLoadingDocument = false;
        _loadingProgress = 0.0;
      });
    }
  }

  Future<void> _exportAsPptx() async {
    setState(() {
      _isLoadingDocument = true;
      _loadingProgress = 0.0;
      _loadingMessage = 'Exporting as PPTX...';
    });

    try {
      final filePath = await ExportService.exportAsPptx(
        _pages,
        'Presentation_Export',
      );

      if (filePath != null) {
        _showSnackBar('PPTX exported', Colors.green, Icons.check_circle);
        _showNewPresentationDialog();
      } else {
        _showSnackBar('Failed to export PPTX', Colors.red, Icons.error);
      }
    } catch (e) {
      print('Error exporting PPTX: $e');
      _showSnackBar('Error: $e', Colors.red, Icons.error);
    } finally {
      setState(() {
        _isLoadingDocument = false;
        _loadingProgress = 0.0;
      });
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'pptx'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final List<String> paths = result.files.map((f) => f.path!).toList();

      final String? pdfPath = paths.any((p) => p.toLowerCase().endsWith('.pdf'))
          ? paths.firstWhere((p) => p.toLowerCase().endsWith('.pdf')) : null;
      final String? pptxPath = paths.any((p) => p.toLowerCase().endsWith('.pptx'))
          ? paths.firstWhere((p) => p.toLowerCase().endsWith('.pptx')) : null;

      setState(() {
        _isLoadingDocument = true;
        _loadingProgress = 0.0;
        _loadingMessage = 'Processing Document...';
      });

      try {
        if (pdfPath != null) {
          await _loadPdf(pdfPath);
        } else if (pptxPath != null) {
          await _loadPptx(pptxPath);
        } else {
          await _loadImages(paths);
        }
      } catch (e) {
        _showSnackBar('Error loading document: $e', Colors.red, Icons.error);
      } finally {
        setState(() {
          _isLoadingDocument = false;
          _loadingProgress = 0.0;
        });
      }
    }
  }

  Future<void> _loadPdf(String path) async {
    setState(() {
      _loadingMessage = 'Loading PDF...';
      _loadingProgress = 0.1;
    });

    final document = await PdfDocument.openFile(path);
    _currentPdfDocument?.dispose();
    _currentPdfDocument = document;

    final List<PresentationPage> newPages = [];
    for (int i = 0; i < document.pages.length; i++) {
      newPages.add(PresentationPage(
        pageNumber: i + 1,
        title: 'PDF Page ${i + 1}',
        subtitle: 'From: ${path.split(Platform.pathSeparator).last}',
        icon: Icons.picture_as_pdf,
        contentType: PageContentType.pdf,
        contentPath: path,
        pdfPageIndex: i,
      ));
    }

    setState(() {
      _pages = newPages;
      _currentPageIndex = 0;
      _undoHistory.clear();
      _redoHistory.clear();
      _loadingProgress = 1.0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  Future<void> _loadImages(List<String> paths) async {
    setState(() {
      _loadingMessage = 'Loading Images...';
      _loadingProgress = 0.5;
    });

    final List<PresentationPage> newPages = [];

    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      newPages.add(PresentationPage(
        pageNumber: i + 1,
        title: 'Image ${i + 1}',
        subtitle: 'From: ${path.split(Platform.pathSeparator).last}',
        icon: Icons.image,
        contentType: PageContentType.image,
        contentPath: path,
      ));
    }

    setState(() {
      _pages = newPages;
      _pptxAspectRatio = 1.5;
      _currentPageIndex = 0;
      _undoHistory.clear();
      _redoHistory.clear();
      _loadingProgress = 1.0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  Future<void> _loadPptx(String path) async {
    setState(() {
      _loadingMessage = 'Loading PPTX...';
      _loadingProgress = 0.1;
    });

    try {
      final imagePaths = await PptxConverterLibreOffice.convertPptxToImages(
        path,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _loadingProgress = progress;
              if (progress < 0.3) {
                _loadingMessage = 'Converting PPTX to PDF...';
              } else if (progress < 0.7) {
                _loadingMessage = 'Converting to images...';
              } else {
                _loadingMessage = 'Finalizing...';
              }
            });
          }
        },
      );

      final List<PresentationPage> newPages = [];

      for (int i = 0; i < imagePaths.length; i++) {
        newPages.add(PresentationPage(
          pageNumber: i + 1,
          title: 'Slide ${i + 1}',
          subtitle: 'From: ${path.split(Platform.pathSeparator).last}',
          icon: Icons.slideshow,
          contentType: PageContentType.image,
          contentPath: imagePaths[i],
        ));
      }

      setState(() {
        _pages = newPages;
        _currentPageIndex = 0;
        _undoHistory.clear();
        _redoHistory.clear();
        _loadingProgress = 1.0;
      });

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    } catch (e) {
      print('Error loading PPTX: $e');
      setState(() {
        _loadingProgress = 1.0;
      });
      _showSnackBar('Error: $e', Colors.red, Icons.error);
    }
  }
}