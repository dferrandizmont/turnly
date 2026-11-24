import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/calendar/application/week_layout.dart';
import '../../features/calendar/presentation/month_fit.dart';
import '../../features/calendar/presentation/shift_format.dart';
import '../../features/schedule/domain/civil_date.dart';
import '../../features/settings/application/preferences_controller.dart';
import '../format/app_date_format.dart';
import '../icons/app_icons.dart';
import '../icons/month_icons.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../theme/theme_context.dart';
import 'app_sheet.dart';
import 'choice_pill.dart';
import 'whole_word_text.dart';

/// The first day the date sheet offers when the caller names none.
const CivilDate dateSheetFirst = CivilDate(2000, 1, 1);

/// The last day the date sheet offers when the caller names none (the limit
/// the Material picker had: 1 January 2100).
const CivilDate dateSheetLast = CivilDate(2100, 1, 1);

/// Asks for a day in a sheet of the app (`docs/diseno.md`, «Asistente de
/// patrón»): the month is handled like the month screen, with an arrow on each
/// side of its name, and the day is chosen with one tap, which also closes the
/// sheet. Dragging the sheet down or going back closes it without a choice
/// (`null`).
///
/// [initial] opens the sheet on its month and is the chosen day; days before
/// [first] or after [last] are shown but cannot be chosen. [hint] is a line
/// under the [title], and [shortcuts] adds «Hoy» and «Lunes pasado» (for a
/// start day, which is usually in the past).
Future<CivilDate?> showDateSheet(
  BuildContext context, {
  required CivilDate initial,
  required String title,
  String? hint,
  CivilDate first = dateSheetFirst,
  CivilDate last = dateSheetLast,
  bool shortcuts = false,
}) => showAppSheet<CivilDate>(
  context: context,
  padded: true,
  builder: (_) => DateSheet(
    initial: initial,
    title: title,
    hint: hint,
    first: first,
    last: last,
    shortcuts: shortcuts,
  ),
);

/// UTC, so a day that a time zone skipped (Samoa, 30 December 2011) is still
/// the day it says.
DateTime _dt(CivilDate d) => DateTime.utc(d.year, d.month, d.day);

/// The body of the sheet of [showDateSheet].
class DateSheet extends ConsumerStatefulWidget {
  const DateSheet({
    super.key,
    required this.initial,
    required this.title,
    this.hint,
    this.first = dateSheetFirst,
    this.last = dateSheetLast,
    this.shortcuts = false,
  });

  final CivilDate initial;
  final String title;
  final String? hint;
  final CivilDate first;
  final CivilDate last;
  final bool shortcuts;

  @override
  ConsumerState<DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends ConsumerState<DateSheet>
    with SingleTickerProviderStateMixin {
  /// Rows of the grid: always six, so the sheet does not change height as the
  /// month changes (the same grid as the month screen).
  static const int _rows = 6;

  /// A horizontal fling faster than this changes the month.
  static const double _swipeVelocity = 250;

  late final CivilDate _selected = _clamp(widget.initial);

  /// The first day of the month on show.
  late CivilDate _month = _selected.firstDayOfMonth;

  /// The year on show while the months of the year are.
  late int _year = _selected.year;

  /// Whether the twelve months of [_year] are on show instead of the days.
  bool _months = false;

  /// 1 when the new page is later (it comes from the right), -1 earlier.
  double _direction = 1;

  /// The change of month or year (`docs/diseno.md`, «Movimiento y tacto»): the
  /// body fades in from the side it comes from, in 200 ms, or at once with
  /// «reducir movimiento».
  late final AnimationController _motion = AnimationController(
    vsync: this,
    value: 1,
  );

  /// The focus of the sheet itself: the keys of the month (Re Pág, Av Pág)
  /// reach it when the day that had the focus has left the grid.
  final FocusNode _focus = FocusNode(debugLabel: 'date sheet');

  /// The day that had the focus is not in the new month: the sheet keeps it.
  void _keepFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focus = FocusManager.instance.primaryFocus;
      if (focus == null || focus.context == null || focus is FocusScopeNode) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _motion.dispose();
    super.dispose();
  }

  CivilDate _clamp(CivilDate d) => d.isBefore(widget.first)
      ? widget.first
      : d.isAfter(widget.last)
      ? widget.last
      : d;

  bool _inRange(CivilDate d) =>
      !d.isBefore(widget.first) && !d.isAfter(widget.last);

  CivilDate _monthAt(int year, int month) {
    final index = year * 12 + month - 1;
    return CivilDate(index ~/ 12, index % 12 + 1, 1);
  }

  bool _monthInRange(CivilDate firstOfMonth) =>
      !firstOfMonth.isBefore(widget.first.firstDayOfMonth) &&
      !firstOfMonth.isAfter(widget.last.firstDayOfMonth);

  bool get _canGoBack => _months
      ? _year > widget.first.year
      : _monthInRange(_monthAt(_month.year, _month.month - 1));

  bool get _canGoForward => _months
      ? _year < widget.last.year
      : _monthInRange(_monthAt(_month.year, _month.month + 1));

  void _animate(double direction) {
    final duration = Motion.of(context, Motion.state);
    if (duration == Duration.zero) {
      _motion.value = 1;
      return;
    }
    _direction = direction;
    _motion.duration = duration;
    unawaited(_motion.forward(from: 0));
  }

  void _announce(String text) {
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        text,
        Directionality.of(context),
      ),
    );
  }

  /// One month back (-1) or forward (1), or one year in the list of months.
  void _step(int delta) {
    if (delta < 0 ? !_canGoBack : !_canGoForward) return;
    final format = AppDateFormat.of(context);
    setState(() {
      if (_months) {
        _year += delta;
      } else {
        _month = _monthAt(_month.year, _month.month + delta);
      }
    });
    _animate(delta.toDouble());
    _keepFocus();
    _announce(_months ? '$_year' : capitalize(format.monthYear(_dt(_month))));
  }

  void _showMonths() {
    setState(() {
      _months = true;
      _year = _month.year;
    });
    _animate(1);
    _announce('$_year');
  }

  void _showDays() {
    setState(() => _months = false);
    _animate(-1);
    _announce(capitalize(AppDateFormat.of(context).monthYear(_dt(_month))));
  }

  void _chooseMonth(CivilDate month) {
    // Against the month on show, not the chosen day.
    final direction = month.isBefore(_month) ? -1.0 : 1.0;
    setState(() {
      _month = month;
      _months = false;
    });
    _animate(direction);
    _announce(capitalize(AppDateFormat.of(context).monthYear(_dt(month))));
  }

  void _pick(CivilDate date) {
    if (!_inRange(date)) return;
    Navigator.of(context).pop(date);
  }

  void _onSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity <= -_swipeVelocity) {
      _step(1);
    } else if (velocity >= _swipeVelocity) {
      _step(-1);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      _step(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final format = AppDateFormat.of(context);
    final today = CivilDate.fromDateTime(ref.watch(minuteClockProvider));
    final weekStart = ref.watch(preferencesProvider.select((p) => p.weekStart));
    return Focus(
      focusNode: _focus,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Column(
        key: const ValueKey('date-sheet'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: WholeWordText(widget.title, style: type.headline),
          ),
          if (widget.hint != null) ...[
            const SizedBox(height: Sp.xs),
            WholeWordText(widget.hint!, style: type.meta),
          ],
          if (widget.shortcuts) ...[
            const SizedBox(height: Sp.m),
            _shortcuts(l10n, format, today),
          ],
          const SizedBox(height: Sp.s),
          _header(l10n, format),
          // The numbers of the grid stop growing with the reader's text size
          // where the header of the month does (a 320 dp phone at x2.0 would
          // not fit seven columns otherwise); each day says its whole date
          // aloud, so nothing is lost.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: MonthFit.headerMaxScale,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: _onSwipe,
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, child) {
                  final t = Motion.curve.transform(_motion.value);
                  return Opacity(
                    opacity: 0.3 + 0.7 * t,
                    child: FractionalTranslation(
                      translation: Offset(_direction * 0.06 * (1 - t), 0),
                      child: child,
                    ),
                  );
                },
                child: _months
                    ? _monthsGrid(l10n, format, today)
                    : _daysGrid(l10n, format, today, weekStart),
              ),
            ),
          ),
          const SizedBox(height: Sp.m),
          Semantics(
            liveRegion: true,
            container: true,
            child: Text(
              capitalize(format.spokenDate(_dt(_selected))),
              key: const ValueKey('date-sheet-selected'),
              style: type.bodyStrong,
            ),
          ),
        ],
      ),
    );
  }

  // ---- shortcuts ------------------------------------------------------------

  /// «Hoy · 23 nov» and «Lunes pasado · 16 nov»: always with the date, so
  /// «last Monday» is never ambiguous.
  Widget _shortcuts(
    AppLocalizations l10n,
    AppDateFormat format,
    CivilDate today,
  ) {
    // The Monday before today (a week back when today is a Monday).
    final lastMonday = today.addDays(
      -(today.weekday == 1 ? 7 : today.weekday - 1),
    );
    // With big text the two go one under the other, each across the whole
    // width, so a long day name (Basque «astelehena») is not cut in two.
    final stacked = MediaQuery.textScalerOf(context).scale(10) / 10 >= 1.5;
    Widget pill(Key key, String label, CivilDate date) => ChoicePill(
      key: key,
      label: '$label · ${_dayMonth(format, date)}',
      selected: date == _selected,
      expand: stacked,
      onTap: _inRange(date) ? () => _pick(date) : null,
    );
    final pills = [
      pill(const ValueKey('date-sheet-today'), l10n.calendarToday, today),
      pill(
        const ValueKey('date-sheet-last-monday'),
        l10n.dateSheetLastMonday,
        lastMonday,
      ),
    ];
    return stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < pills.length; i++) ...[
                if (i > 0) const SizedBox(height: Sp.s),
                pills[i],
              ],
            ],
          )
        : Wrap(spacing: Sp.s, runSpacing: Sp.s, children: pills);
  }

  /// "23 nov" · "Nov 23".
  static String _dayMonth(AppDateFormat format, CivilDate d) {
    final date = _dt(d);
    return format.locale.startsWith('en') || format.locale.startsWith('eu')
        ? '${format.monthShort(date)} ${d.day}'
        : '${d.day} ${format.monthShort(date)}';
  }

  // ---- header ---------------------------------------------------------------

  Widget _header(AppLocalizations l10n, AppDateFormat format) {
    final title = _months
        ? '$_year'
        : capitalize(format.monthYear(_dt(_month)));
    return Row(
      children: [
        IconButton(
          key: const ValueKey('date-sheet-previous'),
          tooltip: _months
              ? l10n.dateSheetPreviousYear
              : l10n.calendarPreviousMonth,
          icon: Icon(AppIcons.chevronLeft),
          onPressed: _canGoBack ? () => _step(-1) : null,
        ),
        Expanded(
          child: Semantics(
            button: true,
            excludeSemantics: true,
            label: title,
            hint: _months ? l10n.dateSheetShowDays : l10n.dateSheetChooseMonth,
            onTap: _months ? _showDays : _showMonths,
            child: InkWell(
              key: const ValueKey('date-sheet-title'),
              borderRadius: Rad.buttonRadius,
              onTap: _months ? _showDays : _showMonths,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sp.touch),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sp.xs,
                    vertical: Sp.xs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // The title wraps (two lines at large text) rather than
                      // being cut: «2026(e)ko a…» in Basque at x2.0.
                      Flexible(
                        child: WholeWordText(
                          title,
                          textAlign: TextAlign.center,
                          style: context.type.bodyStrong,
                        ),
                      ),
                      if (!_months) ...[
                        const SizedBox(width: Sp.xs),
                        Icon(MonthIcons.expand, size: IconSize.inline),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('date-sheet-next'),
          tooltip: _months ? l10n.dateSheetNextYear : l10n.calendarNextMonth,
          icon: Icon(AppIcons.chevronRight),
          onPressed: _canGoForward ? () => _step(1) : null,
        ),
      ],
    );
  }

  // ---- days -----------------------------------------------------------------

  Widget _daysGrid(
    AppLocalizations l10n,
    AppDateFormat format,
    CivilDate today,
    int weekStart,
  ) {
    final colors = context.colors;
    final type = context.type;
    final start = monthGridStart(_month, weekStart);
    // Indexed by DateTime.weekday - 1, like the month screen's header.
    final initials = [
      l10n.calendarWeekdayMon,
      l10n.calendarWeekdayTue,
      l10n.calendarWeekdayWed,
      l10n.calendarWeekdayThu,
      l10n.calendarWeekdayFri,
      l10n.calendarWeekdaySat,
      l10n.calendarWeekdaySun,
    ];
    return Column(
      children: [
        Row(
          children: [
            for (final weekday in weekdayOrder(weekStart))
              Expanded(
                key: ValueKey('date-sheet-weekday-$weekday'),
                child: Semantics(
                  container: true,
                  label: format.weekdayLong(DateTime(2026, 1, 4 + weekday)),
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Sp.xs),
                    child: Center(
                      child: Text(
                        initials[weekday - 1],
                        maxLines: 1,
                        style: type.caption.copyWith(
                          color: colors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var r = 0; r < _rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: _dayCell(
                    l10n,
                    format,
                    today,
                    start.addDays(r * 7 + c),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(
    AppLocalizations l10n,
    AppDateFormat format,
    CivilDate today,
    CivilDate date,
  ) {
    if (date.month != _month.month || date.year != _month.year) {
      return const SizedBox(height: Sp.touch);
    }
    final enabled = _inRange(date);
    final selected = date == _selected;
    final isToday = date == today;
    final label = [
      format.spokenDate(_dt(date)),
      if (isToday) l10n.daySemanticsToday,
      if (selected) l10n.selectionCellSelected,
    ].join(', ');
    return _DayCell(
      key: ValueKey('date-sheet-day-${date.toIso()}'),
      day: date.day,
      label: label,
      selected: selected,
      today: isToday,
      enabled: enabled,
      // The focus starts on the chosen day.
      autofocus: selected,
      onTap: () => _pick(date),
    );
  }

  // ---- months of the year ---------------------------------------------------

  Widget _monthsGrid(
    AppLocalizations l10n,
    AppDateFormat format,
    CivilDate today,
  ) {
    return Column(
      children: [
        for (var row = 0; row < 3; row++)
          Row(
            children: [
              for (var col = 0; col < 4; col++)
                Expanded(
                  child: _monthTile(
                    l10n,
                    format,
                    today,
                    CivilDate(_year, row * 4 + col + 1, 1),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _monthTile(
    AppLocalizations l10n,
    AppDateFormat format,
    CivilDate today,
    CivilDate month,
  ) {
    final date = _dt(month);
    final inRange = _monthInRange(month);
    final isToday = month == today.firstDayOfMonth;
    final selected = month == _selected.firstDayOfMonth;
    final label = [
      capitalize(format.monthYear(date)),
      if (isToday) l10n.daySemanticsToday,
      if (selected) l10n.selectionCellSelected,
    ].join(', ');
    return _PickCell(
      key: ValueKey('date-sheet-month-${month.month}'),
      // The short names keep their case (docs/glosario-idiomas.md §5): lower
      // case in ca, gl and eu, a capital in Spanish and English.
      text: format.locale.startsWith('es')
          ? capitalize(format.monthShort(date))
          : format.monthShort(date),
      label: label,
      selected: selected,
      today: isToday,
      enabled: inRange,
      autofocus: false,
      wide: true,
      onTap: () => _chooseMonth(month),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.day,
    required this.label,
    required this.selected,
    required this.today,
    required this.enabled,
    required this.autofocus,
    required this.onTap,
  });

  final int day;
  final String label;
  final bool selected;
  final bool today;
  final bool enabled;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _PickCell(
    text: '$day',
    label: label,
    selected: selected,
    today: today,
    enabled: enabled,
    autofocus: autofocus,
    wide: false,
    onTap: onTap,
  );
}

/// One day of the grid or one month of the list: the whole 48 dp cell is the
/// target of the tap, and a rounded square of at most 40 dp is drawn inside
/// it. The chosen one is filled with the accent and bold, today has the
/// `todayRing`: neither is told by colour alone.
class _PickCell extends StatefulWidget {
  const _PickCell({
    super.key,
    required this.text,
    required this.label,
    required this.selected,
    required this.today,
    required this.enabled,
    required this.autofocus,
    required this.wide,
    required this.onTap,
  });

  final String text;
  final String label;
  final bool selected;
  final bool today;
  final bool enabled;
  final bool autofocus;

  /// A month tile is wider than a day cell (four to a row).
  final bool wide;
  final VoidCallback onTap;

  @override
  State<_PickCell> createState() => _PickCellState();
}

class _PickCellState extends State<_PickCell> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final color = !widget.enabled
        ? colors.disabledContent
        : widget.selected
        ? colors.onAccent
        : colors.textPrimary;
    final bold = widget.selected || widget.today;
    final shape = RoundedRectangleBorder(
      borderRadius: Rad.cellRadius,
      side: widget.today
          ? BorderSide(color: colors.todayRing, width: Sp.ring)
          : BorderSide.none,
    );
    return Semantics(
      button: true,
      selected: widget.selected,
      enabled: widget.enabled,
      // The label replaces what is drawn, but the focus of the cell is still
      // said (a screen reader or a keyboard user lands on it).
      focusable: widget.enabled,
      focused: _focused,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.enabled ? widget.onTap : null,
      child: SizedBox(
        height: Sp.touch,
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: Rad.cellRadius),
          autofocus: widget.autofocus,
          onFocusChange: (focused) => setState(() => _focused = focused),
          onTap: widget.enabled ? widget.onTap : null,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.wide ? double.infinity : 40,
                maxHeight: 40,
              ),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: widget.selected ? colors.accent : null,
                  shape: shape,
                ),
                child: Center(
                  child: Text(
                    widget.text,
                    maxLines: 1,
                    softWrap: false,
                    style: type.body.copyWith(
                      color: color,
                      fontWeight: bold ? FontWeight.w800 : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
