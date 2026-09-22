import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/deep_links.dart';
import '../core/email_verification.dart';
import '../core/palette.dart';
import '../core/push.dart';
import '../core/session.dart';
import '../data/app_data.dart';
import '../widgets/common.dart';
import '../models/models.dart';
import 'admin/admin_shell.dart';
import 'appointments/appointment_detail_screen.dart';
import 'auth/login_screen.dart';
import 'auth/verify_email_screen.dart';
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

class _BootGateState extends State<BootGate> with WidgetsBindingObserver {
  static const _minimum = Duration(milliseconds: 650);

  Timer? _timer;
  bool _minimumElapsed = false;

  /// Guards against re-running the signed-in fetches on every rebuild. The
  /// session notifies several times as a profile document settles, and each
  /// one of those would otherwise be a fresh round of requests.
  String? _loadedForUid;

  /// https://tlcmedclinics.com/patient/book/result links — the patient coming
  /// back from paying by card in the browser. Started here, once, because this
  /// is the widget that owns the reload they trigger.
  late final DeepLinks _deepLinks = DeepLinks(onPaymentReturn: _refreshSignedIn);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer(_minimum, () {
      if (mounted) setState(() => _minimumElapsed = true);
    });
    _deepLinks.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_deepLinks.dispose());
    super.dispose();
  }

  /// The same reload the app does on returning to the foreground. Before
  /// anyone is signed in there is nothing to reload — and the first load after
  /// sign-in fetches the appointments anyway.
  Future<void> _refreshSignedIn() async {
    if (!mounted || _loadedForUid == null) return;
    final data = context.read<AppData>();
    await Future.wait([
      data.refreshAppointments(),
      data.refreshNotifications(),
    ]);
  }

  /// Reloads whenever the app comes back to the front.
  ///
  /// ── Why this earns its place ──
  ///
  /// The patient leaves the app constantly, and almost never idly: they go to
  /// the browser to pay, to their inbox to verify an email, to Chrome to join a
  /// call. Every one of those changes something on the server, and until now
  /// the app only found out if somebody thought to pull the list down.
  ///
  /// Payment is the case that made this necessary. The gateway's redirect
  /// lands in the browser, not here, so the app cannot watch it — but coming
  /// back to the app is itself the signal that something happened. Asking the
  /// server then is both the simplest way to know and the only reliable one.
  ///
  /// Cheap enough to do unconditionally: two requests, only while signed in,
  /// and only on an actual return to the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!mounted || _loadedForUid == null) return;

    final data = context.read<AppData>();
    unawaited(data.refreshAppointments());
    unawaited(data.refreshNotifications());
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

      // Notifications on the phone, not only in the bell. Started here because
      // this is the one place that knows a *new* person has signed in — and
      // registering the same install twice for the same account would have the
      // server storing a token it already has.
      //
      // Deliberately not awaited: permission prompts and a token round trip
      // must not hold up the appointment list.
      pushService.onRefresh = () async {
        // A message arrived. What it said is not trusted — the lists are
        // reloaded from the server, which is the only thing that knows.
        await data.refreshNotifications();
        await data.refreshAppointments();
      };

      // Tapped, not merely received: take them to what it was about.
      pushService.onOpenAppointment = (appointmentId) async {
        final navigator = navigatorKey.currentState;
        if (navigator == null) return;

        Appointment? match;
        for (final a in data.appointments) {
          if (a.id == appointmentId) {
            match = a;
            break;
          }
        }

        // Not in the list. Rather than guess, do nothing beyond the refresh
        // that already ran — a doctor tapping a patient's notification, or an
        // appointment cancelled since the message went out, both land here and
        // neither wants a broken screen.
        if (match == null) return;

        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => AppointmentDetailScreen(appointment: match!),
          ),
        );
      };

      unawaited(pushService.start());
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
    } else if (needsEmailVerification(session.user)) {
      // Checked here rather than inside the sign-in screen, because there are
      // three ways to arrive signed-in — creating an account, signing in, and
      // simply reopening the app tomorrow — and all three have to end at the
      // same place. One gate is also one thing to get right.
      child = const VerifyEmailScreen();
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
