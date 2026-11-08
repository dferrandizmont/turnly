import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../features/schedule/domain/schedule_domain.dart';
import '../l10n/l10n.dart';
import '../theme/theme_context.dart';

/// What an empty screen is waiting for (`docs/diseno.md`, «Estados vacíos»).
enum EmptyIllustrationKind {
  /// Shifts to come (agenda): three shift discs on an arc and a dashed «+».
  shifts,

  /// A backup: two day cells in a card, a dashed path and a check.
  backup,

  /// Days with shifts (summary, rotations, shift types): three day cells
  /// with their bar and a dashed empty one.
  calendar,
}

/// The drawing of an empty state (design 8.1B): made with the same shift
/// discs and day cells as the month, in the colours of the user's own
/// shifts, so it follows the theme and the palette by itself. Each disc and
/// cell carries its code too: never colour alone.
///
/// Decorative: hidden from screen readers (the title of the empty state says
/// it all). It does not grow with the text size; the text under it does.
class EmptyIllustration extends StatelessWidget {
  const EmptyIllustration({
    super.key,
    this.kind = EmptyIllustrationKind.shifts,
    this.shifts = const [],
    this.width = defaultWidth,
  });

  final EmptyIllustrationKind kind;

  /// The user's shift types; the first three with a colour of their own are
  /// drawn. Missing ones are filled with the starting Mañana, Tarde and Noche.
  final List<ShiftType> shifts;

  final double width;

  /// Width of the drawing; its height keeps the [_box] proportions.
  static const double defaultWidth = 200;

  /// The drawing is laid out on a 200 x 124 box and scaled to [width].
  static const Size _box = Size(200, 124);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final brightness = colors.brightness;
    final l10n = context.l10n;
    final fallback = [
      (l10n.catalogShiftMorningCode, ShiftPalette.morning.toARGB32()),
      (l10n.catalogShiftAfternoonCode, ShiftPalette.afternoon.toARGB32()),
      (l10n.catalogShiftNightCode, ShiftPalette.night.toARGB32()),
    ];
    final own = [
      for (final s in shifts)
        if (!ShiftPalette.isRest(s.colorValue) && s.code.isNotEmpty)
          (s.code, s.colorValue),
    ];
    final picked = [...own.take(3), ...fallback.skip(own.take(3).length)];
    final chips = [
      for (final (code, color) in picked)
        _Chip(code, ShiftSwatch.forColor(color, brightness)),
    ];

    final scale = width / _box.width;
    final layout = switch (kind) {
      EmptyIllustrationKind.shifts => _shiftsLayout(chips),
      EmptyIllustrationKind.backup => _backupLayout(chips),
      EmptyIllustrationKind.calendar => _calendarLayout(chips),
    };

    return ExcludeSemantics(
      child: SizedBox(
        key: ValueKey('empty-illustration-${kind.name}'),
        width: width,
        height: _box.height * scale,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _IllustrationPainter(
                  shapes: layout.shapes,
                  scale: scale,
                  colors: colors,
                ),
              ),
            ),
            for (final label in layout.labels)
              Positioned.fromRect(
                rect: Rect.fromCenter(
                  center: label.center * scale,
                  width: label.size * scale,
                  height: label.size * scale,
                ),
                child: FittedBox(
                  child: Text(
                    label.code,
                    maxLines: 1,
                    textScaler: TextScaler.noScaling,
                    style: context.type.title.copyWith(
                      color: label.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Three discs on a dashed arc and a dashed «+» under the middle one.
  static _Layout _shiftsLayout(List<_Chip> c) => _Layout(
    shapes: [
      _Shape.dashedCurve(
        const Offset(30, 96),
        const Offset(60, 40),
        const Offset(140, 40),
        const Offset(170, 96),
        tone: _Tone.borderStrong,
        stroke: 2.5,
        dash: 3,
        gap: 7,
      ),
      _Shape.disc(const Offset(40, 78), 22, c[0].swatch.disc),
      _Shape.disc(const Offset(100, 46), 26, c[1].swatch.disc),
      _Shape.disc(const Offset(160, 78), 22, c[2].swatch.disc),
      _Shape.dashedCircle(const Offset(100, 106), 11),
      _Shape.plus(const Offset(100, 106), 5),
    ],
    labels: [
      _Label(c[0].code, const Offset(40, 78), 28, c[0].swatch.ink),
      _Label(c[1].code, const Offset(100, 46), 32, c[1].swatch.ink),
      _Label(c[2].code, const Offset(160, 78), 28, c[2].swatch.ink),
    ],
  );

  /// Two day cells in a card, a dashed path and the check of a copy.
  static _Layout _backupLayout(List<_Chip> c) => _Layout(
    shapes: [
      _Shape.card(const Rect.fromLTWH(14, 26, 104, 76), 18),
      ..._cell(const Rect.fromLTWH(28, 42, 34, 44), c[2].swatch),
      ..._cell(const Rect.fromLTWH(70, 42, 34, 44), c[0].swatch),
      _Shape.dashedCurve(
        const Offset(126, 64),
        const Offset(138, 44),
        const Offset(150, 44),
        const Offset(156, 50),
        tone: _Tone.accent,
        stroke: 3,
        dash: 2,
        gap: 7,
      ),
      _Shape.check(const Offset(170, 64), 20),
    ],
    labels: [
      _Label(c[2].code, const Offset(45, 61), 24, c[2].swatch.ink),
      _Label(c[0].code, const Offset(87, 61), 24, c[0].swatch.ink),
    ],
  );

  /// Three day cells with their bars and a dashed empty one.
  static _Layout _calendarLayout(List<_Chip> c) => _Layout(
    shapes: [
      ..._cell(const Rect.fromLTWH(16, 38, 36, 50), c[0].swatch),
      ..._cell(const Rect.fromLTWH(60, 38, 36, 50), c[1].swatch),
      ..._cell(const Rect.fromLTWH(104, 38, 36, 50), c[2].swatch),
      _Shape.dashedBox(const Rect.fromLTWH(148, 38, 36, 50), 9),
      _Shape.plus(const Offset(166, 63), 5),
    ],
    labels: [
      _Label(c[0].code, const Offset(34, 59), 24, c[0].swatch.ink),
      _Label(c[1].code, const Offset(78, 59), 24, c[1].swatch.ink),
      _Label(c[2].code, const Offset(122, 59), 24, c[2].swatch.ink),
    ],
  );

  /// A day cell: its tint and, at the bottom, its bar.
  static List<_Shape> _cell(Rect r, ShiftSwatch s) => [
    _Shape.box(r, 9, s.tint),
    _Shape.bar(Rect.fromLTWH(r.left, r.bottom - 5, r.width, 5), r, 9, s.bar),
  ];
}

class _Chip {
  const _Chip(this.code, this.swatch);

  final String code;
  final ShiftSwatch swatch;
}

class _Label {
  const _Label(this.code, this.center, this.size, this.ink);

  final String code;
  final Offset center;
  final double size;
  final Color ink;
}

class _Layout {
  const _Layout({required this.shapes, required this.labels});

  final List<_Shape> shapes;
  final List<_Label> labels;
}

/// Theme colours a stroke can take (resolved at paint time).
enum _Tone { borderStrong, textMuted, accent }

enum _ShapeKind {
  disc,
  box,
  bar,
  card,
  dashedCurve,
  dashedCircle,
  dashedBox,
  plus,
  check,
}

/// One element of the drawing, in the coordinates of the 200 x 124 box.
class _Shape {
  const _Shape._(
    this.kind, {
    this.points = const [],
    this.rect = Rect.zero,
    this.clip = Rect.zero,
    this.radius = 0,
    this.fill,
    this.tone = _Tone.borderStrong,
    this.stroke = 2,
    this.dash = 3,
    this.gap = 4,
  });

  factory _Shape.disc(Offset c, double r, Color fill) => _Shape._(
    _ShapeKind.disc,
    rect: Rect.fromCircle(center: c, radius: r),
    fill: fill,
  );

  factory _Shape.box(Rect r, double radius, Color fill) =>
      _Shape._(_ShapeKind.box, rect: r, radius: radius, fill: fill);

  /// [r] clipped to the rounded [clip] (the bar of a cell).
  factory _Shape.bar(Rect r, Rect clip, double radius, Color fill) =>
      _Shape._(_ShapeKind.bar, rect: r, clip: clip, radius: radius, fill: fill);

  factory _Shape.card(Rect r, double radius) =>
      _Shape._(_ShapeKind.card, rect: r, radius: radius, stroke: 2.5);

  factory _Shape.dashedCurve(
    Offset a,
    Offset b,
    Offset c,
    Offset d, {
    required _Tone tone,
    required double stroke,
    required double dash,
    required double gap,
  }) => _Shape._(
    _ShapeKind.dashedCurve,
    points: [a, b, c, d],
    tone: tone,
    stroke: stroke,
    dash: dash,
    gap: gap,
  );

  factory _Shape.dashedCircle(Offset c, double r) => _Shape._(
    _ShapeKind.dashedCircle,
    rect: Rect.fromCircle(center: c, radius: r),
  );

  factory _Shape.dashedBox(Rect r, double radius) => _Shape._(
    _ShapeKind.dashedBox,
    rect: r,
    radius: radius,
    stroke: 2.5,
    dash: 4,
    gap: 4,
  );

  factory _Shape.plus(Offset c, double half) => _Shape._(
    _ShapeKind.plus,
    rect: Rect.fromCircle(center: c, radius: half),
    tone: _Tone.textMuted,
  );

  factory _Shape.check(Offset c, double r) => _Shape._(
    _ShapeKind.check,
    rect: Rect.fromCircle(center: c, radius: r),
    tone: _Tone.accent,
    stroke: 3.2,
  );

  final _ShapeKind kind;
  final List<Offset> points;
  final Rect rect;
  final Rect clip;
  final double radius;
  final Color? fill;
  final _Tone tone;
  final double stroke;
  final double dash;
  final double gap;
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter({
    required this.shapes,
    required this.scale,
    required this.colors,
  });

  final List<_Shape> shapes;
  final double scale;
  final AppColors colors;

  Color _tone(_Tone tone) => switch (tone) {
    _Tone.borderStrong => colors.borderStrong,
    _Tone.textMuted => colors.textMuted,
    _Tone.accent => colors.accent,
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(scale);
    for (final s in shapes) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _tone(s.tone);
      switch (s.kind) {
        case _ShapeKind.disc:
          canvas.drawRRect(_square(s.rect), Paint()..color = s.fill!);
        case _ShapeKind.box:
          canvas.drawRRect(
            RRect.fromRectAndRadius(s.rect, Radius.circular(s.radius)),
            Paint()..color = s.fill!,
          );
        case _ShapeKind.bar:
          canvas.save();
          canvas.clipRRect(
            RRect.fromRectAndRadius(s.clip, Radius.circular(s.radius)),
          );
          canvas.drawRect(s.rect, Paint()..color = s.fill!);
          canvas.restore();
        case _ShapeKind.card:
          final r = RRect.fromRectAndRadius(s.rect, Radius.circular(s.radius));
          canvas.drawRRect(r, Paint()..color = colors.surface);
          canvas.drawRRect(r, stroke..color = colors.borderStrong);
        case _ShapeKind.dashedCurve:
          final p = s.points;
          final path = Path()
            ..moveTo(p[0].dx, p[0].dy)
            ..cubicTo(p[1].dx, p[1].dy, p[2].dx, p[2].dy, p[3].dx, p[3].dy);
          _dashed(canvas, path, stroke, s.dash, s.gap);
        case _ShapeKind.dashedCircle:
          _dashed(
            canvas,
            Path()..addRRect(_square(s.rect)),
            stroke..strokeWidth = 2,
            s.dash,
            s.gap,
          );
        case _ShapeKind.dashedBox:
          _dashed(
            canvas,
            Path()..addRRect(
              RRect.fromRectAndRadius(s.rect, Radius.circular(s.radius)),
            ),
            stroke,
            s.dash,
            s.gap,
          );
        case _ShapeKind.plus:
          final c = s.rect.center;
          final h = s.rect.width / 2;
          canvas.drawLine(c.translate(0, -h), c.translate(0, h), stroke);
          canvas.drawLine(c.translate(-h, 0), c.translate(h, 0), stroke);
        case _ShapeKind.check:
          canvas.drawRRect(_square(s.rect), Paint()..color = colors.accentSoft);
          final c = s.rect.center;
          final path = Path()
            ..moveTo(c.dx - 9, c.dy)
            ..lineTo(c.dx - 3, c.dy + 6)
            ..lineTo(c.dx + 8, c.dy - 5);
          canvas.drawPath(path, stroke);
      }
    }
  }

  /// A square piece of the drawing: a rounded square, never a circle
  /// (`docs/diseno.md`).
  static RRect _square(Rect r) =>
      RRect.fromRectAndRadius(r, Radius.circular(Rad.square(r.width)));

  static void _dashed(
    Canvas canvas,
    Path path,
    Paint paint,
    double dash,
    double gap,
  ) {
    for (final PathMetric metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_IllustrationPainter old) =>
      old.scale != scale || old.colors != colors || old.shapes != shapes;
}
