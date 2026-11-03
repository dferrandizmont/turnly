import 'dart:convert';

/// Most strokes a drawing may have.
const int maxSketchStrokes = 2000;

/// Most points one stroke may have.
const int maxSketchPointsPerStroke = 2000;

/// Most points a drawing may have (all its strokes together).
const int maxSketchPoints = 20000;

/// Biggest side (in points) of the canvas of a drawing.
const int maxSketchDimension = 2048;

/// Most pixels a drawing may have (the canvas is square-ish: 2048 x 2048 is
/// 4 MiB of RGBA, which the PNG of a drawing must not exceed).
const int maxSketchPixels = 4 * 1024 * 1024;

/// Biggest thickness of a stroke, in points.
const double maxSketchStrokeWidth = 64;

/// The version of the strokes format ([Sketch.toJson]).
const int sketchFormatVersion = 1;

/// One point of a stroke, in the canvas of the drawing (pixels from its top
/// left corner).
class SketchPoint {
  const SketchPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is SketchPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'SketchPoint($x, $y)';
}

/// A continuous line of a drawing: its points, its colour (ARGB) and its
/// thickness, in points.
class SketchStroke {
  const SketchStroke({
    required this.points,
    this.colorValue = 0xFF111111,
    this.width = 4,
  });

  /// The points of the line, in order. One point is a dot.
  final List<SketchPoint> points;

  /// The colour of the line, as ARGB (opaque black by default).
  final int colorValue;

  /// The thickness of the line, in points.
  final double width;

  @override
  bool operator ==(Object other) =>
      other is SketchStroke &&
      other.colorValue == colorValue &&
      other.width == width &&
      _samePoints(other.points, points);

  @override
  int get hashCode => Object.hash(colorValue, width, Object.hashAll(points));

  @override
  String toString() => 'SketchStroke(${points.length} points, $colorValue)';
}

bool _samePoints(List<SketchPoint> a, List<SketchPoint> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A drawing made in the app: the canvas and its strokes.
///
/// The strokes are the source of truth and travel as **compact JSON**
/// ([toJson]): `{"v":1,"w":1000,"h":1000,"s":[{"c":4278190080,"w":4,
/// "p":[10.5,20,11,22]}]}` (the points of a stroke are a flat list of
/// coordinates, in pairs). The PNG of the drawing (the file the app stores as
/// an attachment) carries these same strokes inside it, so a drawing can be
/// reopened and edited after a restore (`data/sketch_png.dart`).
class Sketch {
  const Sketch({
    this.width = 1000,
    this.height = 1000,
    this.strokes = const [],
  });

  /// The width of the canvas, in points.
  final int width;

  /// The height of the canvas, in points.
  final int height;

  /// The strokes, in the order they were drawn.
  final List<SketchStroke> strokes;

  /// How many points the drawing has, all its strokes together.
  int get pointCount =>
      strokes.fold(0, (sum, stroke) => sum + stroke.points.length);

  /// Why this drawing cannot be stored, or `null` when it is valid.
  String? get problem {
    if (width < 1 || width > maxSketchDimension) return 'canvas too wide';
    if (height < 1 || height > maxSketchDimension) return 'canvas too tall';
    if (width * height > maxSketchPixels) return 'canvas too big';
    if (strokes.length > maxSketchStrokes) return 'too many strokes';
    if (pointCount > maxSketchPoints) return 'too many points';
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) return 'stroke without points';
      if (stroke.points.length > maxSketchPointsPerStroke) {
        return 'stroke with too many points';
      }
      if (!stroke.width.isFinite ||
          stroke.width <= 0 ||
          stroke.width > maxSketchStrokeWidth) {
        return 'invalid stroke width';
      }
      if (stroke.colorValue < 0 || stroke.colorValue > 0xFFFFFFFF) {
        return 'invalid stroke colour';
      }
      for (final point in stroke.points) {
        if (!point.x.isFinite || !point.y.isFinite) {
          return 'point outside the canvas';
        }
        if (point.x < 0 || point.y < 0 || point.x > width || point.y > height) {
          return 'point outside the canvas';
        }
      }
    }
    return null;
  }

  /// The compact JSON of the drawing. The keys are short because this text
  /// travels inside the PNG of the drawing.
  Map<String, Object?> toJson() => {
    'v': sketchFormatVersion,
    'w': width,
    'h': height,
    's': [
      for (final stroke in strokes)
        {
          'c': stroke.colorValue,
          'w': stroke.width,
          'p': [
            for (final point in stroke.points) ...[point.x, point.y],
          ],
        },
    ],
  };

  /// The compact JSON as text (what the PNG carries).
  String toJsonText() => jsonEncode(toJson());

  /// Reads a drawing from its compact JSON. Throws [FormatException] when the
  /// text is not a drawing this build understands (a file from the future, a
  /// corrupted one). A key this build does not know is ignored.
  factory Sketch.fromJson(Map<String, Object?> json) {
    final version = json['v'];
    if (version is! int || version < 1 || version > sketchFormatVersion) {
      throw FormatException('Unsupported sketch version', '$version');
    }
    final width = json['w'];
    final height = json['h'];
    if (width is! int || height is! int) {
      throw const FormatException('A sketch needs its canvas size');
    }
    // The limits of a drawing are enforced while it is read, before anything
    // is built from the content: the text is untrusted.
    if (width < 1 ||
        height < 1 ||
        width > maxSketchDimension ||
        height > maxSketchDimension ||
        width * height > maxSketchPixels) {
      throw const FormatException('The canvas of a sketch is out of range');
    }
    final rawStrokes = json['s'];
    if (rawStrokes is! List) {
      throw const FormatException('A sketch needs its strokes');
    }
    if (rawStrokes.length > maxSketchStrokes) {
      throw const FormatException('A sketch has too many strokes');
    }
    var totalPoints = 0;
    final strokes = <SketchStroke>[];
    for (final raw in rawStrokes) {
      if (raw is! Map<String, Object?>) {
        throw const FormatException('A stroke is not an object');
      }
      final color = raw['c'];
      if (color is! int) {
        throw const FormatException('A stroke needs its colour');
      }
      final strokeWidth = raw['w'];
      if (strokeWidth is! num) {
        throw const FormatException('A stroke needs its width');
      }
      final rawPoints = raw['p'];
      if (rawPoints is! List) {
        throw const FormatException('A stroke needs its points');
      }
      if (rawPoints.length.isOdd) {
        throw const FormatException('A stroke has an odd number of values');
      }
      final pointsInStroke = rawPoints.length ~/ 2;
      totalPoints += pointsInStroke;
      if (pointsInStroke > maxSketchPointsPerStroke ||
          totalPoints > maxSketchPoints) {
        throw const FormatException('A sketch has too many points');
      }
      final points = <SketchPoint>[];
      for (var i = 0; i < rawPoints.length; i += 2) {
        final x = rawPoints[i];
        final y = rawPoints[i + 1];
        if (x is! num || y is! num) {
          throw const FormatException('A point is not a number');
        }
        points.add(SketchPoint(x.toDouble(), y.toDouble()));
      }
      strokes.add(
        SketchStroke(
          points: points,
          colorValue: color,
          width: strokeWidth.toDouble(),
        ),
      );
    }
    return Sketch(width: width, height: height, strokes: strokes);
  }

  /// Reads a drawing from its compact JSON text. Throws [FormatException].
  factory Sketch.fromJsonText(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('A sketch is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('A sketch is not an object');
    }
    return Sketch.fromJson(decoded);
  }

  @override
  bool operator ==(Object other) =>
      other is Sketch &&
      other.width == width &&
      other.height == height &&
      _sameStrokes(other.strokes, strokes);

  @override
  int get hashCode => Object.hash(width, height, Object.hashAll(strokes));

  @override
  String toString() => 'Sketch(${width}x$height, ${strokes.length} strokes)';
}

bool _sameStrokes(List<SketchStroke> a, List<SketchStroke> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
