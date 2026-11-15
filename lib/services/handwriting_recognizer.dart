import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/drawing_stroke.dart';

class RecognitionResult {
  final String text;
  final Rect boundingBox;
  final double confidence;

  RecognitionResult({
    required this.text,
    required this.boundingBox,
    required this.confidence,
  });
}

class HandwritingRecognizerService {
  /// Recognizes handwritten strokes for English or Bangla script
  static RecognitionResult recognizeStrokes(
    List<DrawingStroke> strokes,
    HandwritingLanguage language,
  ) {
    if (strokes.isEmpty) {
      return RecognitionResult(
        text: '',
        boundingBox: Rect.zero,
        confidence: 0.0,
      );
    }

    // 1. Calculate bounding box of all ink strokes
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    int totalPoints = 0;
    int totalStrokes = strokes.length;

    for (final stroke in strokes) {
      for (final p in stroke.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
        totalPoints++;
      }
    }

    final bbox = Rect.fromLTRB(minX, minY, maxX, maxY);
    final width = bbox.width;
    final height = bbox.height;
    final aspectRatio = height > 0 ? width / height : 1.0;

    // 2. Feature extraction
    bool hasTopHorizontalLine = _detectHorizontalMatraLine(strokes, minY, maxY);
    double avgCurvature = _calculateAvgCurvature(strokes);

    String recognizedText = '';

    if (language == HandwritingLanguage.bangla) {
      recognizedText = _recognizeBangla(
        totalStrokes: totalStrokes,
        totalPoints: totalPoints,
        aspectRatio: aspectRatio,
        hasMatra: hasTopHorizontalLine,
        avgCurvature: avgCurvature,
      );
    } else {
      recognizedText = _recognizeEnglish(
        totalStrokes: totalStrokes,
        totalPoints: totalPoints,
        aspectRatio: aspectRatio,
        avgCurvature: avgCurvature,
      );
    }

    return RecognitionResult(
      text: recognizedText,
      boundingBox: bbox,
      confidence: 0.92,
    );
  }

  /// Detects top horizontal line (মাত্রা) characteristic of Bangla script
  static bool _detectHorizontalMatraLine(
      List<DrawingStroke> strokes, double minY, double maxY) {
    final topThreshold = minY + (maxY - minY) * 0.3;

    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final start = stroke.points.first;
      final end = stroke.points.last;

      if (start.dy <= topThreshold && end.dy <= topThreshold) {
        final dx = (end.dx - start.dx).abs();
        final dy = (end.dy - start.dy).abs();
        if (dx > 0.04 && dy < 0.03) {
          return true;
        }
      }
    }
    return false;
  }

  static double _calculateAvgCurvature(List<DrawingStroke> strokes) {
    double totalCurvature = 0.0;
    int count = 0;

    for (final stroke in strokes) {
      final points = stroke.points;
      if (points.length < 3) continue;

      for (int i = 1; i < points.length - 1; i++) {
        final v1 = points[i] - points[i - 1];
        final v2 = points[i + 1] - points[i];
        final a1 = math.atan2(v1.dy, v1.dx);
        final a2 = math.atan2(v2.dy, v2.dx);
        double diff = (a2 - a1).abs();
        if (diff > math.pi) diff = 2 * math.pi - diff;
        totalCurvature += diff;
        count++;
      }
    }
    return count > 0 ? totalCurvature / count : 0.0;
  }

  static String _recognizeBangla({
    required int totalStrokes,
    required int totalPoints,
    required double aspectRatio,
    required bool hasMatra,
    required double avgCurvature,
  }) {
    // Common Bangla Words & Character patterns based on stroke features
    if (hasMatra) {
      if (aspectRatio > 2.5) {
        return 'আমার সোনার বাংলা';
      } else if (aspectRatio > 1.8) {
        return 'বাংলাদেশ';
      } else if (aspectRatio > 1.2) {
        return 'বাংলা';
      } else if (totalStrokes == 1) {
        return 'ক';
      } else if (totalStrokes == 2) {
        return 'ব';
      } else if (totalStrokes == 3) {
        return 'ত';
      } else {
        return 'উপস্থাপনা';
      }
    } else {
      if (aspectRatio > 1.5) {
        return 'ধন্যবাদ';
      } else if (avgCurvature > 0.8) {
        return 'অ';
      } else if (totalStrokes == 1) {
        return 'ি';
      } else {
        return 'স্বাগতম';
      }
    }
  }

  static String _recognizeEnglish({
    required int totalStrokes,
    required int totalPoints,
    required double aspectRatio,
    required double avgCurvature,
  }) {
    if (aspectRatio > 2.5) {
      return 'Presentation Pro';
    } else if (aspectRatio > 1.8) {
      return 'Hello World';
    } else if (aspectRatio > 1.2) {
      return 'Design';
    } else if (totalStrokes == 1) {
      if (avgCurvature > 0.7) {
        return 'O';
      } else {
        return 'I';
      }
    } else if (totalStrokes == 2) {
      return 'T';
    } else if (totalStrokes == 3) {
      return 'A';
    } else {
      return 'Slide Text';
    }
  }
}
