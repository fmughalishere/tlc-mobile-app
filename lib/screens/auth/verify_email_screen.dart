import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/email_verification.dart';
import '../../core/palette.dart';
import '../../core/session.dart';
import '../../i18n/strings.dart';
import '../../widgets/common.dart';

/// "Open the link we emailed you."
///
/// ── Why this is a screen and not a dialog ──
///
/// Because the person has to leave the app to finish it. They go to their
/// inbox, tap a link, and come back — possibly minutes later, possibly after
/// Android has killed the app in the background. A dialog would not survive
/// that. A screen the gate decides to show does, and it is still there when
/// they return.
///
/// ── Why it checks by itself ──
///
/// Firebase does not tell the app when a link is tapped: the verification
/// happens on Google's servers, in a browser, in a different process. The only
/// way to find out is to ask. So this polls every few seconds while it is on
/// screen, and there is a button for the impatient. Somebody who has just
/// verified their email and comes back to a screen still insisting they
/// haven't would reasonably conclude the app is broken.
///
/// The poll stops the moment the screen goes away, and it is deliberately slow
/// — this is a person walking to their inbox, not a race.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _pollEvery = Duration(seconds: 4);

  /// Firebase itself rate-limits verification emails, and its error for
  /// sending too many is unhelpful. Holding the button for a minute is both
  /// kinder to read and keeps the account well clear of that limit.
  static const _resendCooldown = Duration(seconds: 60);

  Timer? _poll;
  Timer? _tick;
  DateTime? _lastSent;
  bool _checking = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(_pollEvery, (_) => _check(quiet: true));
    // One tick a second, only so the countdown on the resend button moves.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _secondsLeft > 0) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  int get _secondsLeft {
    final sent = _lastSent;
    if (sent == null) return 0;
    final left = _resendCooldown - DateTime.now().difference(sent);
    return left.isNegative ? 0 : left.inSeconds + 1;
  }

  /// Asks Firebase whether the link has been tapped yet.
  ///
  /// `quiet` is the periodic check: it must never interrupt with a message,
  /// because a toast appearing every four seconds saying "not yet" would be
  /// unbearable. The button's check is not quiet — it was asked for.
  Future<void> _check({bool quiet = false}) async {
    if (_checking) return;
    final session = context.read<Session>();
    final l10n = context.read<LocaleController>();

    if (!quiet) setState(() => _checking = true);
    try {
      final user = await session.reloadUser();
      if (!mounted) return;
      if (user != null && !needsEmailVerification(user)) {
        // Nothing to navigate: the gate above this screen is watching the
        // session and swaps this out for the app itself.
        _poll?.cancel();
        showToast(context, l10n.t('auth.verifyThanks'));
      } else if (!quiet) {
        showToast(context, l10n.t('auth.verifyNotYet'), error: true);
      }
    } finally {
      if (mounted && !quiet) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _sending) return;
    final l10n = context.read<LocaleController>();
    setState(() => _sending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (!mounted) return;
      setState(() => _lastSent = DateTime.now());
      showToast(context, l10n.t('auth.verifyResent'));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // The one worth naming: Firebase refuses after a handful of sends in
      // quick succession, and "unknown error" would send the person looking
      // for a problem that fixes itself in a few minutes.
      final message = e.code == 'too-many-requests'
          ? l10n.t('auth.verifyTooMany')
          : (e.message ?? l10n.t('auth.verifyFailed'));
      showToast(context, message, error: true);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.watch<Session>();
    final email = session.user?.email ?? '';
    final waiting = _secondsLeft;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.t('auth.verifyTitle')),
        actions: [
          TextButton(
            onPressed: l10n.toggle,
            child: Text(l10n.isUrdu ? 'English' : 'اردو'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Palette.paperDim,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 34,
                  color: Palette.indigoDeep,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              l10n.t('auth.verifyHeading'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.t('auth.verifySentTo'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              email,
              textAlign: TextAlign.center,
              // The address is Latin text whichever language the app is in,
              // and mirroring it would put the "@" on the wrong side.
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Palette.ink,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Palette.paperDim,
                borderRadius: BorderRadius.circular(Palette.radiusCard),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Bullet(l10n.t('auth.verifyStep1')),
                  Bullet(l10n.t('auth.verifyStep2')),
                  Bullet(l10n.t('auth.verifySpam')),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _checking ? null : () => _check(),
                child: _checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Palette.paper),
                        ),
                      )
                    : Text(l10n.t('auth.verifyDone')),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (waiting > 0 || _sending) ? null : _resend,
                icon: const Icon(Icons.send_outlined, size: 18),
                label: Text(
                  waiting > 0
                      ? '${l10n.t('auth.verifyResend')} ($waiting)'
                      : l10n.t('auth.verifyResend'),
                ),
              ),
            ),

            const SizedBox(height: 26),
            Center(
              child: Text(
                l10n.t('auth.verifyWrongEmail'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Palette.inkSoft),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: session.signOut,
                child: Text(l10n.t('auth.signOut')),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: () => dialClinic(context),
                icon: const Icon(Icons.call_outlined, size: 18),
                label: Text(l10n.t('common.callClinic')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
