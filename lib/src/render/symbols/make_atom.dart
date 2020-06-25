import 'dart:ui';

import 'package:flutter/widgets.dart';
import '../../ast/options.dart';
import '../../ast/size.dart';
import '../../ast/symbols.dart';
import '../../ast/syntax_tree.dart';
import '../../ast/types.dart';
import '../../font/metrics/font_metrics.dart';
import '../../font/metrics/font_metrics_data.dart';
import '../../parser/tex_parser/symbols.dart';
import '../layout/reset_dimension.dart';

List<BuildResult> makeAtom({
  @required String symbol,
  bool variantForm = false,
  @required AtomType atomType,
  @required Mode mode,
  FontOptions overrideFont,
  @required Options options,
}) {
  // First lookup the render config table. We need the information
  var symbolRenderConfig = symbolRenderConfigs[symbol];
  if (variantForm) {
    symbolRenderConfig = symbolRenderConfig?.variantForm;
  }
  final renderConfig =
      mode == Mode.math ? symbolRenderConfig?.math : symbolRenderConfig?.text;
  final char = renderConfig?.replaceChar ?? symbol;

  // Only mathord and textord will be affected by user-specified fonts
  // Also, surrogate pairs will ignore any user-specified font.
  if (atomType == AtomType.ord && symbol.codeUnitAt(0) != 0xD835) {
    final useMathFont = mode == Mode.math ||
        (mode == Mode.text && options.mathFontOptions != null);
    var font = overrideFont ??
        (useMathFont ? options.mathFontOptions : options.textFontOptions);

    if (font != null) {
      var charMetrics = lookupChar(char, font, mode);

      // Some font (such as boldsymbol) has fallback options
      if (charMetrics == null) {
        font = font.fallback.firstWhere((fallback) {
          charMetrics = lookupChar(char, font, mode);
          return charMetrics != null;
        }, orElse: () => null);
      }

      if (charMetrics != null) {
        return [
          BuildResult(
            options: options,
            italic: charMetrics.italic.cssEm.toLpUnder(options),
            widget: makeChar(symbol, font, charMetrics, options),
          )
        ];
      } else if (ligatures.containsKey(symbol) &&
          font.fontFamily == 'Typewriter') {
        // Make a special case for ligatures under Typewriter font
        final expandedText = ligatures[symbol].split('');

        return [
          BuildResult(
            options: options,
            widget: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: expandedText
                  .map((e) =>
                      makeChar(e, font, lookupChar(e, font, mode), options))
                  .toList(growable: false),
            ),
            italic: lookupChar(expandedText.last, font, mode)
                .italic
                .cssEm
                .toLpUnder(options),
          )
        ];
      }
    }
  }

  // If the code reaches here, it means we failed to find any appliable
  // user-specified font. We will use default render configs.
  final defaultFont = renderConfig?.defaultFont ?? const FontOptions();
  final characterMetrics = getCharacterMetrics(
    character: renderConfig?.replaceChar ?? symbol,
    fontName: defaultFont.fontName,
    mode: Mode.math,
  );
  // fontMetricsData[defaultFont.fontName][replaceChar.codeUnitAt(0)];
  return [
    BuildResult(
      options: options,
      widget: makeChar(char, defaultFont, characterMetrics, options),
      italic: characterMetrics?.italic?.cssEm?.toLpUnder(options) ?? 0.0,
    )
  ];
}

Widget makeChar(String character, FontOptions font,
    CharacterMetrics characterMetrics, Options options) {
  return ResetDimension(
    height: characterMetrics?.height?.cssEm?.toLpUnder(options),
    depth: characterMetrics?.depth?.cssEm?.toLpUnder(options),
    child: Text(
      character,
      style: TextStyle(
        fontFamily: 'KaTeX_${font.fontFamily}',
        fontWeight: font.fontWeight,
        fontStyle: font.fontShape,
        fontSize: 1.21.cssEm.toLpUnder(options),
      ),
    ),
  );
}

// CharacterMetrics lookupSymbol(String symbol, bool variantForm, FontOptions font, Mode mode) {
//   final renderConfig = mode == Mode.math
//       ? symbolRenderConfigs[value].math
//       : symbolRenderConfigs[value].text;
//   return getCharacterMetrics(
//     character: renderConfig?.replaceChar ?? value,
//     fontName: font.fontName,
//     mode: mode,
//   );
// }

CharacterMetrics lookupChar(String char, FontOptions font, Mode mode) =>
    getCharacterMetrics(
      character: char,
      fontName: font.fontName,
      mode: mode,
    );

final _numberDigitRegex = RegExp('[0-9]');

final _mathitLetters = {
  // "\\imath",
  'ı', // dotless i
  // "\\jmath",
  'ȷ', // dotless j
  // "\\pounds", "\\mathsterling", "\\textsterling",
  '£', // pounds symbol
};

FontOptions mathdefault(String value) {
  if (_numberDigitRegex.hasMatch(value[0]) || _mathitLetters.contains(value)) {
    return FontOptions(
      fontFamily: 'Main',
      fontShape: FontStyle.italic,
    );
  } else {
    return FontOptions(
      fontFamily: 'Math',
      fontShape: FontStyle.italic,
    );
  }
}
