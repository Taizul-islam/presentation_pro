import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:google_fonts/google_fonts.dart';
import 'package:archive/archive.dart';

import '../models/drawing_stroke.dart';

class ExportService {
  static Future<void> printPages(
      List<PresentationPage> pages, {
        Function(int current, int total)? onProgress,
      }) async {
    try {
      final pdf = pw.Document();
      final Map<String, pdfrx.PdfDocument> docCache = {};

      final double slideRatio = pages.isNotEmpty
          ? (pages[0].aspectRatio ?? 16 / 9)
          : 16 / 9;

      for (int i = 0; i < pages.length; i++) {
        onProgress?.call(i + 1, pages.length);

        final page = pages[i];
        final imageBytes = await _renderPageToImage(
          page,
          docCache: docCache,
          forcedRatio: slideRatio,
        );

        if (imageBytes != null) {
          const double pageWidth = 1280.0;
          final double pageHeight = pageWidth / slideRatio;

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(pageWidth, pageHeight),
              margin: const pw.EdgeInsets.all(0),
              build: (context) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(
                  pw.MemoryImage(imageBytes),
                  fit: pw.BoxFit.fill,
                ),
              ),
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
    } catch (e) {
      debugPrint('Error in printPages: $e');
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

      final double slideRatio = pages.isNotEmpty
          ? (pages[0].aspectRatio ?? 16 / 9)
          : 16 / 9;

      for (int i = 0; i < pages.length; i++) {
        onProgress?.call(i + 1, pages.length);
        final page = pages[i];

        final imageBytes = await _renderPageToImage(
          page,
          docCache: docCache,
          forcedRatio: slideRatio,
        );

        if (imageBytes != null) {
          const double pageWidth = 1280.0;
          final double pageHeight = pageWidth / slideRatio;

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(pageWidth, pageHeight),
              margin: const pw.EdgeInsets.all(0),
              build: (context) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(
                  pw.MemoryImage(imageBytes),
                  fit: pw.BoxFit.fill,
                ),
              ),
            ),
          );
        }
      }

      for (final doc in docCache.values) {
        await doc.dispose();
      }

      final bytes = await pdf.save();

      final file = File(outputPath);
      await file.writeAsBytes(bytes);

      if (!await file.exists() || await file.length() == 0) {
        throw Exception('File save failed. The path may be invalid or too long.');
      }

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

      final double slideRatio = pages.isNotEmpty
          ? (pages[0].aspectRatio ?? 16 / 9)
          : 16 / 9;

      const double baseWidthEmu = 9144000.0;
      final int slideWidthEmu = baseWidthEmu.toInt();
      final int slideHeightEmu = (baseWidthEmu / slideRatio).toInt();

      final Map<String, pdfrx.PdfDocument> docCache = {};
      final archive = Archive();

      // [Content_Types].xml
      final contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
  ${pages.asMap().entries.map((e) => '<Override PartName="/ppt/slides/slide${e.key + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>').join('\n  ')}
</Types>''';
      archive.addFile(ArchiveFile(
        '[Content_Types].xml',
        utf8.encode(contentTypes).length,
        utf8.encode(contentTypes),
      ));

      // _rels/.rels
      final rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';
      archive.addFile(ArchiveFile(
        '_rels/.rels',
        utf8.encode(rootRels).length,
        utf8.encode(rootRels),
      ));

      // ppt/presentation.xml
      final slideIds = pages.asMap().entries
          .map((e) => '<p:sldId id="${256 + e.key}" r:id="rId${e.key + 1}"/>')
          .join('\n    ');

      final presentationXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldMasterIdLst>
    <p:sldMasterId id="2147483648" r:id="rId${pages.length + 1}"/>
  </p:sldMasterIdLst>
  <p:sldIdLst>
    $slideIds
  </p:sldIdLst>
  <p:sldSz cx="$slideWidthEmu" cy="$slideHeightEmu"/>
  <p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>''';
      archive.addFile(ArchiveFile(
        'ppt/presentation.xml',
        utf8.encode(presentationXml).length,
        utf8.encode(presentationXml),
      ));

      // ppt/_rels/presentation.xml.rels
      var relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId${pages.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
  <Relationship Id="rId${pages.length + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
''';
      for (int i = 0; i < pages.length; i++) {
        relsXml += '  <Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${i + 1}.xml"/>\n';
      }
      relsXml += '</Relationships>';
      archive.addFile(ArchiveFile(
        'ppt/_rels/presentation.xml.rels',
        utf8.encode(relsXml).length,
        utf8.encode(relsXml),
      ));

      // ppt/slideMasters/slideMaster1.xml
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
  <p:txStyles>
    <p:titleStyle>
      <a:lvl1pPr algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1">
        <a:spcBef><a:spcPct val="0"/></a:spcBef>
        <a:buNone/>
        <a:defRPr sz="4400" kern="1200">
          <a:solidFill><a:schemeClr val="tx1"/></a:solidFill>
          <a:latin typeface="+mj-lt"/><a:ea typeface="+mj-ea"/><a:cs typeface="+mj-cs"/>
        </a:defRPr>
      </a:lvl1pPr>
    </p:titleStyle>
    <p:bodyStyle>
      <a:lvl1pPr marL="342900" indent="-342900" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1">
        <a:spcBef><a:spcPct val="20000"/></a:spcBef>
        <a:buFont typeface="Arial" pitchFamily="34" charset="0"/>
        <a:buChar char="•"/>
        <a:defRPr sz="2800" kern="1200">
          <a:solidFill><a:schemeClr val="tx1"/></a:solidFill>
          <a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/>
        </a:defRPr>
      </a:lvl1pPr>
    </p:bodyStyle>
    <p:otherStyle>
      <a:defPPr>
        <a:defRPr lang="en-US"/>
      </a:defPPr>
    </p:otherStyle>
  </p:txStyles>
</p:sldMaster>''';
      archive.addFile(ArchiveFile(
        'ppt/slideMasters/slideMaster1.xml',
        utf8.encode(slideMasterXml).length,
        utf8.encode(slideMasterXml),
      ));

      // ppt/slideMasters/_rels/slideMaster1.xml.rels
      final slideMasterRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
</Relationships>''';
      archive.addFile(ArchiveFile(
        'ppt/slideMasters/_rels/slideMaster1.xml.rels',
        utf8.encode(slideMasterRels).length,
        utf8.encode(slideMasterRels),
      ));

      // ppt/slideLayouts/slideLayout1.xml
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
      archive.addFile(ArchiveFile(
        'ppt/slideLayouts/slideLayout1.xml',
        utf8.encode(slideLayoutXml).length,
        utf8.encode(slideLayoutXml),
      ));

      // ppt/slideLayouts/_rels/slideLayout1.xml.rels
      final slideLayoutRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>''';
      archive.addFile(ArchiveFile(
        'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
        utf8.encode(slideLayoutRels).length,
        utf8.encode(slideLayoutRels),
      ));

      // ppt/theme/theme1.xml
      final themeXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
  <a:themeElements>
    <a:clrScheme name="Office">
      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="44546A"/></a:dk2>
      <a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>
      <a:accent1><a:srgbClr val="4472C4"/></a:accent1>
      <a:accent2><a:srgbClr val="ED7D31"/></a:accent2>
      <a:accent3><a:srgbClr val="A5A5A5"/></a:accent3>
      <a:accent4><a:srgbClr val="FFC000"/></a:accent4>
      <a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>
      <a:accent6><a:srgbClr val="70AD47"/></a:accent6>
      <a:hlink><a:srgbClr val="0563C1"/></a:hlink>
      <a:folHlink><a:srgbClr val="954F72"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="Office">
      <a:majorFont>
        <a:latin typeface="Calibri Light" panose="020F0302020204030204"/>
        <a:ea typeface=""/>
        <a:cs typeface=""/>
      </a:majorFont>
      <a:minorFont>
        <a:latin typeface="Calibri" panose="020F0502020204030204"/>
        <a:ea typeface=""/>
        <a:cs typeface=""/>
      </a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="Office">
      <a:fillStyleLst>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:gradFill rotWithShape="1">
          <a:gsLst>
            <a:gs pos="0"><a:schemeClr val="phClr"><a:lumMod val="110000"/><a:satMod val="105000"/><a:tint val="67000"/></a:schemeClr></a:gs>
            <a:gs pos="50000"><a:schemeClr val="phClr"><a:lumMod val="105000"/><a:satMod val="103000"/><a:tint val="73000"/></a:schemeClr></a:gs>
            <a:gs pos="100000"><a:schemeClr val="phClr"><a:lumMod val="105000"/><a:satMod val="109000"/><a:tint val="81000"/></a:schemeClr></a:gs>
          </a:gsLst>
          <a:lin ang="5400000" scaled="0"/>
        </a:gradFill>
        <a:gradFill rotWithShape="1">
          <a:gsLst>
            <a:gs pos="0"><a:schemeClr val="phClr"><a:satMod val="103000"/><a:lumMod val="102000"/><a:tint val="94000"/></a:schemeClr></a:gs>
            <a:gs pos="50000"><a:schemeClr val="phClr"><a:satMod val="110000"/><a:lumMod val="100000"/><a:shade val="100000"/></a:schemeClr></a:gs>
            <a:gs pos="100000"><a:schemeClr val="phClr"><a:lumMod val="99000"/><a:satMod val="120000"/><a:shade val="78000"/></a:schemeClr></a:gs>
          </a:gsLst>
          <a:lin ang="5400000" scaled="0"/>
        </a:gradFill>
      </a:fillStyleLst>
      <a:lnStyleLst>
        <a:ln w="6350" cap="flat" cmpd="sng" algn="ctr">
          <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
          <a:prstDash val="solid"/>
          <a:miter lim="800000"/>
        </a:ln>
        <a:ln w="12700" cap="flat" cmpd="sng" algn="ctr">
          <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
          <a:prstDash val="solid"/>
          <a:miter lim="800000"/>
        </a:ln>
        <a:ln w="19050" cap="flat" cmpd="sng" algn="ctr">
          <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
          <a:prstDash val="solid"/>
          <a:miter lim="800000"/>
        </a:ln>
      </a:lnStyleLst>
      <a:effectStyleLst>
        <a:effectStyle><a:effectLst/></a:effectStyle>
        <a:effectStyle><a:effectLst/></a:effectStyle>
        <a:effectStyle><a:effectLst/></a:effectStyle>
      </a:effectStyleLst>
      <a:bgFillStyleLst>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
      </a:bgFillStyleLst>
    </a:fmtScheme>
  </a:themeElements>
  <a:objectDefaults/>
  <a:extraClrSchemeLst/>
</a:theme>''';
      archive.addFile(ArchiveFile(
        'ppt/theme/theme1.xml',
        utf8.encode(themeXml).length,
        utf8.encode(themeXml),
      ));

      // Render each page and add slide XML + image
      for (int i = 0; i < pages.length; i++) {
        onProgress?.call(i + 1, pages.length);
        final page = pages[i];

        final imageBytes = await _renderPageToImage(
          page,
          docCache: docCache,
          forcedRatio: slideRatio,
        );

        if (imageBytes == null) continue;

        archive.addFile(ArchiveFile(
          'ppt/media/slide${i + 1}.png',
          imageBytes.length,
          imageBytes,
        ));

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
            <a:ext cx="$slideWidthEmu" cy="$slideHeightEmu"/>
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
        archive.addFile(ArchiveFile(
          'ppt/slides/slide${i + 1}.xml',
          utf8.encode(slideXml).length,
          utf8.encode(slideXml),
        ));

        final slideRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/slide${i + 1}.png"/>
</Relationships>''';
        archive.addFile(ArchiveFile(
          'ppt/slides/_rels/slide${i + 1}.xml.rels',
          utf8.encode(slideRels).length,
          utf8.encode(slideRels),
        ));
      }

      for (final doc in docCache.values) {
        await doc.dispose();
      }

      // Filter duplicate entries
      final Set<String> addedFiles = {};
      final Archive validatedArchive = Archive();
      for (final file in archive.files) {
        if (addedFiles.contains(file.name)) {
          debugPrint('Skipping duplicate: ${file.name}');
          continue;
        }
        addedFiles.add(file.name);
        validatedArchive.addFile(file);
      }

      final zipBytes = ZipEncoder().encode(validatedArchive);

      final file = File(outputPath);
      await file.writeAsBytes(zipBytes);

      if (!await file.exists() || await file.length() == 0) {
        throw Exception('PPTX file save failed.');
      }

      return outputPath;
    } catch (e) {
      debugPrint('Error exporting PPTX: $e');
      return null;
    }
  }

  static Future<String?> _getSavePath(String fileName) async {
    try {
      final safeFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Presentation As',
        fileName: safeFileName,
        type: FileType.custom,
        allowedExtensions: [safeFileName.split('.').last],
      );

      if (result != null) {
        try {
          final testFile = File(result);
          await testFile.writeAsBytes([0]);
          await testFile.delete();
          return result;
        } catch (writeError) {
          debugPrint('DEBUG: Path is not writable: $writeError');
        }
      }
    } catch (e) {
      debugPrint('DEBUG: File picker failed: $e');
    }

    try {
      final tempDir = Directory.systemTemp;
      final shortPath = '${tempDir.path}${Platform.pathSeparator}Export_${DateTime.now().millisecondsSinceEpoch}.${fileName.split('.').last}';
      return shortPath;
    } catch (fallbackError) {
      return null;
    }
  }

  static Future<Uint8List?> _renderPageToImage(
      PresentationPage page, {
        Map<String, pdfrx.PdfDocument>? docCache,
        double? forcedRatio,
      }) async {
    try {
      const double targetWidth = 4000.0;
      final double ratio = forcedRatio ?? page.aspectRatio ?? 16 / 9;
      final double targetHeight = targetWidth / ratio;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final bgColor = page.backgroundColor ?? Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, targetWidth, targetHeight),
        Paint()..color = bgColor,
      );

      if (page.contentPath != null && page.contentPath!.isNotEmpty) {
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
          final double bgW = bgImage.width.toDouble();
          final double bgH = bgImage.height.toDouble();
          final double bgRatio = bgW / bgH;

          double srcX = 0, srcY = 0, srcW = bgW, srcH = bgH;
          if (bgRatio > ratio) {
            srcW = bgH * ratio;
            srcX = (bgW - srcW) / 2;
          } else if (bgRatio < ratio) {
            srcH = bgW / ratio;
            srcY = (bgH - srcH) / 2;
          }

          canvas.drawImageRect(
            bgImage,
            Rect.fromLTWH(srcX, srcY, srcW, srcH),
            Rect.fromLTWH(0, 0, targetWidth, targetHeight),
            Paint()..filterQuality = ui.FilterQuality.high,
          );
          bgImage.dispose();
        }
      }

      final double scaleFactor = targetWidth / 1920.0;

      for (final stroke in page.strokes) {
        if (stroke.points.length < 2) continue;

        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.width * scaleFactor
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
        path.moveTo(
          stroke.points[0].dx * targetWidth,
          stroke.points[0].dy * targetHeight,
        );
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(
            stroke.points[i].dx * targetWidth,
            stroke.points[i].dy * targetHeight,
          );
        }
        canvas.drawPath(path, paint);
      }

      for (final textElement in page.texts) {
        if (textElement.text.trim().isEmpty) continue;

        final textStyle = _getRenderTextStyle(textElement);
        final textSpan = TextSpan(
          text: textElement.text,
          style: textStyle.copyWith(fontSize: textElement.fontSize * scaleFactor),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textAlign: textElement.alignment,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout(maxWidth: (textElement.width * scaleFactor) + 20);
        textPainter.paint(
          canvas,
          Offset(
            textElement.position.dx * targetWidth,
            textElement.position.dy * targetHeight,
          ),
        );
      }

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(
        targetWidth.toInt(),
        targetHeight.toInt(),
      );

      final byteData = await finalImage.toByteData(
        format: ui.ImageByteFormat.png,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => null,
      );

      finalImage.dispose();

      if (byteData == null) return null;

      return Uint8List.fromList(byteData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error in _renderPageToImage: $e');
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
        decoration: element.isUnderlined
            ? TextDecoration.underline
            : TextDecoration.none,
      );
    } catch (e) {
      return TextStyle(
        color: element.color,
        fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: element.isUnderlined
            ? TextDecoration.underline
            : TextDecoration.none,
      );
    }
  }
}