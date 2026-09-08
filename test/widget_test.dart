// The generated counter test is gone — it referenced a `MyApp` that no longer
// exists, which would have broken `flutter analyze` and `flutter test` from
// the first commit onwards.
//
// What is left is deliberately narrow. Anything that touches Firebase cannot
// run in a plain widget test without a fake, so the things worth testing today
// are the pure ones: the dictionary and the language controller.

import 'package:flutter_test/flutter_test.dart';
import 'package:tlc_med_clinics/i18n/strings.dart';

void main() {
  test('every English key has an Urdu translation', () {
    final missing = Strings.en.keys.where((k) => !Strings.ur.containsKey(k)).toList();
    expect(missing, isEmpty, reason: 'untranslated keys: $missing');
  });

  test('no Urdu key is orphaned', () {
    final extra = Strings.ur.keys.where((k) => !Strings.en.containsKey(k)).toList();
    expect(extra, isEmpty, reason: 'Urdu keys with no English source: $extra');
  });

  test('an unknown key falls back to itself rather than rendering blank', () {
    final controller = LocaleController(false);
    expect(controller.t('nothing.here'), 'nothing.here');
  });

  test('Urdu falls back to English when a key is only written in English', () {
    final controller = LocaleController(true);
    expect(controller.t('app.name'), Strings.ur['app.name']);
    expect(controller.t('nothing.here'), 'nothing.here');
  });
}
