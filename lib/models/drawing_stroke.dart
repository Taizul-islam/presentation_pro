import 'package:flutter/material.dart';

enum DrawingTool {
  pen,
  highlighter,
  eraser,
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
  });

  PresentationPage copyWith({
    List<DrawingStroke>? strokes,
    PageContentType? contentType,
    String? contentPath,
    int? pdfPageIndex,
    dynamic extraData,
    Color? backgroundColor,
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
    );
  }
}