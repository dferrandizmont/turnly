import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;

import '../domain/sketch.dart';

/// The keyword of the PNG chunk that carries the strokes of a drawing
/// (`turnly:sketch`).
const String sketchPngKeyword = 'turnly:sketch';

/// Most bytes the `tEXt` chunk of a drawing may have. The strokes of a
/// drawing at its limits (`maxSketchPoints` points) are far below this; a
/// bigger chunk is not one of ours (or an attempt to make the app parse
/// megabytes of JSON).
const int maxSketchTextBytes = 1024 * 1024;

/// The PNG of a drawing, with its strokes inside it.
///
/// The file the app stores as an attachment of a day is this PNG: the image is
/// what the user sees (and what travels in the backup), and the strokes (in a
/// `tEXt` chunk) are what lets the drawing be reopened and edited after a
/// restore. The PNG is written by hand (no new dependency): `IHDR` + `tEXt` +
/// `IDAT` + `IEND`, 8 bits per channel, RGBA, no interlacing.
///
/// The canvas keeps its size and the strokes their colours, so the image is
/// the drawing and not a thumbnail of it.
class SketchPng {
  const SketchPng._();

  static const List<int> _signature = [137, 80, 78, 71, 13, 10, 26, 10];

  /// The PNG of [sketch]: the drawing and its strokes.
  static Uint8List encode(Sketch sketch) {
    final problem = sketch.problem;
    if (problem != null) {
      throw ArgumentError.value(sketch, 'sketch', problem);
    }
    final out = BytesBuilder(copy: false);
    out.add(_signature);
    out.add(_chunk('IHDR', _header(sketch.width, sketch.height)));
    out.add(
      _chunk('tEXt', [
        ...ascii.encode(sketchPngKeyword),
        0,
        ...ascii.encode(sketch.toJsonText()),
      ]),
    );
    out.add(_chunk('IDAT', ZLibCodec(level: 6).encode(_scanlines(sketch))));
    out.add(_chunk('IEND', const []));
    return out.toBytes();
  }

  /// The strokes of the drawing in a PNG, or `null` when the file is not a PNG
  /// of this app (a photo, a file, a drawing from another app), when its
  /// `tEXt` chunk is over [maxSketchTextBytes], or when the drawing it holds
  /// is over the limits of a drawing (`Sketch.problem`). Never throws: the
  /// file may be anything. The limits are checked **while** the strokes are
  /// read (`Sketch.fromJson`), so a hostile file cannot make the app build
  /// millions of points first.
  static Sketch? decode(Uint8List bytes) {
    final text = _textChunk(bytes);
    if (text == null) return null;
    try {
      final sketch = Sketch.fromJsonText(text);
      return sketch.problem == null ? sketch : null;
    } on FormatException {
      return null;
    } catch (_) {
      // Anything else the content could provoke (it is untrusted).
      return null;
    }
  }

  /// Whether [bytes] is a PNG at all (the eight bytes every PNG starts with).
  static bool looksLikePng(Uint8List bytes) {
    if (bytes.length < _signature.length) return false;
    for (var i = 0; i < _signature.length; i++) {
      if (bytes[i] != _signature[i]) return false;
    }
    return true;
  }

  // ---- the file ----------------------------------------------------------

  static Uint8List _header(int width, int height) {
    final data = ByteData(13);
    data.setUint32(0, width, Endian.big);
    data.setUint32(4, height, Endian.big);
    data.setUint8(8, 8); // bits per channel
    data.setUint8(9, 6); // RGBA
    data.setUint8(10, 0); // deflate
    data.setUint8(11, 0); // the standard filter
    data.setUint8(12, 0); // no interlacing
    return data.buffer.asUint8List();
  }

  /// The pixels of the drawing, row by row, each one preceded by its filter
  /// byte (0: none).
  static Uint8List _scanlines(Sketch sketch) {
    final pixels = _raster(sketch);
    final width = sketch.width;
    final stride = width * 4;
    final out = Uint8List((stride + 1) * sketch.height);
    for (var y = 0; y < sketch.height; y++) {
      final target = y * (stride + 1);
      out[target] = 0;
      out.setRange(target + 1, target + 1 + stride, pixels, y * stride);
    }
    return out;
  }

  static Uint8List _chunk(String type, List<int> data) {
    final out = BytesBuilder(copy: false);
    final length = ByteData(4)..setUint32(0, data.length, Endian.big);
    out.add(length.buffer.asUint8List());
    final typeBytes = ascii.encode(type);
    out.add(typeBytes);
    out.add(data);
    final crc = ByteData(4)
      ..setUint32(0, getCrc32([...typeBytes, ...data]), Endian.big);
    out.add(crc.buffer.asUint8List());
    return out.toBytes();
  }

  /// The text of the `tEXt` chunk with the keyword [sketchPngKeyword], or
  /// `null` when the file has none (or is not a PNG).
  static String? _textChunk(Uint8List bytes) {
    if (!looksLikePng(bytes)) return null;
    var offset = _signature.length;
    while (offset + 8 <= bytes.length) {
      final length = ByteData.sublistView(
        bytes,
        offset,
        offset + 4,
      ).getUint32(0, Endian.big);
      final type = ascii.decode(
        bytes.sublist(offset + 4, offset + 8),
        allowInvalid: true,
      );
      final start = offset + 8;
      final end = start + length;
      if (end + 4 > bytes.length) return null;
      if (type == 'tEXt') {
        // Only chunks that can be ours are looked at, and never a big one.
        if (length > maxSketchTextBytes) return null;
        final data = bytes.sublist(start, end);
        final separator = data.indexOf(0);
        if (separator >= 0) {
          final keyword = ascii.decode(
            data.sublist(0, separator),
            allowInvalid: true,
          );
          if (keyword == sketchPngKeyword) {
            return ascii.decode(
              data.sublist(separator + 1),
              allowInvalid: true,
            );
          }
        }
        // Another keyword: the next chunk may be ours.
      }
      if (type == 'IEND') return null;
      offset = end + 4;
    }
    return null;
  }

  // ---- the drawing -------------------------------------------------------

  /// The pixels of the drawing (RGBA, transparent where nothing was drawn).
  static Uint8List _raster(Sketch sketch) {
    final width = sketch.width;
    final height = sketch.height;
    final pixels = Uint8List(width * height * 4);
    for (final stroke in sketch.strokes) {
      if (stroke.points.isEmpty) continue;
      final radius = stroke.width / 2;
      final color = _colorOf(stroke.colorValue);
      if (stroke.points.length == 1) {
        _disc(pixels, width, height, stroke.points.first, radius, color);
        continue;
      }
      for (var i = 0; i < stroke.points.length - 1; i++) {
        _line(
          pixels,
          width,
          height,
          stroke.points[i],
          stroke.points[i + 1],
          radius,
          color,
        );
      }
    }
    return pixels;
  }

  /// The colour of a stroke as `(a, r, g, b)`.
  static (int, int, int, int) _colorOf(int argb) {
    final a = (argb >> 24) & 0xFF;
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return (a, r, g, b);
  }

  /// Draws the line between two points, stamping a disc of [radius] along it.
  static void _line(
    Uint8List pixels,
    int width,
    int height,
    SketchPoint from,
    SketchPoint to,
    double radius,
    (int, int, int, int) color,
  ) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final distance = _distance(dx, dy);
    final steps = (distance / 0.5).ceil().clamp(1, 100000);
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      _disc(
        pixels,
        width,
        height,
        SketchPoint(from.x + dx * t, from.y + dy * t),
        radius,
        color,
      );
    }
  }

  static double _distance(double dx, double dy) {
    final squared = dx * dx + dy * dy;
    if (squared <= 0) return 0;
    return math.sqrt(squared);
  }

  /// Paints a disc of [radius] centred at [centre], over what is already
  /// there (the source colour goes on top of it).
  static void _disc(
    Uint8List pixels,
    int width,
    int height,
    SketchPoint centre,
    double radius,
    (int, int, int, int) color,
  ) {
    final r = radius < 0.5 ? 0.5 : radius;
    final minX = (centre.x - r).floor().clamp(0, width - 1);
    final maxX = (centre.x + r).ceil().clamp(0, width - 1);
    final minY = (centre.y - r).floor().clamp(0, height - 1);
    final maxY = (centre.y + r).ceil().clamp(0, height - 1);
    final squared = r * r;
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final dx = x + 0.5 - centre.x;
        final dy = y + 0.5 - centre.y;
        if (dx * dx + dy * dy > squared) continue;
        _blend(pixels, (y * width + x) * 4, color);
      }
    }
  }

  /// Puts the source colour over what is at [offset] (the usual "source over").
  static void _blend(Uint8List pixels, int offset, (int, int, int, int) color) {
    final (sa, sr, sg, sb) = color;
    if (sa == 0) return;
    if (sa == 255) {
      pixels[offset] = sr;
      pixels[offset + 1] = sg;
      pixels[offset + 2] = sb;
      pixels[offset + 3] = 255;
      return;
    }
    final da = pixels[offset + 3];
    final outA = sa + da * (255 - sa) ~/ 255;
    if (outA == 0) {
      pixels[offset] = 0;
      pixels[offset + 1] = 0;
      pixels[offset + 2] = 0;
      pixels[offset + 3] = 0;
      return;
    }
    int mix(int s, int d) => (s * sa + d * da * (255 - sa) ~/ 255) ~/ outA;
    pixels[offset] = mix(sr, pixels[offset]);
    pixels[offset + 1] = mix(sg, pixels[offset + 1]);
    pixels[offset + 2] = mix(sb, pixels[offset + 2]);
    pixels[offset + 3] = outA;
  }
}
