import 'package:flutter/material.dart';

enum DrawingTool {
  pen,
  highlighter,
  eraser,
  selector,
}

enum PageContentType {
  placeholder,
  image,
  pdf,
  pptx,
}

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final DrawingTool tool;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
  });

  Rect get boundingBox {
    if (points.isEmpty) return Rect.zero;
    double left = points[0].dx;
    double top = points[0].dy;
    double right = points[0].dx;
    double bottom = points[0].dy;

    for (final p in points) {
      if (p.dx < left) left = p.dx;
      if (p.dx > right) right = p.dx;
      if (p.dy < top) top = p.dy;
      if (p.dy > bottom) bottom = p.dy;
    }
    // Add stroke width to the bounding box
    return Rect.fromLTRB(left, top, right, bottom).inflate(width / 2);
  }

  DrawingStroke translate(Offset delta) {
    return DrawingStroke(
      points: points.map((p) => p + delta).toList(),
      color: color,
      width: width,
      tool: tool,
    );
  }
}

class PresentationPage {
  final int pageNumber;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<DrawingStroke> strokes;
  final PageContentType contentType;
  final String? contentPath;
  final int? pdfPageIndex;
  final dynamic extraData;
  final Color? backgroundColor;
  final double? aspectRatio;

  PresentationPage({
    required this.pageNumber,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.strokes = const [],
    this.contentType = PageContentType.placeholder,
    this.contentPath,
    this.pdfPageIndex,
    this.extraData,
    this.backgroundColor = Colors.white,
    this.aspectRatio,
  });

  PresentationPage copyWith({
    List<DrawingStroke>? strokes,
    PageContentType? contentType,
    String? contentPath,
    int? pdfPageIndex,
    dynamic extraData,
    Color? backgroundColor,
    double? aspectRatio,
  }) {
    return PresentationPage(
      pageNumber: pageNumber,
      title: title,
      subtitle: subtitle,
      icon: icon,
      strokes: strokes ?? this.strokes,
      contentType: contentType ?? this.contentType,
      contentPath: contentPath ?? this.contentPath,
      pdfPageIndex: pdfPageIndex ?? this.pdfPageIndex,
      extraData: extraData ?? this.extraData,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }
}
