import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../core/session.dart';
import '../data/app_data.dart';
import '../widgets/common.dart';
import 'admin/admin_shell.dart';
import 'auth/login_screen.dart';
import 'doctor/doctor_shell.dart';
import 'patient/patient_shell.dart';
import 'splash_screen.dart';

/// Decides what the app opens to, holds the splash until it can, and starts
/// the signed-in data loading the moment there is someone to load it for.
///
/// Two conditions have to be met before anything is shown:
///
///   · `session.ready` — Firebase has said whether anyone is signed in, and if
///     so their role has come back from Firestore. Routing before this is how
///     an app flashes the patient home screen at a doctor for half a second
///     and then corrects itself.
///   · a minimum of [_minimum] on screen — the opposite failure is just as
///     bad. When the session resolves in 80ms the splash appears as a flicker,
///     which reads as a glitch rather than as a brand.
///
/// [_minimum] is short — the splash is not a place to spend the patient's
/// time, and the data it was covering for is already on its way from main().
class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  static const _minimum = Duration(milliseconds: 650);

  Timer? _timer;
  bool _minimumElapsed = false;

  /// Guards against re-running the signed-in fetches on every rebuild. The
  /// session notifies several times as a profile document settles, and each
  /// one of those would otherwise be a fresh round of requests.
  String? _loadedForUid;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_minimum, () {
      if (mounted) setState(() => _minimumElapsed = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncData(Session session, AppData data) {
    final uid = session.user?.uid;
    final staff = session.role == Role.doctor || session.role == Role.admin;

    if (uid == null) {
      if (_loadedForUid != null) {
        _loadedForUid = null;
        // Cleared rather than left behind: on a shared phone the next person
        // to sign in must not see the last one's appointments, even briefly.
        data.onSignedOut();
      }
      return;
    }

    if (_loadedForUid != uid) {
      _loadedForUid = uid;
      // The identity travels with the call so that, if the server has no
      // profile document for this account, AppData can write the one that
      // should have been there instead of leaving the person stranded on a
      // blank settings screen.
      data.onSignedIn(
        staff: staff,
        uid: uid,
        name: session.name,
        email: session.user?.email,
        phone: session.user?.phoneNumber,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final data = context.read<AppData>();

    // Fired after this frame, because it calls notifyListeners() on AppData
    // and doing that during a build is an error.
    if (session.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncData(session, data);
      });
    }

    Widget child;
    if (!session.ready || !_minimumElapsed) {
      child = const SplashScreen();
    } else if (!session.signedIn) {
      child = const LoginScreen();
    } else if (session.blocked) {
      child = const _SuspendedScreen();
    } else if (session.role == Role.doctor) {
      child = const DoctorShell();
    } else if (session.role == Role.admin) {
      child = const AdminShell();
    } else {
      // Patient, and also "unknown" — an account whose profile document has
      // not arrived, or has no role on it. The patient app is the right place
      // for that: every screen in it handles a failed call gracefully, whereas
      // a dedicated "we don't know who you are" screen would be a dead end for
      // a state that usually resolves itself a second later.
      child = const PatientShell();
    }

    // A cross-fade rather than a route push: there is nothing to go back to,
    // and pushing would put the splash into the history.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: KeyedSubtree(key: ValueKey(child.runtimeType), child: child),
    );
  }
}

/// A suspended account is signed in and must still be told what happened,
/// with a way to reach a human. Silently signing them out would leave them
/// tapping "sign in" forever with no idea why it does not work.
class _SuspendedScreen extends StatelessWidget {
  const _SuspendedScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = context.read<Session>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 44, color: Palette.crimsonDeep),
                const SizedBox(height: 20),
                Text(
                  l10n.t('auth.blocked'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => dialClinic(context),
                  icon: const Icon(Icons.call_rounded, size: 19),
                  label: Text(l10n.t('common.callClinic')),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: session.signOut,
                  child: Text(l10n.t('auth.signOut')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
