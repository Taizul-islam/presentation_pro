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

import '../models/drawing_stroke.dart';

class ExportService {
  static Future<void> printPages(
    List<PresentationPage> pages, {
    Function(int current, int total)? onProgress,
  }) async {
    // HEARTBEAT LOG - Using multiple methods to ensure visibility
    print('!!! CRITICAL DEBUG: printPages entered !!!');
    debugPrint('!!! CRITICAL DEBUG: printPages entered (debugPrint) !!!');
    
    try {
      final pdf = pw.Document();
      final Map<String, pdfrx.PdfDocument> docCache = {};

      print('DEBUG: Number of pages to process: ${pages.length}');

      for (int i = 0; i < pages.length; i++) {
        print('DEBUG: Processing slide index $i...');
        onProgress?.call(i + 1, pages.length);
        
        final page = pages[i];
        final imageBytes = await _renderPageToImage(page, docCache: docCache);
        
        if (imageBytes != null) {
          print('DEBUG: Slide $i rendered (${imageBytes.length} bytes)');
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (context) => pw.Center(child: pw.Image(pw.MemoryImage(imageBytes))),
            ),
          );
        } else {
          print('DEBUG: Slide $i render returned NULL');
        }
      }

      print('DEBUG: Disposing cache...');
      for (final doc in docCache.values) {
        await doc.dispose();
      }

      print('DEBUG: Pre-saving PDF document...');
      final Uint8List pdfBytes = await pdf.save();
      print('DEBUG: PDF document saved (${pdfBytes.length} bytes)');

      // IMPORTANT: Give the macOS event loop time to settle before opening a native sheet
      print('DEBUG: Yielding thread for 500ms...');
      await Future.delayed(const Duration(milliseconds: 500));

      print('DEBUG: Calling Printing.layoutPdf...');
      try {
        final success = await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: 'Presentation',
          dynamicLayout: false,
        );
        print('DEBUG: Printing.layoutPdf finished (Result: $success)');
      } catch (printError) {
        print('DEBUG: Printing.layoutPdf failed directly: $printError');
        print('DEBUG: Attempting fallback to sharePdf...');
        await Printing.sharePdf(bytes: pdfBytes, filename: 'presentation.pdf');
      }
      
    } catch (e, stack) {
      print('DEBUG: ERROR in printPages: $e');
      print('DEBUG: STACKTRACE: $stack');
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
        final imageBytes = await _renderPageToImage(pages[i], docCache: docCache);

        if (imageBytes != null) {
          final image = pw.MemoryImage(imageBytes);
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (context) => pw.Center(child: pw.Image(image)),
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
      const double width = 1200;
      final double height = width / (page.aspectRatio ?? 16 / 9);
      print('DEBUG: Target dimensions: ${width}x${height}');

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final bgColor = page.backgroundColor ?? Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = bgColor);

      if (page.contentPath != null && page.contentPath!.isNotEmpty) {
        print('DEBUG: Processing content from ${page.contentPath}');
        if (page.contentType == PageContentType.pdf && page.pdfPageIndex != null) {
          pdfrx.PdfDocument? doc;
          if (docCache != null && docCache.containsKey(page.contentPath)) {
            print('DEBUG: Using cached PDF document');
            doc = docCache[page.contentPath];
          } else {
            print('DEBUG: Opening new PDF document...');
            doc = await pdfrx.PdfDocument.openFile(page.contentPath!);
            docCache?[page.contentPath!] = doc;
          }

          if (doc != null) {
            print('DEBUG: Rendering PDF page ${page.pdfPageIndex}');
            final pdfPage = doc.pages[page.pdfPageIndex!];
            final pdfImage = await pdfPage.render(
              fullWidth: width,
              fullHeight: height,
            );
            if (pdfImage != null) {
              print('DEBUG: Creating ui.Image from PdfImage...');
              final uiImage = await pdfImage.createImage();
              canvas.drawImageRect(
                uiImage,
                Rect.fromLTWH(0, 0, uiImage.width.toDouble(), uiImage.height.toDouble()),
                Rect.fromLTWH(0, 0, width, height),
                Paint(),
              );
              uiImage.dispose();
            }
          }
        } else {
          print('DEBUG: Handling as standard image...');
          final file = File(page.contentPath!);
          if (file.existsSync()) {
            final bytes = await file.readAsBytes();
            print('DEBUG: Image bytes read (${bytes.length}). Decoding...');
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            final image = frame.image;
            
            canvas.drawImageRect(
              image,
              Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
              Rect.fromLTWH(0, 0, width, height),
              Paint(),
            );
            image.dispose();
          }
        }
      }

      print('DEBUG: Drawing ${page.strokes.length} strokes...');
      for (final stroke in page.strokes) {
        if (stroke.points.length < 2) continue;

        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.width * (width / 800)
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
        final scaleX = width / 800;
        final scaleY = height / (800 / (page.aspectRatio ?? 16/9));

        path.moveTo(stroke.points[0].dx * scaleX, stroke.points[0].dy * scaleY);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx * scaleX, stroke.points[i].dy * scaleY);
        }
        canvas.drawPath(path, paint);
      }

      print('DEBUG: Ending recording...');
      final picture = recorder.endRecording();
      
      print('DEBUG: Converting picture to image (1200x${height.toInt()})...');
      final finalImage = await picture.toImage(width.toInt(), height.toInt());
      
      print('DEBUG: Converting image to byte data (PNG)...');
      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('DEBUG: toByteData TIMEOUT');
          return null;
        },
      );
      
      print('DEBUG: Disposing final image...');
      finalImage.dispose();

      if (byteData == null) return null;
      print('DEBUG: _renderPageToImage complete');
      return byteData.buffer.asUint8List();
    } catch (e, stack) {
      print('DEBUG: Error in _renderPageToImage: $e');
      print('DEBUG: Stack trace: $stack');
      return null;
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