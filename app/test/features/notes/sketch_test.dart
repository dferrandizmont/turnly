import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:cuadrante/features/notes/data/sketch_png.dart';
import 'package:cuadrante/features/notes/domain/sketch.dart';
import 'package:flutter_test/flutter_test.dart';

Sketch _sketch() => Sketch(
  width: 200,
  height: 100,
  strokes: [
    SketchStroke(
      points: const [SketchPoint(0, 0), SketchPoint(10, 20)],
      colorValue: 0xFF112233,
      width: 3,
    ),
    SketchStroke(points: const [SketchPoint(5, 5)], colorValue: 0xFF000000),
  ],
);

void main() {
  group('the strokes of a drawing', () {
    test('they travel as compact JSON', () {
      final json = _sketch().toJson();
      expect(json['v'], 1);
      expect(json['w'], 200);
      expect(json['h'], 100);
      final strokes = json['s']! as List<Object?>;
      expect(strokes, hasLength(2));
      final first = strokes.first! as Map<String, Object?>;
      expect(first['c'], 0xFF112233);
      expect(first['w'], 3);
      expect(first['p'], [0, 0, 10, 20]);
    });

    test('the JSON of a drawing comes back the same', () {
      final sketch = _sketch();
      final back = Sketch.fromJsonText(sketch.toJsonText());
      expect(back, sketch);
      expect(back.hashCode, sketch.hashCode);
      expect(back.pointCount, 3);
    });

    test('a JSON that is not a drawing is refused', () {
      for (final text in [
        'not json',
        '[]',
        '{"v":2,"w":1,"h":1,"s":[]}',
        '{"v":1,"w":1,"h":1}',
        '{"v":1,"w":1,"h":1,"s":[{"c":1,"w":1,"p":[1]}]}',
        '{"v":1,"w":1,"h":1,"s":[{"c":1,"w":1,"p":["a",1]}]}',
        '{"v":1,"w":"x","h":1,"s":[]}',
      ]) {
        expect(
          () => Sketch.fromJsonText(text),
          throwsA(isA<FormatException>()),
          reason: text,
        );
      }
    });

    test('a drawing that cannot be stored says why', () {
      expect(_sketch().problem, isNull);
      expect(const Sketch(width: 0).problem, 'canvas too wide');
      expect(
        const Sketch(width: maxSketchDimension + 1).problem,
        'canvas too wide',
      );
      expect(
        Sketch(
          strokes: [
            SketchStroke(points: const [SketchPoint(0, 0)]),
          ],
        ).problem,
        isNull,
      );
      expect(
        Sketch(
          strokes: [
            SketchStroke(points: const [SketchPoint(-1, 0)]),
          ],
        ).problem,
        'point outside the canvas',
      );
      expect(
        Sketch(
          strokes: [
            SketchStroke(points: const [SketchPoint(0, 0)], width: 0),
          ],
        ).problem,
        'invalid stroke width',
      );
      expect(
        Sketch(
          strokes: [
            SketchStroke(points: const [SketchPoint(0, 0)], colorValue: -1),
          ],
        ).problem,
        'invalid stroke colour',
      );
      expect(
        Sketch(strokes: [SketchStroke(points: const [])]).problem,
        'stroke without points',
      );
      expect(
        Sketch(
          strokes: [
            for (var i = 0; i < maxSketchStrokes + 1; i++)
              SketchStroke(points: const [SketchPoint(0, 0)]),
          ],
        ).problem,
        'too many strokes',
      );
    });
  });

  group('the PNG of a drawing', () {
    test('it is a PNG that carries the strokes', () {
      final sketch = _sketch();
      final png = SketchPng.encode(sketch);
      expect(SketchPng.looksLikePng(png), isTrue);
      expect(png.sublist(1, 4), utf8.encode('PNG'));
      final back = SketchPng.decode(png);
      expect(back, sketch);
    });

    test('a drawing with no strokes is a PNG too', () {
      final png = SketchPng.encode(const Sketch(width: 10, height: 10));
      expect(SketchPng.looksLikePng(png), isTrue);
      expect(SketchPng.decode(png), const Sketch(width: 10, height: 10));
    });

    test('a file that is not a drawing has no strokes', () {
      expect(SketchPng.decode(Uint8List.fromList([1, 2, 3])), isNull);
      expect(SketchPng.decode(Uint8List(0)), isNull);
      // A PNG without the chunk of the app: nothing to read.
      final png = SketchPng.encode(_sketch());
      final withoutText = Uint8List.fromList(png);
      expect(SketchPng.decode(withoutText), isNotNull);
      expect(
        SketchPng.decode(
          Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]),
        ),
        isNull,
      );
    });

    test('a drawing that cannot be stored is not drawn', () {
      expect(
        () => SketchPng.encode(const Sketch(width: 0)),
        throwsArgumentError,
      );
    });
  });

  group('a drawing from an untrusted file', () {
    /// A PNG made only of the chunks that matter: [text] in a `tEXt` chunk
    /// with the keyword of the app.
    Uint8List pngWith(List<int> text, {String keyword = sketchPngKeyword}) {
      Uint8List chunk(String type, List<int> data) {
        final out = BytesBuilder();
        out.add(
          (ByteData(
            4,
          )..setUint32(0, data.length, Endian.big)).buffer.asUint8List(),
        );
        out.add(ascii.encode(type));
        out.add(data);
        out.add(
          (ByteData(4)..setUint32(
                0,
                getCrc32([...ascii.encode(type), ...data]),
                Endian.big,
              ))
              .buffer
              .asUint8List(),
        );
        return out.toBytes();
      }

      return Uint8List.fromList([
        137, 80, 78, 71, 13, 10, 26, 10, //
        ...chunk('tEXt', [...ascii.encode(keyword), 0, ...text]),
        ...chunk('IEND', const []),
      ]);
    }

    List<int> jsonOf(Map<String, Object?> json) =>
        ascii.encode(jsonEncode(json));

    Map<String, Object?> stroke(int points) => {
      'c': 0xFF000000,
      'w': 2,
      'p': List<num>.filled(points * 2, 1),
    };

    test('a tEXt chunk over 1 MiB is not read', () {
      expect(maxSketchTextBytes, 1024 * 1024);
      // Valid JSON, but padded past the cap with a key nobody reads.
      final padded = jsonOf({
        'v': 1,
        'w': 10,
        'h': 10,
        's': const [],
        'x': 'a' * (maxSketchTextBytes + 1),
      });
      expect(padded.length, greaterThan(maxSketchTextBytes));
      expect(SketchPng.decode(pngWith(padded)), isNull);
      // The same drawing without the padding is read.
      final small = jsonOf({'v': 1, 'w': 10, 'h': 10, 's': const []});
      expect(
        SketchPng.decode(pngWith(small)),
        const Sketch(width: 10, height: 10),
      );
    });

    test('the limits are enforced while the strokes are read', () {
      Map<String, Object?> sketch(List<Object?> strokes, {int w = 100}) => {
        'v': 1,
        'w': w,
        'h': 100,
        's': strokes,
      };
      // Too many strokes: refused before any of them is built.
      expect(
        () => Sketch.fromJson(
          sketch(List.filled(maxSketchStrokes + 1, stroke(1))),
        ),
        throwsFormatException,
      );
      // Too many points in one stroke.
      expect(
        () => Sketch.fromJson(sketch([stroke(maxSketchPointsPerStroke + 1)])),
        throwsFormatException,
      );
      // Too many points in all (each stroke is within its own limit).
      expect(
        () => Sketch.fromJson(
          sketch(
            List.filled(
              maxSketchPoints ~/ maxSketchPointsPerStroke + 1,
              stroke(maxSketchPointsPerStroke),
            ),
          ),
        ),
        throwsFormatException,
      );
      // A canvas out of range.
      expect(
        () => Sketch.fromJson(sketch(const [], w: 5000)),
        throwsFormatException,
      );
      expect(
        () => Sketch.fromJson(sketch(const [], w: 0)),
        throwsFormatException,
      );
      // The limits themselves are fine.
      expect(
        Sketch.fromJson(sketch([stroke(maxSketchPointsPerStroke)])).pointCount,
        maxSketchPointsPerStroke,
      );
      // Through the PNG: the same refusals, as null.
      expect(
        SketchPng.decode(
          pngWith(jsonOf(sketch(List.filled(maxSketchStrokes + 1, stroke(1))))),
        ),
        isNull,
      );
    });

    test('a drawing that is not valid (problem) is not returned', () {
      // A point outside the canvas, a stroke width of 0 and a bad colour all
      // parse as JSON but are not a drawing the app can draw.
      for (final bad in [
        {
          'c': 0xFF000000,
          'w': 2,
          'p': [500, 5],
        },
        {
          'c': 0xFF000000,
          'w': 0,
          'p': [5, 5],
        },
        {
          'c': 0xFF000000,
          'w': 1000,
          'p': [5, 5],
        },
        {
          'c': -1,
          'w': 2,
          'p': [5, 5],
        },
        {'c': 0xFF000000, 'w': 2, 'p': <num>[]},
      ]) {
        final text = jsonOf({
          'v': 1,
          'w': 100,
          'h': 100,
          's': [bad],
        });
        expect(Sketch.fromJsonText(ascii.decode(text)).problem, isNotNull);
        expect(SketchPng.decode(pngWith(text)), isNull, reason: '$bad');
      }
      // A valid one still comes back.
      final good = jsonOf({
        'v': 1,
        'w': 100,
        'h': 100,
        's': [stroke(2)],
      });
      expect(SketchPng.decode(pngWith(good)), isNotNull);
    });

    test('a tEXt chunk of another keyword does not hide ours', () {
      final other = pngWith(ascii.encode('hello'), keyword: 'Comment');
      expect(SketchPng.decode(other), isNull);
    });
  });
}
