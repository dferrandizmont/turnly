import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Asset paths of the fonts embedded in the PDF. Roboto (Apache 2.0, the
/// license sits next to the files) covers Latin with accents, `ç`, `ñ`,
/// `ŀ`, `·` and the rest of what Spanish, Catalan, Galician, Basque and
/// English need. The standard PDF fonts (Helvetica) are not enough: they
/// are not embedded, so a viewer may swap them, and they only reach Latin-1.
const String reportFontRegularAsset = 'assets/fonts/Roboto-Regular.ttf';
const String reportFontBoldAsset = 'assets/fonts/Roboto-Bold.ttf';

/// The two weights the report uses.
class ReportFonts {
  const ReportFonts({required this.regular, required this.bold});

  /// The standard PDF fonts, Latin-1 only. For tests that search the text of
  /// the PDF: a standard font writes it as plain strings, an embedded one as
  /// glyph numbers.
  factory ReportFonts.standard() => ReportFonts(
    regular: pw.Font.helvetica(),
    bold: pw.Font.helveticaBold(),
  );

  final pw.Font regular;
  final pw.Font bold;
}

/// Loads the embedded fonts from [bundle] (the app's assets by default).
Future<ReportFonts> loadReportFonts([AssetBundle? bundle]) async {
  final source = bundle ?? rootBundle;
  final regular = await source.load(reportFontRegularAsset);
  final bold = await source.load(reportFontBoldAsset);
  return ReportFonts(regular: pw.Font.ttf(regular), bold: pw.Font.ttf(bold));
}
