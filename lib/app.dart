import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/palette.dart';
import 'core/theme.dart';
import 'i18n/strings.dart';
import 'screens/boot_gate.dart';

/// The MaterialApp, and nothing else.
///
/// It is kept this small on purpose: the theme swaps wholesale between the
/// Latin and the Urdu one, and that swap is much easier to reason about when
/// exactly one widget performs it.
class TlcApp extends StatelessWidget {
  const TlcApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>();

    return MaterialApp(
      title: 'TLC Med Clinics',
      debugShowCheckedModeBanner: false,

      // Two full themes rather than one theme with a font override. Nastaliq
      // needs more line height than Latin at every text size, so the
      // difference between the two is not a single property.
      theme: locale.isUrdu ? AppTheme.urdu() : AppTheme.light(),

      locale: locale.locale,
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Urdu is right-to-left, and Flutter picks that up from the locale for
      // its own widgets. This makes it explicit for ours too.
      builder: (context, child) => Directionality(
        textDirection: locale.direction,
        child: child ?? const SizedBox.shrink(),
      ),

      home: const BootGate(),
    );
  }
}

/// Shown when Firebase itself could not start.
///
/// This runs outside the provider tree — there is no Session to build one —
/// so it takes what it needs directly. It exists because "the app opens to
/// nothing" is the worst possible failure for a clinic app, and a patient who
/// cannot get in should still be able to reach a human.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key, required this.locale, required this.error});

  final LocaleController locale;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: locale.direction,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 44, color: Palette.inkSoft),
                    const SizedBox(height: 18),
                    Text(
                      locale.t('common.somethingWrong'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      locale.t('common.offline'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '$error',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 11, color: Palette.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
