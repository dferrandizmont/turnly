import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/content_app_bar.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/notes_providers.dart';
import '../data/attachment_store.dart';
import '../data/sketch_png.dart';
import '../domain/note_attachment.dart';
import '../domain/sketch.dart';

/// «Dibujo» of a day (`/dia/dibujo?fecha=2026-10-19&calendario=main`): the
/// canvas where a drawing is made. It is saved as an attachment of the day
/// (a PNG that carries the strokes inside it, so it can be reopened and
/// edited after a restore).
class SketchScreen extends ConsumerStatefulWidget {
  const SketchScreen({
    super.key,
    required this.date,
    required this.calendarId,
  });

  /// The day the drawing belongs to.
  final CivilDate date;

  /// The calendar the drawing belongs to.
  final String calendarId;

  @override
  ConsumerState<SketchScreen> createState() => _SketchScreenState();
}

/// The tools of the canvas: the pen and the eraser.
enum _Tool { pen, eraser }

class _SketchScreenState extends ConsumerState<SketchScreen> {
  /// The width of the canvas, in points (the height follows the shape of the
  /// screen where the drawing starts).
  static const int _canvasWidth = 1000;

  /// How thick a stroke is, in canvas points.
  static const double _strokeWidth = 12;

  /// How wide the eraser is, in canvas points.
  static const double _eraserWidth = 28;

  final List<SketchStroke> _strokes = [];
  final List<List<SketchStroke>> _past = [];
  final List<List<SketchStroke>> _future = [];

  _Tool _tool = _Tool.pen;

  /// The colour of the pen: the ink of the theme until the person picks
  /// another one.
  int _colorValue = 0;
  int? _canvasHeight;
  List<SketchPoint> _current = const [];

  /// How many points the drawing has, all its strokes together.
  int get _pointCount =>
      _strokes.fold(0, (sum, stroke) => sum + stroke.points.length);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_colorValue == 0) _colorValue = context.colors.textPrimary.toARGB32();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;

    final palette = <(Color, String)>[
      (colors.textPrimary, l10n.sketchColorInk),
      (colors.accent, l10n.sketchColorAccent),
      (colors.highlight, l10n.sketchColorHighlight),
      (colors.holiday, l10n.sketchColorHoliday),
      (colors.success, l10n.sketchColorSuccess),
    ];
    // The ink of the theme is the first colour: a drawing that follows the
    // theme is readable in light and in dark.
    final colorValue = _colorValue;

    return Scaffold(
      appBar: ContentAppBar.adaptive(
        context,
        title: Text(l10n.sketchTitle),
        actions: [
          IconButton(
            key: const ValueKey('sketch-undo'),
            tooltip: l10n.sketchUndo,
            icon: Icon(AppIcons.undo),
            onPressed: _past.isEmpty ? null : _undo,
          ),
          IconButton(
            key: const ValueKey('sketch-redo'),
            tooltip: l10n.sketchRedo,
            icon: Icon(AppIcons.redo),
            onPressed: _future.isEmpty ? null : _redo,
          ),
          IconButton(
            key: const ValueKey('sketch-clear'),
            tooltip: l10n.sketchClear,
            icon: Icon(AppIcons.erase),
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
        ],
      ),
      // The canvas takes the room that is left; the bottom panel (tools,
      // colours and «Guardar») is one column, above the system area, so the
      // row of colours is never cut by the button.
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => _canvas(constraints, colorValue),
            ),
          ),
          Container(
            width: double.infinity,
            color: colors.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.page, Sp.m, Sp.page, Sp.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Toolbar(
                      tool: _tool,
                      colorValue: colorValue,
                      palette: palette,
                      onTool: (tool) => setState(() => _tool = tool),
                      onColor: (value) => setState(() => _colorValue = value),
                    ),
                    const SizedBox(height: Sp.m),
                    PrimaryButton(
                      key: const ValueKey('sketch-save'),
                      label: l10n.sketchSave,
                      icon: AppIcons.check,
                      onPressed: _save,
                    ),
                    if (_strokes.isEmpty) ...[
                      const SizedBox(height: Sp.s),
                      Text(
                        l10n.sketchEmpty,
                        key: const ValueKey('sketch-empty-hint'),
                        style: type.meta,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The canvas: a fixed area (the size it had when the drawing started) that
  /// is scaled to fit, so the strokes never change their shape.
  Widget _canvas(BoxConstraints constraints, int colorValue) {
    _canvasHeight ??= _heightFor(constraints);
    final height = _canvasHeight!;
    final strokes = [
      ..._strokes,
      if (_current.isNotEmpty)
        SketchStroke(
          points: _current,
          colorValue: colorValue,
          width: _strokeWidth,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.all(Sp.m),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(Rad.inner),
          border: Border.all(color: context.colors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Rad.inner),
          child: FittedBox(
            fit: BoxFit.contain,
            child: Semantics(
              label: context.l10n.sketchTitle,
              child: GestureDetector(
                key: const ValueKey('sketch-canvas'),
                behavior: HitTestBehavior.opaque,
                onPanDown: _onDown,
                onPanStart: (details) => _onStart(details.localPosition),
                onPanUpdate: _onUpdate,
                onPanEnd: (_) => _onEnd(),
                onPanCancel: _onEnd,
                child: SizedBox(
                  width: _canvasWidth.toDouble(),
                  height: height.toDouble(),
                  child: CustomPaint(
                    painter: _SketchPainter(strokes),
                    size: Size(_canvasWidth.toDouble(), height.toDouble()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The height of the canvas for the room the screen gives it.
  int _heightFor(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    if (!width.isFinite || width <= 0 || !height.isFinite || height <= 0) {
      return _canvasWidth;
    }
    final ratio = height / width;
    return (1000 * ratio)
        .round()
        .clamp(1, maxSketchDimension.toInt());
  }

  void _onDown(DragDownDetails details) => _onStart(details.localPosition);

  void _onStart(Offset point) {
    if (_tool == _Tool.eraser) {
      _remember();
      _eraseAt(point);
      setState(() {});
      return;
    }
    if (_pointCount >= maxSketchPoints) return;
    _current = [SketchPoint(point.dx, point.dy)];
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_tool == _Tool.eraser) {
      _eraseAt(details.localPosition);
      setState(() {});
      return;
    }
    if (_current.isEmpty) return;
    if (_current.length >= maxSketchPointsPerStroke) return;
    if (_pointCount >= maxSketchPoints) return;
    _current = [
      ..._current,
      SketchPoint(details.localPosition.dx, details.localPosition.dy),
    ];
  }

  void _onEnd() {
    if (_tool == _Tool.eraser) return;
    if (_current.isEmpty) return;
    _remember();
    setState(() {
      _strokes.add(
        SketchStroke(
          points: _current,
          colorValue: _colorValue,
          width: _strokeWidth,
        ),
      );
      _current = const [];
    });
  }

  /// The eraser takes away the strokes it passes over (the format of a
  /// drawing has no transparent colour: a stroke is either there or not).
  void _eraseAt(Offset point) {
    _strokes.removeWhere(
      (stroke) => stroke.points.any(
        (p) => (Offset(p.x, p.y) - point).distance <= _eraserWidth,
      ),
    );
  }

  /// Remembers the drawing as it was before the last change.
  void _remember() {
    _past.add([for (final stroke in _strokes) stroke]);
    while (_past.length > 50) {
      _past.removeAt(0);
    }
    _future.clear();
  }

  void _undo() {
    if (_past.isEmpty) return;
    _future.add([for (final stroke in _strokes) stroke]);
    setState(() {
      _strokes
        ..clear()
        ..addAll(_past.removeLast());
      _current = const [];
    });
  }

  void _redo() {
    if (_future.isEmpty) return;
    _past.add([for (final stroke in _strokes) stroke]);
    setState(() {
      _strokes
        ..clear()
        ..addAll(_future.removeLast());
      _current = const [];
    });
  }

  void _clear() {
    _remember();
    setState(() {
      _strokes.clear();
      _current = const [];
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (_strokes.isEmpty) {
      _say(messenger, l10n.sketchEmpty);
      return;
    }
    final sketch = Sketch(
      width: _canvasWidth,
      height: _canvasHeight ?? _canvasWidth,
      strokes: _strokes,
    );
    final Uint8List bytes;
    try {
      bytes = SketchPng.encode(sketch);
    } catch (_) {
      _say(messenger, l10n.sketchFailed);
      return;
    }
    final key = DayKey(widget.calendarId, widget.date);
    try {
      await ref
          .read(dayAttachmentsProvider(key).notifier)
          .add(
            kind: AttachmentKind.sketch,
            bytes: bytes,
            mimeType: 'image/png',
          );
    } on AttachmentStoreException catch (error) {
      _say(
        messenger,
        error.problem == AttachmentProblem.storeFull
            ? l10n.noteAttachmentStoreFull
            : l10n.noteAttachmentTooLarge,
      );
      return;
    } catch (_) {
      _say(messenger, l10n.sketchFailed);
      return;
    }
    if (!mounted) return;
    // The drawing is now in the strip of the day, which is what the screen
    // goes back to. A notice here would not be seen (the sheet of the day is
    // under it), so the thumbnail is the confirmation.
    context.pop();
  }
}

/// The tools of the canvas: the pen, the eraser and the colours.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.tool,
    required this.colorValue,
    required this.palette,
    required this.onTool,
    required this.onColor,
  });

  final _Tool tool;
  final int colorValue;
  final List<(Color, String)> palette;
  final void Function(_Tool tool) onTool;
  final void Function(int value) onColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ToolButton(
              icon: AppIcons.edit,
              label: l10n.sketchPen,
              selected: tool == _Tool.pen,
              onPressed: () => onTool(_Tool.pen),
            ),
            const SizedBox(width: Sp.l),
            _ToolButton(
              icon: AppIcons.erase,
              label: l10n.sketchEraser,
              selected: tool == _Tool.eraser,
              onPressed: () => onTool(_Tool.eraser),
            ),
          ],
        ),
        const SizedBox(height: Sp.m),
        Semantics(
          header: true,
          child: Text(
            l10n.sketchColor,
            style: context.type.meta,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: Sp.s),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Sp.s,
          runSpacing: Sp.s,
          children: [
            for (final (color, name) in palette)
              _ColorButton(
                color: color,
                name: name,
                selected: color.toARGB32() == colorValue,
                onPressed: () => onColor(color.toARGB32()),
              ),
          ],
        ),
      ],
    );
  }
}

/// A round tool of the canvas with its name below (the pattern of the shift
/// pucks of the paint mode).
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const ringOutset = Sp.selectionGap + Sp.selectionRing / 2;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: label,
      onTap: onPressed,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(Rad.inner),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: Disc.toolPuck,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected ? colors.accentSoft : colors.surfaceRaised,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: IconSize.base,
                      color: selected
                          ? colors.accentText
                          : colors.textSecondary,
                    ),
                  ),
                  if (selected)
                    Positioned(
                      left: -ringOutset,
                      top: -ringOutset,
                      right: -ringOutset,
                      bottom: -ringOutset,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.todayRing,
                              width: Sp.selectionRing,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Sp.xs),
            Text(
              label,
              style: context.type.caption.copyWith(
                color: selected ? colors.textPrimary : colors.textMuted,
                fontWeight: selected ? FontWeight.w800 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A colour of the pen: a disc with the colour, its name for the reader of
/// screen and a check when it is the chosen one (never colour alone).
class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.color,
    required this.name,
    required this.selected,
    required this.onPressed,
  });

  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const ringOutset = Sp.selectionGap + Sp.selectionRing / 2;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: name,
      onTap: onPressed,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: Sp.touch,
          child: Center(
            child: SizedBox.square(
              dimension: Disc.s,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                    child: selected
                        ? Icon(
                            AppIcons.check,
                            size: IconSize.inline,
                            color: _inkOn(color, colors),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (selected)
                    Positioned(
                      left: -ringOutset,
                      top: -ringOutset,
                      right: -ringOutset,
                      bottom: -ringOutset,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.todayRing,
                              width: Sp.selectionRing,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The colour of the check over the disc: the one of the theme that reads
  /// on it (the text colour or the background of the theme, whichever has
  /// more contrast).
  static Color _inkOn(Color color, AppColors colors) =>
      contrastRatio(colors.textPrimary, color) >=
          contrastRatio(colors.background, color)
      ? colors.textPrimary
      : colors.background;
}

/// The strokes of the drawing.
class _SketchPainter extends CustomPainter {
  const _SketchPainter(this.strokes);

  final List<SketchStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final color = Color(stroke.colorValue);
      if (stroke.points.length == 1) {
        final point = stroke.points.first;
        canvas.drawCircle(
          Offset(point.x, point.y),
          stroke.width / 2,
          Paint()..color = color,
        );
        continue;
      }
      final path = Path()..moveTo(stroke.points.first.x, stroke.points.first.y);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.x, point.y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_SketchPainter old) {
    if (old.strokes.length != strokes.length) return true;
    for (var i = 0; i < strokes.length; i++) {
      if (old.strokes[i] != strokes[i]) return true;
    }
    return false;
  }
}

/// Says it in a notice (never throws).
void _say(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(appSnackBar(content: Text(message)));
}
