import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../data/repository.dart';

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
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((_) {
        // Tapped from outside. Whatever the message said, the truth is on the
        // server — so the lists are reloaded rather than patched from the
        // notification's own text.
        onRefresh?.call();
      });

      // Opened from cold by tapping a notification: the stream above never
      // fires for that one, because it arrived before anything was listening.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) onRefresh?.call();
    } catch (error, stack) {
      // Push is a courtesy layer. A phone without Play Services, a project
      // without messaging configured, a simulator — none of these should stop
      // somebody booking an appointment.
      debugPrint('[push] could not start: $error\n$stack');
    }
  }

  Future<void> _register(String token) async {
    _token = token;
    try {
      await _repo.registerPushToken(
        token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      debugPrint('[push] registered with the server');
    } catch (error) {
      debugPrint('[push] could not register token: $error');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    onRefresh?.call();

    final notification = message.notification;
    final title = notification?.title?.trim() ?? '';
    final body = notification?.body?.trim() ?? '';
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
