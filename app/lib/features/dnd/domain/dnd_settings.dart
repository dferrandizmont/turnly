/// The interruption filter the phone applies while it is silenced (P13,
/// docs/ola3-logica.md). The names are the ones the platform channel uses
/// (`app.cuadrante/dnd`); the screen translates them.
///
/// Each one is the Android interruption filter of the same meaning
/// (`NotificationManager.INTERRUPTION_FILTER_*`), which is what the native
/// side sets.
enum DndFilter {
  /// Nothing is filtered: the phone sounds as usual.
  all,

  /// «No molestar»: only priority notifications get through.
  priority,

  /// Total silence: nothing gets through, not even the alarms.
  none,

  /// Only the alarms get through.
  alarms;

  /// Whether this filter silences the phone at all.
  bool get silences => this != DndFilter.all;
}

/// Whether the system lets the app change the interruption filter.
enum DndPermission {
  /// Granted («Acceso a No molestar»): the app may silence the phone.
  granted,

  /// Not granted: only the system settings can give it.
  denied,

  /// The platform has no such thing (iOS: Focus is not programmable by apps).
  unsupported,
}

/// The choices of one shift type: whether the phone is silenced while it
/// works. Off until the user opts in.
class DndTypeSettings {
  const DndTypeSettings({this.enabled = false});

  static const DndTypeSettings off = DndTypeSettings();

  /// Whether the phone is silenced during the shifts of this type.
  final bool enabled;

  DndTypeSettings copyWith({bool? enabled}) =>
      DndTypeSettings(enabled: enabled ?? this.enabled);

  Map<String, Object?> toJson() => {'enabled': enabled};

  /// Tolerant: anything that is not `true` reads as "off".
  factory DndTypeSettings.fromJson(Map<String, Object?> json) =>
      DndTypeSettings(enabled: json['enabled'] == true);

  @override
  bool operator ==(Object other) =>
      other is DndTypeSettings && other.enabled == enabled;

  @override
  int get hashCode => enabled.hashCode;

  @override
  String toString() => 'DndTypeSettings(enabled: $enabled)';
}

/// All the settings of the silence windows: the global switch, the filter
/// the phone is put in and one [DndTypeSettings] per shift type id.
/// Everything off by default.
class DndSettings {
  const DndSettings({
    this.enabled = false,
    this.filter = DndFilter.priority,
    this.byShiftType = const {},
  });

  static const DndSettings disabled = DndSettings();

  /// The version of the stored JSON. 1: the first one.
  static const int jsonVersion = 1;

  /// The global switch: with it off nothing is silenced, whatever the types.
  final bool enabled;

  /// The interruption filter the phone is put in while a shift lasts.
  final DndFilter filter;

  /// Keyed by `ShiftType.id`. A missing key means [DndTypeSettings.off].
  final Map<String, DndTypeSettings> byShiftType;

  /// The choices of [shiftTypeId] (off when it has none).
  DndTypeSettings forShiftType(String shiftTypeId) =>
      byShiftType[shiftTypeId] ?? DndTypeSettings.off;

  /// Whether the shifts of [shiftTypeId] silence the phone.
  bool isEnabledFor(String shiftTypeId) =>
      enabled && forShiftType(shiftTypeId).enabled;

  /// Whether any shift could silence the phone: the global switch and one
  /// type on.
  bool get anyActive => enabled && byShiftType.values.any((t) => t.enabled);

  DndSettings copyWith({
    bool? enabled,
    DndFilter? filter,
    Map<String, DndTypeSettings>? byShiftType,
  }) => DndSettings(
    enabled: enabled ?? this.enabled,
    filter: filter ?? this.filter,
    byShiftType: byShiftType ?? this.byShiftType,
  );

  /// Returns a copy with [shiftTypeId] set to [settings].
  DndSettings withShiftType(String shiftTypeId, DndTypeSettings settings) =>
      copyWith(byShiftType: {...byShiftType, shiftTypeId: settings});

  Map<String, Object?> toJson() => {
    'version': jsonVersion,
    'enabled': enabled,
    'filter': filter.name,
    'types': {for (final e in byShiftType.entries) e.key: e.value.toJson()},
  };

  /// Tolerant: unknown or malformed parts fall back to the defaults (all
  /// off). A stored filter that is not one of ours reads as [DndFilter.priority].
  ///
  /// The stored [jsonVersion] is read too. Version 1 is the only one so far:
  /// a value without a version (or with one we do not know) is read with the
  /// same rules and its unknown parts are ignored, never guessed, so a copy
  /// of another version never breaks the app. A version older than the one we
  /// know reads as "nothing configured": the phone is never silenced because
  /// of a value we do not understand.
  factory DndSettings.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    final stored = version is num && version.isFinite
        ? version.round()
        : jsonVersion;
    final known = stored >= jsonVersion;
    final filterName = known ? json['filter'] : null;
    final types = known ? json['types'] : null;
    final byType = <String, DndTypeSettings>{};
    if (types is Map) {
      for (final e in types.entries) {
        final value = e.value;
        if (e.key is String && value is Map) {
          byType[e.key as String] = DndTypeSettings.fromJson(
            value.cast<String, Object?>(),
          );
        }
      }
    }
    return DndSettings(
      enabled: known && json['enabled'] == true,
      filter: DndFilter.values.where((f) => f.name == filterName).firstOrNull ??
          DndFilter.priority,
      byShiftType: Map.unmodifiable(byType),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DndSettings &&
      other.enabled == enabled &&
      other.filter == filter &&
      _sameTypes(other.byShiftType, byShiftType);

  static bool _sameTypes(
    Map<String, DndTypeSettings> a,
    Map<String, DndTypeSettings> b,
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
    filter,
    Object.hashAllUnordered(
      byShiftType.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'DndSettings(enabled: $enabled, filter: ${filter.name}, '
      'types: $byShiftType)';
}
