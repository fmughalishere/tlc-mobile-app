import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/session.dart';
import 'data/app_data.dart';
import 'firebase_options.dart';
import 'i18n/strings.dart';

/// The one entry point.
///
/// The order here is chosen so that the app spends the splash screen doing
/// work rather than waiting:
///
///   1. The saved language is read. An Urdu reader should never see a flash of
///      English on launch, and the only way to guarantee that is to know the
///      language before the first frame is built rather than after it.
///   2. Firebase starts. Session listens to the auth stream, so Firebase has
///      to exist before Session is constructed.
///   3. **The catalogue request goes out immediately** — it needs no token, so
///      it does not have to wait for anything above it, and by the time the
///      splash has finished the home screen usually has content to draw.
///
/// Firebase failing to start is treated as a showable state rather than a
/// crash: a patient on a bad connection in a waiting room should be told what
/// happened and offered the clinic's phone number, not shown a grey screen.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final locale = await LocaleController.load();

  Object? startupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stack) {
    debugPrint('[startup] Firebase failed to initialise: $error\n$stack');
    startupError = error;
  }

  if (startupError != null) {
    runApp(StartupFailureApp(locale: locale, error: startupError));
    return;
  }

  final data = AppData();
  // Not awaited on purpose. The splash is about to be on screen for a moment
  // regardless; this fills it with useful work instead of dead time.
  data.warmUp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleController>.value(value: locale),
        ChangeNotifierProvider<AppData>.value(value: data),
        ChangeNotifierProvider<Session>(create: (_) => Session()),
      ],
      child: const TlcApp(),
    ),
  );
}
