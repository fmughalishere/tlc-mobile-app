import 'package:flutter/material.dart';

/// The clinic's colours, taken from the website's own stylesheet.
///
/// These are not "close enough" values picked by eye — they are the exact
/// tokens from src/app/globals.css, so a patient who books on the phone and
/// then opens the site sees one brand rather than two that nearly match. When
/// the website's palette changes, change it here in the same commit.
///
/// The names mirror the CSS variables deliberately (`indigo` is the green —
/// the site was indigo before it was green, and the token names never caught
/// up). Renaming them here would break that correspondence and make the two
/// codebases harder to keep in step, which costs more than the confusion of
/// one badly-named colour.
class Palette {
  const Palette._();

  /// --paper / --paper-dim / --mist
  static const paper = Color(0xFFFFFFFF);
  static const paperDim = Color(0xFFF4F6F5);
  static const mist = Color(0xFFEEF0F4);

  /// --ink / --ink-soft
  static const ink = Color(0xFF191B1F);
  static const inkSoft = Color(0xFF565B66);

  /// --crimson / --crimson-deep — the call-to-action colour.
  static const crimson = Color(0xFFD81F2A);
  static const crimsonDeep = Color(0xFFA8151E);

  /// --indigo / --indigo-deep / --indigo-soft — the brand green.
  static const indigo = Color(0xFF238055);
  static const indigoDeep = Color(0xFF15563B);
  static const indigoSoft = Color(0xFF2B7D59);

  /// --line
  static const line = Color(0xFFDFE1E6);

  /// Status colours. --success / --warning / --danger and their soft fills.
  static const success = Color(0xFF0D7A72);
  static const successSoft = Color(0xFFE3F3F1);
  static const warning = Color(0xFF9A6410);
  static const warningSoft = Color(0xFFFDF3E2);
  static const danger = crimsonDeep;
  static const dangerSoft = Color(0xFFFDECED);

  /// --radius-sm / --radius-card / --radius-lg / --radius-pill, in logical
  /// pixels. The CSS is in rem at a 16px root, so 0.625rem is 10.
  static const radiusSm = 10.0;
  static const radiusCard = 16.0;
  static const radiusLg = 20.0;
  static const radiusPill = 999.0;
}
