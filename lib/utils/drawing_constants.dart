import 'package:flutter/material.dart';

class DrawingConstants {
  static const double highResMultiplier = 3.0;
  static const double minStrokeWidth = 1.0;
  static const double maxStrokeWidth = 20.0;
  static const double defaultStrokeWidth = 4.0;

  static const List<Color> defaultColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.black,
    Colors.white,
  ];

  static const Map<String, DrawingToolType> tools = {
    'pen': DrawingToolType.pen,
    'highlighter': DrawingToolType.highlighter,
    'eraser': DrawingToolType.eraser,
  };
}

enum DrawingToolType {
  pen,
  highlighter,
  eraser,
}