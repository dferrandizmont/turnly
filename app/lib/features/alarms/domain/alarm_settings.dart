import '../../schedule/domain/civil_date.dart';

/// When the mid-shift pause notice rings (docs/alarmas.md, «Aviso de pausa»).
enum PauseTiming {
  /// Halfway through the shift (or through the long segment of a split one).
  midShift,

  /// [PauseAlertSettings.afterMinutes] after the shift starts.
  afterStart,
}

/// The pause notice of one shift type: "Toca pausa" in the middle of the
/// shift. Off until the user opts in, per shift type.
class PauseAlertSettings {
  const PauseAlertSettings({
    this.enabled = false,
    this.timing = PauseTiming.midShift,
    this.afterMinutes = defaultAfterMinutes,
  });

  /// 4 h after the start: the usual break of an 8 h shift.
  static const int defaultAfterMinutes = 4 * 60;

  /// Shortest and longest "after the start" we accept (a day minus a minute:
  /// a longer lead never fits inside a shift).
  static const int minAfterMinutes = 15;
  static const int maxAfterMinutes = 1439;

  /// A shift of this many minutes or more is the one the form suggests the
  /// notice for (8 h).
  static const int suggestedFromMinutes = 8 * 60;

  static const PauseAlertSettings off = PauseAlertSettings();

  final bool enabled;
  final PauseTiming timing;

  /// Minutes after the start, only for [PauseTiming.afterStart].
  final int afterMinutes;

  PauseAlertSettings copyWith({
    bool? enabled,
    PauseTiming? timing,
    int? afterMinutes,
  }) => PauseAlertSettings(
    enabled: enabled ?? this.enabled,
    timing: timing ?? this.timing,
    afterMinutes: afterMinutes ?? this.afterMinutes,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'timing': timing == PauseTiming.midShift ? 'mid' : 'after',
    'afterMinutes': afterMinutes,
  };

  /// Tolerant: wrong types fall back to the defaults (off, mid-shift, 4 h)
  /// and the lead is clamped.
  factory PauseAlertSettings.fromJson(Map<String, Object?> json) {
    final after = json['afterMinutes'];
    return PauseAlertSettings(
      enabled: json['enabled'] == true,
      timing: json['timing'] == 'after'
          ? PauseTiming.afterStart
          : PauseTiming.midShift,
      afterMinutes: after is num && after.isFinite
          ? after.clamp(minAfterMinutes, maxAfterMinutes).round()
          : defaultAfterMinutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PauseAlertSettings &&
      other.enabled == enabled &&
      other.timing == timing &&
      other.afterMinutes == afterMinutes;

  @override
  int get hashCode => Object.hash(enabled, timing, afterMinutes);

  @override
  String toString() =>
      'PauseAlertSettings(enabled: $enabled, timing: ${timing.name}, '
      'after: $afterMinutes)';
}

/// Alarm choices of one shift type. Off until the user opts in.
class AlarmTypeSettings {
  const AlarmTypeSettings({
    this.enabled = false,
    this.minutesBefore = defaultMinutesBefore,
    this.label,
    this.dayBefore = false,
    this.dayBeforeMinute = defaultDayBeforeMinute,
    this.secondSegment = true,
    this.pause = PauseAlertSettings.off,
  }) : assert(dayBeforeMinute >= 0 && dayBeforeMinute < 1440);

  static const int defaultMinutesBefore = 90;

  /// 20:00, in minutes after midnight.
  static const int defaultDayBeforeMinute = 20 * 60;

  /// Longest lead we accept (a day): the planner's search window relies on it.
  static const int maxMinutesBefore = 24 * 60;

  static const AlarmTypeSettings off = AlarmTypeSettings();

  final bool enabled;

  /// How long before the shift starts the alarm rings.
  final int minutesBefore;

  /// Custom title of the notification; null or blank = "Turno de X a las H".
  /// It only replaces the title of the alarm before the shift, not that of
  /// the day-before reminder.
  final String? label;

  /// Also remind the day before, at [dayBeforeMinute] (wall-clock time).
  final bool dayBefore;

  /// Minutes after 00:00 at which the day-before reminder rings, `0..1439`.
  final int dayBeforeMinute;

  /// Also ring before the second segment of a split shift (A12), with the
  /// same lead as the first. On by default, so a split shift rings twice;
  /// it only matters for types that have a second segment, and the day-before
  /// reminder (about the shift as a whole) does not depend on it.
  final bool secondSegment;

  /// The pause notice of this type (independent of [enabled]: a type can have
  /// only the pause notice).
  final PauseAlertSettings pause;

  /// Whether this type can make any notice ring: the alarm before the shift
  /// or the pause notice.
  bool get anyEnabled => enabled || pause.enabled;

  /// [label] without surrounding blanks, or null when there is none.
  String? get cleanLabel {
    final trimmed = label?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  AlarmTypeSettings copyWith({
    bool? enabled,
    int? minutesBefore,
    String? label,
    bool clearLabel = false,
    bool? dayBefore,
    int? dayBeforeMinute,
    bool? secondSegment,
    PauseAlertSettings? pause,
  }) => AlarmTypeSettings(
    enabled: enabled ?? this.enabled,
    minutesBefore: minutesBefore ?? this.minutesBefore,
    label: clearLabel ? null : label ?? this.label,
    dayBefore: dayBefore ?? this.dayBefore,
    dayBeforeMinute: dayBeforeMinute ?? this.dayBeforeMinute,
    secondSegment: secondSegment ?? this.secondSegment,
    pause: pause ?? this.pause,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'minutesBefore': minutesBefore,
    if (cleanLabel != null) 'label': cleanLabel,
    'dayBefore': dayBefore,
    'dayBeforeMinute': dayBeforeMinute,
    // Only written when turned off: the default (on) is what a missing key
    // reads as, so settings of a type without a second segment stay as they
    // were.
    if (!secondSegment) 'secondSegment': false,
    // Same idea: a type that never touched the pause notice keeps its JSON
    // as it was (an older app ignores the key).
    if (pause != PauseAlertSettings.off) 'pause': pause.toJson(),
  };

  /// Tolerant: wrong types (and NaN or infinite numbers) fall back to the
  /// defaults, lead and day-before time are clamped. Settings stored before
  /// the day-before reminder existed read as "no day-before reminder".
  factory AlarmTypeSettings.fromJson(Map<String, Object?> json) {
    final minutes = json['minutesBefore'];
    final label = json['label'];
    final dayBeforeMinute = json['dayBeforeMinute'];
    final pause = json['pause'];
    return AlarmTypeSettings(
      enabled: json['enabled'] == true,
      minutesBefore: minutes is num && minutes.isFinite
          ? minutes.clamp(0, maxMinutesBefore).round()
          : defaultMinutesBefore,
      label: label is String ? label : null,
      dayBefore: json['dayBefore'] == true,
      dayBeforeMinute: dayBeforeMinute is num && dayBeforeMinute.isFinite
          ? dayBeforeMinute.clamp(0, 1439).round()
          : defaultDayBeforeMinute,
      secondSegment: json['secondSegment'] != false,
      pause: pause is Map
          ? PauseAlertSettings.fromJson(pause.cast<String, Object?>())
          : PauseAlertSettings.off,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AlarmTypeSettings &&
      other.enabled == enabled &&
      other.minutesBefore == minutesBefore &&
      other.cleanLabel == cleanLabel &&
      other.dayBefore == dayBefore &&
      other.dayBeforeMinute == dayBeforeMinute &&
      other.secondSegment == secondSegment &&
      other.pause == pause;

  @override
  int get hashCode => Object.hash(
    enabled,
    minutesBefore,
    cleanLabel,
    dayBefore,
    dayBeforeMinute,
    secondSegment,
    pause,
  );

  @override
  String toString() =>
      'AlarmTypeSettings(enabled: $enabled, minutesBefore: $minutesBefore, '
      'label: $cleanLabel, dayBefore: $dayBefore @ $dayBeforeMinute, '
      'secondSegment: $secondSegment, pause: $pause)';
}

/// All alarm settings: a global switch and horizon, one [AlarmTypeSettings]
/// per shift type id and the days on which nothing rings. Everything off by
/// default.
class AlarmSettings {
  const AlarmSettings({
    this.enabled = false,
    this.horizonDays = defaultHorizonDays,
    this.byShiftType = const {},
    this.skippedDates = const {},
  });

  /// Days ahead that get scheduled (docs/alarmas.md, «Límites»). 30 since
  /// A1 (it was 14): with the cap of `maxPendingAlarms` a typical rotation
  /// (one alarm a day) fits a month, and a denser one is cut by the cap and
  /// announced by the renewal notice.
  static const int defaultHorizonDays = 30;
  static const int maxHorizonDays = 30;

  /// Most skipped days we read back (old ones are pruned and nothing plans
  /// more than [maxHorizonDays] ahead, so this is only a safety net).
  static const int maxSkippedDates = 400;

  static const AlarmSettings disabled = AlarmSettings();

  final bool enabled;
  final int horizonDays;

  /// Keyed by `ShiftType.id`. A missing key means [AlarmTypeSettings.off].
  final Map<String, AlarmTypeSettings> byShiftType;

  /// Days (the day a shift starts) on which no alarm rings, whatever the
  /// shift type: the "Sin alarma este día" switch of the day detail.
  final Set<CivilDate> skippedDates;

  AlarmTypeSettings forShiftType(String shiftTypeId) =>
      byShiftType[shiftTypeId] ?? AlarmTypeSettings.off;

  /// Whether any alarm could ring: the global switch and one type with its
  /// alarm or its pause notice on.
  bool get anyActive => enabled && byShiftType.values.any((t) => t.anyEnabled);

  bool isSkipped(CivilDate date) => skippedDates.contains(date);

  AlarmSettings copyWith({
    bool? enabled,
    int? horizonDays,
    Map<String, AlarmTypeSettings>? byShiftType,
    Set<CivilDate>? skippedDates,
  }) => AlarmSettings(
    enabled: enabled ?? this.enabled,
    horizonDays: horizonDays ?? this.horizonDays,
    byShiftType: byShiftType ?? this.byShiftType,
    skippedDates: skippedDates ?? this.skippedDates,
  );

  /// Returns a copy with [shiftTypeId] set to [settings].
  AlarmSettings withShiftType(String shiftTypeId, AlarmTypeSettings settings) =>
      copyWith(byShiftType: {...byShiftType, shiftTypeId: settings});

  /// Returns a copy where [date] is skipped ([skipped] true) or rings again.
  AlarmSettings withSkipped(CivilDate date, {required bool skipped}) {
    if (isSkipped(date) == skipped) return this;
    final next = {...skippedDates};
    skipped ? next.add(date) : next.remove(date);
    return copyWith(skippedDates: next);
  }

  /// Drops the skipped days before [today]: they can no longer matter.
  AlarmSettings pruneSkipped(CivilDate today) {
    if (skippedDates.every((d) => !d.isBefore(today))) return this;
    return copyWith(
      skippedDates: {
        for (final d in skippedDates)
          if (!d.isBefore(today)) d,
      },
    );
  }

  /// 2 since A1: version 1 always wrote the old default horizon (14), which
  /// no screen lets the user change, so a stored horizon is only honoured
  /// from version 2 on (a version 1 value reads as [defaultHorizonDays]).
  static const int jsonVersion = 2;

  Map<String, Object?> toJson() => {
    'version': jsonVersion,
    'enabled': enabled,
    'horizonDays': horizonDays,
    'types': {for (final e in byShiftType.entries) e.key: e.value.toJson()},
    // ISO dates, sorted, so the stored text is stable.
    'skipped': [for (final d in skippedDates.toList()..sort()) d.toIso()],
  };

  /// Tolerant: unknown or malformed parts fall back to the defaults (all off).
  /// The horizon of a version 1 value is ignored (see [jsonVersion]).
  factory AlarmSettings.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    final horizon = version is num && version >= 2 ? json['horizonDays'] : null;
    final types = json['types'];
    final skipped = json['skipped'];
    final byType = <String, AlarmTypeSettings>{};
    if (types is Map) {
      for (final e in types.entries) {
        final value = e.value;
        if (e.key is String && value is Map) {
          byType[e.key as String] = AlarmTypeSettings.fromJson(
            value.cast<String, Object?>(),
          );
        }
      }
    }
    final skippedDates = <CivilDate>{};
    if (skipped is List) {
      for (final item in skipped) {
        if (skippedDates.length >= maxSkippedDates) break;
        if (item is! String) continue;
        try {
          skippedDates.add(CivilDate.parse(item));
        } on FormatException {
          // A malformed date is simply not a skip.
        }
      }
    }
    return AlarmSettings(
      enabled: json['enabled'] == true,
      horizonDays: horizon is num && horizon.isFinite
          ? horizon.clamp(1, maxHorizonDays).round()
          : defaultHorizonDays,
      byShiftType: Map.unmodifiable(byType),
      skippedDates: Set.unmodifiable(skippedDates),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AlarmSettings &&
      other.enabled == enabled &&
      other.horizonDays == horizonDays &&
      _sameTypes(other.byShiftType, byShiftType) &&
      other.skippedDates.length == skippedDates.length &&
      other.skippedDates.containsAll(skippedDates);

  static bool _sameTypes(
    Map<String, AlarmTypeSettings> a,
    Map<String, AlarmTypeSettings> b,
  ) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    horizonDays,
    Object.hashAllUnordered(
      byShiftType.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(skippedDates),
  );

  @override
  String toString() =>
      'AlarmSettings(enabled: $enabled, horizonDays: $horizonDays, '
      'types: $byShiftType, skipped: ${skippedDates.length})';
}
