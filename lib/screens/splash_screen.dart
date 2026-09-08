import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../i18n/strings.dart';

/// The first thing anyone sees.
///
/// It says nothing about what it is doing. An earlier version had a spinner
/// and the words "Getting things ready…" under it, which is a sentence that
/// only ever makes a wait feel longer — it draws attention to the waiting and
/// tells the person nothing they can act on. What is left is the clinic's mark
/// and a thin progress line, on screen for well under a second while the
/// session resolves and the catalogue arrives.
///
/// White, not the brand green: the mark is a red heart in a green hand, and it
/// needs a light ground to read as itself. A logo floated on a dark field of
/// one of its own two colours loses half of them.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>();

    return Scaffold(
      backgroundColor: Palette.paper,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Image.asset(
              'assets/images/logo-icon.png',
              width: 128,
              // If the asset is ever missing the splash still has to appear —
              // an app that shows a grey rectangle on launch reads as broken
              // before it has done anything.
              errorBuilder: (_, __, ___) => const SizedBox(height: 128),
            ),
            const SizedBox(height: 24),
            Text(
              locale.t('app.name'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Palette.indigoDeep,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 46),
              child: Text(
                locale.t('app.tagline'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Palette.inkSoft,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
            const Spacer(),
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                minHeight: 2.5,
                backgroundColor: Palette.mist,
                valueColor: AlwaysStoppedAnimation<Color>(Palette.indigo),
              ),
            ),
            const SizedBox(height: 34),
          ],
        ),
      ),
    );
  }
}
