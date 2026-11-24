import 'dart:math' as math;
import 'package:flutter/material.dart';

enum DrawingTool {
  pen,
  highlighter,
  eraser,
  selector,
  hand,
  text,
  shape,
  handwriting,
  laserPointer,
}

enum ShapeType {
  rectangle,
  circle,
  triangle,
  diamond,
  star,
  line,
  arrow,
  coordinateAxes,
  cube,
}

enum LaserMode {
  laserDot,
  spotlight,
}

enum HandwritingLanguage {
  english,
  bangla,
}

enum DusterType {
  feltBlock,  // Classic 2:1 rectangular wooden/felt duster
  sponge,     // Soft rounded microfiber sponge
  handDuster, // Open hand palm duster
  precision,  // Precision circular tip eraser
}

enum DusterOrientation {
  rightHand,  // 15° Ergonomic right-hand holding grip (default)
  horizontal, // 0° Flat horizontal
  leftHand,   // -15° Ergonomic left-hand holding grip
  vertical,   // 90° Vertical column
  auto,       // Dynamic motion direction with high-pass filtering
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
  final DusterType dusterType;
  final double strokeAngle;
  final bool isLocked;
  final ShapeType? shapeType;
  final Color? fillColor;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
    this.dusterType = DusterType.feltBlock,
    this.strokeAngle = 0.0,
    this.isLocked = false,
    this.shapeType,
    this.fillColor,
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
    // Note: points are normalized (0-1).
    return Rect.fromLTRB(left, top, right, bottom);
  }

  DrawingStroke translate(Offset delta) {
    if (isLocked) return this;
    return DrawingStroke(
      points: points.map((p) => p + delta).toList(),
      color: color,
      width: width,
      tool: tool,
      dusterType: dusterType,
      strokeAngle: strokeAngle,
      isLocked: isLocked,
      shapeType: shapeType,
      fillColor: fillColor,
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
      dusterType: dusterType,
      strokeAngle: strokeAngle,
      isLocked: isLocked,
      shapeType: shapeType,
      fillColor: fillColor,
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
      dusterType: dusterType,
      strokeAngle: strokeAngle + angle,
      isLocked: isLocked,
      shapeType: shapeType,
      fillColor: fillColor,
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
      dusterType: dusterType,
      strokeAngle: -strokeAngle,
      isLocked: isLocked,
      shapeType: shapeType,
      fillColor: fillColor,
    );
  }

  DrawingStroke copyWith({
    List<Offset>? points,
    Color? color,
    double? width,
    DrawingTool? tool,
    DusterType? dusterType,
    double? strokeAngle,
    bool? isLocked,
    ShapeType? shapeType,
    Color? fillColor,
  }) {
    return DrawingStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      tool: tool ?? this.tool,
      dusterType: dusterType ?? this.dusterType,
      strokeAngle: strokeAngle ?? this.strokeAngle,
      isLocked: isLocked ?? this.isLocked,
      shapeType: shapeType ?? this.shapeType,
      fillColor: fillColor ?? this.fillColor,
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

  DrawingText flip(bool horizontal, Offset center) {
    if (isLocked) return this;
    double dx = horizontal ? center.dx - (position.dx - center.dx) : position.dx;
    double dy = horizontal ? position.dy : center.dy - (position.dy - center.dy);
    return copyWith(position: Offset(dx, dy));
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
    int? pageNumber,
    String? title,
    String? subtitle,
    IconData? icon,
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
      pageNumber: pageNumber ?? this.pageNumber,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      icon: icon ?? this.icon,
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
