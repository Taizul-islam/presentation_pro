import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:google_fonts/google_fonts.dart';

import '../models/drawing_stroke.dart';

class ExportService {
  static Future<void> printPages(
    List<PresentationPage> pages, {
    Function(int current, int total)? onProgress,
  }) async {
    print('!!! DEBUG: printPages entered !!!');
    
    try {
      final pdf = pw.Document();
      final Map<String, pdfrx.PdfDocument> docCache = {};

      for (int i = 0; i < pages.length; i++) {
        onProgress?.call(i + 1, pages.length);
        
        final page = pages[i];
        final imageBytes = await _renderPageToImage(page, docCache: docCache);
        
        if (imageBytes != null) {
          final double ratio = page.aspectRatio ?? 16 / 9;
          // Standard A4 width is 595 points. 
          // We use that as base and calculate height to maintain slide shape.
          final double pageWidth = 842.0; // Widescreen landscape base
          final double pageHeight = pageWidth / ratio;

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(pageWidth, pageHeight),
              margin: const pw.EdgeInsets.all(0),
              build: (context) => pw.Center(child: pw.Image(pw.MemoryImage(imageBytes))),
            ),
          );
        }
      }

      for (final doc in docCache.values) {
        await doc.dispose();
      }

      final Uint8List pdfBytes = await pdf.save();
      await Future.delayed(const Duration(milliseconds: 500));

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Presentation',
        dynamicLayout: false,
      );
      
    } catch (e, stack) {
      print('DEBUG: ERROR in printPages: $e');
    }
  }

  static Future<String?> exportAsPdf(
    List<PresentationPage> pages,
    String fileName, {
    Function(int current, int total)? onProgress,
  }) async {
    try {
      final outputPath = await _getSavePath('$fileName.pdf');
      if (outputPath == null) return null;

      final pdf = pw.Document();
      final Map<String, pdfrx.PdfDocument> docCache = {};

      for (int i = 0; i < pages.length; i++) {
        onProgress?.call(i + 1, pages.length);
        final page = pages[i];
        final imageBytes = await _renderPageToImage(page, docCache: docCache);

        if (imageBytes != null) {
          final double ratio = page.aspectRatio ?? 16 / 9;
          final double pageWidth = 842.0;
          final double pageHeight = pageWidth / ratio;

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(pageWidth, pageHeight),
              margin: const pw.EdgeInsets.all(0),
              build: (context) => pw.Center(child: pw.Image(pw.MemoryImage(imageBytes))),
            ),
          );
        }
      }

      for (final doc in docCache.values) {
        await doc.dispose();
      }

      await File(outputPath).writeAsBytes(await pdf.save());
      return outputPath;
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      return null;
    }
  }

  static Future<String?> exportAsPptx(
    List<PresentationPage> pages,
    String fileName, {
    Function(int current, int total)? onProgress,
  }) async {
    try {
      final outputPath = await _getSavePath('$fileName.pptx');
      if (outputPath == null) return null;

      final pptxBytes = await _createProperPptx(pages, onProgress: onProgress);
      await File(outputPath).writeAsBytes(pptxBytes);
      return outputPath;
    } catch (e) {
      debugPrint('Error exporting PPTX: $e');
      return null;
    }
  }

  static Future<String?> _getSavePath(String fileName) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save file as',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [fileName.split('.').last],
      );
      return result;
    } catch (e) {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/$fileName';
    }
  }

  static Future<Uint8List?> _renderPageToImage(
    PresentationPage page, {
    Map<String, pdfrx.PdfDocument>? docCache,
  }) async {
    print('DEBUG: _renderPageToImage starting for page ${page.pageNumber}');
    try {
      // 1. High Resolution Setup (4K base)
      const double targetWidth = 3000.0;
      final double ratio = page.aspectRatio ?? 16 / 9;
      final double targetHeight = targetWidth / ratio;
      
      print('DEBUG: Target high-res dimensions: ${targetWidth.toInt()}x${targetHeight.toInt()}');

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 2. Background
      final bgColor = page.backgroundColor ?? Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, targetWidth, targetHeight), Paint()..color = bgColor);

      if (page.contentPath != null && page.contentPath!.isNotEmpty) {
        print('DEBUG: Processing background content...');
        ui.Image? bgImage;
        
        if (page.contentType == PageContentType.pdf && page.pdfPageIndex != null) {
          pdfrx.PdfDocument? doc;
          if (docCache != null && docCache.containsKey(page.contentPath)) {
            doc = docCache[page.contentPath];
          } else {
            doc = await pdfrx.PdfDocument.openFile(page.contentPath!);
            docCache?[page.contentPath!] = doc;
          }

          if (doc != null) {
            final pdfPage = doc.pages[page.pdfPageIndex!];
            final pdfImage = await pdfPage.render(
              fullWidth: targetWidth,
              fullHeight: targetHeight,
            );
            if (pdfImage != null) {
              bgImage = await pdfImage.createImage();
            }
          }
        } else {
          final file = File(page.contentPath!);
          if (file.existsSync()) {
            final bytes = await file.readAsBytes();
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            bgImage = frame.image;
          }
        }

        if (bgImage != null) {
          // Draw background with high quality filtering
          canvas.drawImageRect(
            bgImage,
            Rect.fromLTWH(0, 0, bgImage.width.toDouble(), bgImage.height.toDouble()),
            Rect.fromLTWH(0, 0, targetWidth, targetHeight),
            Paint()..filterQuality = ui.FilterQuality.high,
          );
          bgImage.dispose();
        }
      }

      // 3. Drawing Strokes
      print('DEBUG: Drawing ${page.strokes.length} strokes...');
      // We use 1920 as the "standard" width for stroke thickness math
      final double thicknessScale = targetWidth / 1920.0;

      for (final stroke in page.strokes) {
        if (stroke.points.length < 2) continue;

        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.width * thicknessScale
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;

        if (stroke.tool == DrawingTool.eraser) {
          paint.blendMode = ui.BlendMode.clear;
        }

        if (stroke.tool == DrawingTool.highlighter) {
          paint.color = stroke.color.withOpacity(0.3);
          paint.strokeWidth *= 3;
        }

        final path = Path();
        // Points are normalized (0.0 - 1.0)
        path.moveTo(stroke.points[0].dx * targetWidth, stroke.points[0].dy * targetHeight);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx * targetWidth, stroke.points[i].dy * targetHeight);
        }
        canvas.drawPath(path, paint);
      }

      // 4. Text Elements
      print('DEBUG: Drawing ${page.texts.length} text elements...');
      for (final textElement in page.texts) {
        if (textElement.text.trim().isEmpty) continue;

        final textStyle = _getRenderTextStyle(textElement);
        // Important: Use the same scale for text font and box width
        final textSpan = TextSpan(
          text: textElement.text,
          style: textStyle.copyWith(fontSize: textElement.fontSize * thicknessScale),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textAlign: textElement.alignment,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout(maxWidth: textElement.width * thicknessScale);
        textPainter.paint(
          canvas,
          Offset(textElement.position.dx * targetWidth, textElement.position.dy * targetHeight),
        );
      }

      print('DEBUG: Ending recording...');
      final picture = recorder.endRecording();
      
      print('DEBUG: Converting picture to image (3000x${targetHeight.toInt()})...');
      final finalImage = await picture.toImage(targetWidth.toInt(), targetHeight.toInt());
      
      print('DEBUG: Converting image to byte data (PNG)...');
      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('DEBUG: toByteData TIMEOUT after 30s');
          return null;
        },
      );
      
      finalImage.dispose();

      if (byteData == null) return null;
      print('DEBUG: _renderPageToImage complete');
      return byteData.buffer.asUint8List();
    } catch (e, stack) {
      print('DEBUG: Error in _renderPageToImage: $e');
      return null;
    }
  }

  static TextStyle _getRenderTextStyle(DrawingText element) {
    try {
      return GoogleFonts.getFont(
        element.fontFamily,
        color: element.color,
        fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: element.isUnderlined ? TextDecoration.underline : TextDecoration.none,
      );
    } catch (e) {
      return TextStyle(
        color: element.color,
        fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: element.isUnderlined ? TextDecoration.underline : TextDecoration.none,
      );
    }
  }

  static Future<Uint8List> _createProperPptx(
    List<PresentationPage> pages, {
    Function(int current, int total)? onProgress,
  }) async {
    final archive = Archive();
    final Map<String, pdfrx.PdfDocument> docCache = {};

    final contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
  ${pages.asMap().entries.map((e) => '<Override PartName="/ppt/slides/slide${e.key + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>').join('\n  ')}
</Types>''';

    final contentTypesBytes = utf8.encode(contentTypes);
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesBytes.length, contentTypesBytes));

    final rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';

    final rootRelsBytes = utf8.encode(rootRels);
    archive.addFile(ArchiveFile('_rels/.rels', rootRelsBytes.length, rootRelsBytes));

    final slideIds = pages.asMap().entries.map((e) =>
    '<p:sldId id="${256 + e.key}" r:id="rId${e.key + 1}"/>'
    ).join('\n    ');

    final presentationXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldMasterIdLst>
    <p:sldMasterId id="2147483648" r:id="rId${pages.length + 1}"/>
  </p:sldMasterIdLst>
  <p:sldIdLst>
    $slideIds
  </p:sldIdLst>
  <p:sldSz cx="9144000" cy="6858000"/>
  <p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>''';

    final presentationBytes = utf8.encode(presentationXml);
    archive.addFile(ArchiveFile('ppt/presentation.xml', presentationBytes.length, presentationBytes));

    var relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId${pages.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
''';

    for (int i = 0; i < pages.length; i++) {
      relsXml += '  <Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${i + 1}.xml"/>\n';
    }

    relsXml += '</Relationships>';

    final relsBytes = utf8.encode(relsXml);
    archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', relsBytes.length, relsBytes));

    final slideMasterXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr>
        <p:cNvPr id="1" name=""/>
        <p:cNvGrpSpPr/>
        <p:nvPr/>
      </p:nvGrpSpPr>
      <p:grpSpPr>
        <a:xfrm>
          <a:off x="0" y="0"/>
          <a:ext cx="0" cy="0"/>
          <a:chOff x="0" y="0"/>
          <a:chExt cx="0" cy="0"/>
        </a:xfrm>
      </p:grpSpPr>
    </p:spTree>
  </p:cSld>
  <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
  <p:sldLayoutIdLst>
    <p:sldLayoutId id="2147483649" r:id="rId1"/>
  </p:sldLayoutIdLst>
</p:sldMaster>''';

    final slideMasterBytes = utf8.encode(slideMasterXml);
    archive.addFile(ArchiveFile('ppt/slideMasters/slideMaster1.xml', slideMasterBytes.length, slideMasterBytes));

    final slideMasterRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>''';

    final slideMasterRelsBytes = utf8.encode(slideMasterRels);
    archive.addFile(ArchiveFile('ppt/slideMasters/_rels/slideMaster1.xml.rels', slideMasterRelsBytes.length, slideMasterRelsBytes));

    final slideLayoutXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr>
        <p:cNvPr id="1" name=""/>
        <p:cNvGrpSpPr/>
        <p:nvPr/>
      </p:nvGrpSpPr>
      <p:grpSpPr>
        <a:xfrm>
          <a:off x="0" y="0"/>
          <a:ext cx="0" cy="0"/>
          <a:chOff x="0" y="0"/>
          <a:chExt cx="0" cy="0"/>
        </a:xfrm>
      </p:grpSpPr>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr>
    <a:overrideClrMapping bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
  </p:clrMapOvr>
</p:sldLayout>''';

    final slideLayoutBytes = utf8.encode(slideLayoutXml);
    archive.addFile(ArchiveFile('ppt/slideLayouts/slideLayout1.xml', slideLayoutBytes.length, slideLayoutBytes));

    for (int i = 0; i < pages.length; i++) {
      final imageBytes = await _renderPageToImage(pages[i]);

      if (imageBytes != null) {
        archive.addFile(ArchiveFile('ppt/media/slide${i + 1}.png', imageBytes.length, imageBytes));

        final slideXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr>
        <p:cNvPr id="1" name=""/>
        <p:cNvGrpSpPr/>
        <p:nvPr/>
      </p:nvGrpSpPr>
      <p:grpSpPr>
        <a:xfrm>
          <a:off x="0" y="0"/>
          <a:ext cx="0" cy="0"/>
          <a:chOff x="0" y="0"/>
          <a:chExt cx="0" cy="0"/>
        </a:xfrm>
      </p:grpSpPr>
      <p:pic>
        <p:nvPicPr>
          <p:cNvPr id="${i + 2}" name="Slide ${i + 1}"/>
          <p:cNvPicPr/>
          <p:nvPr/>
        </p:nvPicPr>
        <p:blipFill>
          <a:blip r:embed="rId1"/>
          <a:stretch>
            <a:fillRect/>
          </a:stretch>
        </p:blipFill>
        <p:spPr>
          <a:xfrm>
            <a:off x="0" y="0"/>
            <a:ext cx="9144000" cy="6858000"/>
          </a:xfrm>
          <a:prstGeom prst="rect">
            <a:avLst/>
          </a:prstGeom>
        </p:spPr>
      </p:pic>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr>
    <a:overrideClrMapping bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
  </p:clrMapOvr>
</p:sld>''';

        final slideBytes = utf8.encode(slideXml);
        archive.addFile(ArchiveFile('ppt/slides/slide${i + 1}.xml', slideBytes.length, slideBytes));

        final slideRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/slide${i + 1}.png"/>
</Relationships>''';

        final slideRelsBytes = utf8.encode(slideRels);
        archive.addFile(ArchiveFile('ppt/slides/_rels/slide${i + 1}.xml.rels', slideRelsBytes.length, slideRelsBytes));
      }
    }

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    return Uint8List.fromList(zipBytes);
  }
}