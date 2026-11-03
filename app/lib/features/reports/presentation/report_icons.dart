import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart' show IconData;
import 'package:material_symbols_icons/symbols.dart';

/// The icon of the reports (a page with text): SF Symbol on iOS and macOS,
/// Material Symbol rounded elsewhere, like `AppIcons`.
class ReportIcons {
  const ReportIcons._();

  static bool get _apple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// «Informe».
  static IconData get report =>
      _apple ? CupertinoIcons.doc_text : Symbols.description_rounded;
}
