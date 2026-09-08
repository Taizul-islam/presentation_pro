import 'dart:math' as math;
import 'package:flutter/material.dart';

enum DrawingTool {
  pen,
  highlighter,
  eraser,
  selector,
  hand,
  text,
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
  final bool isLocked;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
    this.isLocked = false,
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
    if (isLocked) return this;
    return DrawingStroke(
      points: points.map((p) => p + delta).toList(),
      color: color,
      width: width,
      tool: tool,
      isLocked: isLocked,
    );
  }

  DrawingStroke scale(double scaleX, double scaleY, Offset origin) {
    if (isLocked) return this;
    return DrawingStroke(
      points: points.map((p) {
        double dx = origin.dx + (p.dx - origin.dx) * scaleX;
        double dy = origin.dy + (p.dy - origin.dy) * scaleY;
        return Offset(dx, dy);
      }).toList(),
      color: color,
      width: width, 
      tool: tool,
      isLocked: isLocked,
    );
  }

  DrawingStroke rotate(double angle, Offset center) {
    if (isLocked) return this;
    return DrawingStroke(
      points: points.map((p) {
        double x = p.dx - center.dx;
        double y = p.dy - center.dy;

        double cosA = math.cos(angle);
        double sinA = math.sin(angle);

        double newX = x * cosA - y * sinA;
        double newY = x * sinA + y * cosA;

        return Offset(newX + center.dx, newY + center.dy);
      }).toList(),
      color: color,
      width: width,
      tool: tool,
      isLocked: isLocked,
    );
  }

  DrawingStroke flip(bool horizontal, Offset center) {
    if (isLocked) return this;
    return DrawingStroke(
      points: points.map((p) {
        double dx = horizontal ? center.dx - (p.dx - center.dx) : p.dx;
        double dy = horizontal ? p.dy : center.dy - (p.dy - center.dy);
        return Offset(dx, dy);
      }).toList(),
      color: color,
      width: width,
      tool: tool,
      isLocked: isLocked,
    );
  }

  DrawingStroke copyWith({
    List<Offset>? points,
    Color? color,
    double? width,
    DrawingTool? tool,
    bool? isLocked,
  }) {
    return DrawingStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      tool: tool ?? this.tool,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class DrawingText {
  final String text;
  final Offset position;
  final double width;
  final double fontSize;
  final String fontFamily;
  final bool isBold;
  final bool isItalic;
  final bool isUnderlined;
  final Color color;
  final TextAlign alignment;
  final bool isLocked;

  DrawingText({
    this.text = '',
    required this.position,
    this.width = 200,
    this.fontSize = 24,
    this.fontFamily = 'Roboto',
    this.isBold = false,
    this.isItalic = false,
    this.isUnderlined = false,
    this.color = Colors.black,
    this.alignment = TextAlign.left,
    this.isLocked = false,
  });

  DrawingText copyWith({
    String? text,
    Offset? position,
    double? width,
    double? fontSize,
    String? fontFamily,
    bool? isBold,
    bool? isItalic,
    bool? isUnderlined,
    Color? color,
    TextAlign? alignment,
    bool? isLocked,
  }) {
    return DrawingText(
      text: text ?? this.text,
      position: position ?? this.position,
      width: width ?? this.width,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderlined: isUnderlined ?? this.isUnderlined,
      color: color ?? this.color,
      alignment: alignment ?? this.alignment,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  DrawingText translate(Offset delta) {
    if (isLocked) return this;
    return copyWith(position: position + delta);
  }
}

class PresentationPage {
  final int pageNumber;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<DrawingStroke> strokes;
  final List<DrawingText> texts;
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
    this.texts = const [],
    this.contentType = PageContentType.placeholder,
    this.contentPath,
    this.pdfPageIndex,
    this.extraData,
    this.backgroundColor = Colors.white,
    this.aspectRatio,
  });

  PresentationPage copyWith({
    List<DrawingStroke>? strokes,
    List<DrawingText>? texts,
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
      texts: texts ?? this.texts,
      contentType: contentType ?? this.contentType,
      contentPath: contentPath ?? this.contentPath,
      pdfPageIndex: pdfPageIndex ?? this.pdfPageIndex,
      extraData: extraData ?? this.extraData,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }
}
