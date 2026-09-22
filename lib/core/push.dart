import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../i18n/strings.dart';

/// Notifications that reach the phone, not just the bell inside the app.
///
/// ── Why this is not optional ──
///
/// The clinic can open a session early. That is a kindness, and it is worth
/// nothing if the only way for the patient to find out is to keep opening the
/// app and looking. An in-app notification list serves the person who is
/// already in the app; this serves the person who is not — which is everyone,
/// nearly all of the time.
///
/// ── What the server needs from this file ──
///
/// One string: Firebase's registration token for this install. The app sends
/// it to /api/push/token after signing in and deletes it on sign-out. The
/// second half matters more than it sounds: a phone that is sold, lent or
/// handed to a family member must stop delivering somebody's medical
/// appointments to a stranger's lock screen, and waiting for the token to
/// expire on its own is not a plan.
///
/// ── The three states a message can arrive in ──
///
///   · app closed      — the OS draws the notification. Nothing here runs
///                       until the patient taps it.
///   · app backgrounded — same, plus `onMessageOpenedApp` when tapped.
///   · app in front    — the OS draws nothing at all, by design, because it
///                       assumes the app will handle it. If nothing does, the
///                       message vanishes with no trace, which reads as a bug
///                       to everyone who sees it. So `onMessage` shows a
///                       banner and refreshes the lists behind it.
/// The one ScaffoldMessenger for the whole app.
///
/// A push can arrive while any screen is on top. `ScaffoldMessenger.of(context)`
/// needs a context mounted under the MaterialApp at that exact moment; a key
/// does not. Declared here rather than in app.dart so that the file which
/// needs it does not have to import the file that builds the UI.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// The app's navigator, reachable from outside the widget tree.
///
/// A notification is tapped while the app is closed. There is no screen, no
/// BuildContext and no route stack yet — by the time one exists, the tap is
/// long over. A key held here survives all of that, so the message can still
/// say "open this appointment" when the app finally has somewhere to open it.
final navigatorKey = GlobalKey<NavigatorState>();

/// One instance for the app's lifetime.
///
/// Not in the provider tree on purpose: sign-out has to unregister this phone
/// *before* Firebase clears the user, and by the time a widget notices the
/// user is gone the request can no longer be authorised. A plain top-level
/// value can be reached from Session, which is where that moment actually is.
final pushService = PushService();

class PushService {
  PushService();

  final _repo = Repository();

  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  /// Called after something arrives, so the screens catch up with the message
  /// the patient has just been shown. Set by the widget that owns this.
  Future<void> Function()? onRefresh;

  /// Called when a notification is *tapped* and names an appointment.
  ///
  /// Separate from [onRefresh] on purpose. A message arriving in the
  /// background should quietly bring the lists up to date; a message somebody
  /// deliberately tapped should take them to what it was about. Treating both
  /// the same is how an app answers "your session has started" by dropping
  /// someone on a home screen to go and find it.
  Future<void> Function(String appointmentId)? onOpenAppointment;

  /// Starts delivery for the signed-in user.
  ///
  /// Safe to call more than once — signing in again with the same install
  /// simply re-registers the same token, which the server overwrites.
  Future<void> start() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // iOS refuses to deliver anything without this, and Android 13+ needs it
      // for the notification to be shown at all. On older Android it returns
      // "authorized" immediately without troubling anyone.
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        // Not an error and not worth a dialog. Someone who said no to
        // notifications said no on purpose; the bell inside the app still
        // works, and nagging is how an app gets uninstalled.
        debugPrint('[push] notifications declined by the user');
        return;
      }

      // iOS hands out the FCM token only after APNs has issued its own, and
      // for a few seconds after launch there is none. Asking too early returns
      // null — which is not a failure, just an answer that is not ready yet.
      final token = await messaging.getToken();
      if (token != null) await _register(token);

      // Firebase rotates tokens on its own schedule — after a restore, a
      // reinstall, or for no visible reason. A token registered once and never
      // updated stops working silently, and silence is exactly the failure
      // this whole file exists to prevent.
      _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen(_register);

      _messageSub?.cancel();
      _messageSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      _openedSub?.cancel();
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);

      // Opened from cold by tapping a notification: the stream above never
      // fires for that one, because it arrived before anything was listening.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        // A beat, so the app has finished deciding which screen it opens to.
        // Pushing a route onto a Navigator that is still being built puts the
        // appointment underneath the home screen instead of on top of it.
        Future<void>.delayed(const Duration(milliseconds: 700), () {
          _onOpened(initial);
        });
      }
    } catch (error, stack) {
      // Push is a courtesy layer. A phone without Play Services, a project
      // without messaging configured, a simulator — none of these should stop
      // somebody booking an appointment.
      debugPrint('[push] could not start: $error\n$stack');
    }
  }

  /// A notification the patient tapped.
  ///
  /// The lists are reloaded first and the screen opened afterwards, in that
  /// order: the message may be the first the app has heard of this
  /// appointment — a follow-up the doctor booked a minute ago — and opening it
  /// before the data arrives shows an empty screen for something that exists.
  ///
  /// Nothing is read from the notification except the id. What it *says* about
  /// the appointment is a copy of how things were when it was sent, and by the
  /// time somebody taps it the session may have ended.
  void _onOpened(RemoteMessage message) {
    final id = message.data['appointmentId'];

    () async {
      await onRefresh?.call();
      if (id is String && id.isNotEmpty) {
        await onOpenAppointment?.call(id);
      }
    }();
  }

  Future<void> _register(String token) async {
    _token = token;
    try {
      await _repo.registerPushToken(
        token,
        platform: Platform.isIOS ? 'ios' : 'android',
        locale: LocaleController.urdu ? 'ur' : 'en',
      );
      debugPrint('[push] registered with the server');
    } catch (error) {
      debugPrint('[push] could not register token: $error');
    }
  }

  /// Re-sends this phone's token with the current language, so the next
  /// lock-screen notification is written in it. Called when the patient
  /// switches language; a no-op before sign-in.
  Future<void> refreshLocale() async {
    final token = _token;
    if (token == null) return;
    await _register(token);
  }

  void _onForegroundMessage(RemoteMessage message) {
    onRefresh?.call();

    // The server sends both languages in `data`, so the in-app banner follows
    // the app's own language even if the token was registered in the other.
    final notification = message.notification;
    final urdu = LocaleController.urdu;
    String pickData(String en, String ur) {
      final value = (message.data[urdu ? ur : en] ?? '').toString().trim();
      return value;
    }
    final dataTitle = pickData('title', 'titleUr');
    final dataBody = pickData('body', 'bodyUr');
    final title = dataTitle.isNotEmpty ? dataTitle : (notification?.title?.trim() ?? '');
    final body = dataBody.isNotEmpty ? dataBody : (notification?.body?.trim() ?? '');
    if (title.isEmpty && body.isEmpty) return;

    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    // Replaces rather than queues. Two notifications arriving together should
    // not mean the second waits behind four seconds of the first.
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(body, style: const TextStyle(fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  /// Stops delivery to this phone. Called on sign-out, before Firebase Auth
  /// clears the user — the server needs a valid token to authorise the delete.
  Future<void> stop() async {
    // Asked for again if this run never registered it.
    //
    // `_token` is only populated by a sign-in that happened in *this* process.
    // Open the app tomorrow, already signed in, and press sign out: the field
    // is null, and without this line the phone would quietly keep receiving
    // that account's notifications. Which is the common case, not the rare one.
    var token = _token;
    if (token == null) {
      try {
        token = await FirebaseMessaging.instance.getToken();
      } catch (error) {
        debugPrint('[push] could not read the token to unregister: $error');
      }
    }
    _token = null;

    await _refreshSub?.cancel();
    await _messageSub?.cancel();
    await _openedSub?.cancel();
    _refreshSub = null;
    _messageSub = null;
    _openedSub = null;

    if (token == null) return;
    try {
      await _repo.unregisterPushToken(token);
    } catch (error) {
      // The sign-out must not fail because of this. Worst case the server
      // sends to a token this phone no longer accepts, and prunes it itself
      // the first time Firebase says it is gone.
      debugPrint('[push] could not unregister: $error');
    }
  }

  void dispose() {
    _refreshSub?.cancel();
    _messageSub?.cancel();
    _openedSub?.cancel();
    _repo.close();
  }
}
