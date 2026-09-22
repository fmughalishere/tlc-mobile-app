import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/strings.dart';
import 'config.dart';
import 'push.dart';

/// Links from https://tlcmedclinics.com that open the app instead of the
/// browser — today exactly one: the page the payment gateway returns a
/// patient to after paying by card in the phone's browser,
///
///   https://tlcmedclinics.com/patient/book/result?status=ok|attention|failed&message=…
///
/// Android routes that address here through the verified intent filter in
/// AndroidManifest.xml (and /.well-known/assetlinks.json on the website).
/// Flutter's own deep linking is switched off on both platforms, because the
/// app has no route table and would otherwise try to push a named route that
/// does not exist.
///
/// ── What the link is trusted for ──
///
/// Nothing, beyond "the patient has just come back from paying". Anyone can
/// type this URL, so the status only chooses which sentence to show; whether
/// the appointment really exists is decided by the reload [onPaymentReturn]
/// runs, which asks the server — exactly what the app already does on every
/// return to the foreground. `message` is the server's English sentence; the
/// website translates it on the page. It is deliberately not shown here: it
/// is free text from the address bar, and a snackbar is not a place for
/// somebody else's words — a crafted link could otherwise put any sentence,
/// or any phone number, in front of a patient in the clinic's own voice.
class DeepLinks {
  DeepLinks({required this.onPaymentReturn});

  /// Reloads the lists from the server. Set by BootGate, which owns them.
  final Future<void> Function() onPaymentReturn;

  static const _resultPath = '/patient/book/result';
  static const _hosts = {'tlcmedclinics.com', 'www.tlcmedclinics.com'};

  StreamSubscription<Uri>? _sub;

  // app_links 6.x emits the link that cold-started the app on the same stream
  // as later ones. The same link can still arrive twice (a cold start followed
  // by the activity's onNewIntent), so one identical URI within a few seconds
  // is treated as one arrival.
  Uri? _lastUri;
  DateTime? _lastAt;

  /// Starts listening. Safe to call once per app lifetime; later calls are
  /// ignored.
  void start() {
    if (_sub != null) return;
    try {
      _sub = AppLinks().uriLinkStream.listen(
        _handle,
        onError: (Object error) => debugPrint('[links] stream error: $error'),
      );
    } catch (error) {
      // A platform without the plugin (tests, desktop) must not stop the app.
      debugPrint('[links] could not start: $error');
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  void _handle(Uri uri) {
    if (uri.scheme != 'https' || !_hosts.contains(uri.host)) return;
    if (!uri.path.startsWith(_resultPath)) return;

    final now = DateTime.now();
    if (_lastUri == uri &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 5)) {
      return;
    }
    _lastUri = uri;
    _lastAt = now;

    // The same three outcomes the website's result page distinguishes, with
    // the same default: no status, or one it does not know, is "failed".
    final status = uri.queryParameters['status'] ?? 'failed';
    final message = uri.queryParameters['message'];
    debugPrint('[links] payment result: status=$status message=$message');

    unawaited(onPaymentReturn().catchError((Object error) {
      debugPrint('[links] refresh after payment failed: $error');
    }));

    final outcome = status == 'ok'
        ? _Outcome.paid
        : status == 'attention'
            ? _Outcome.attention
            : _Outcome.failed;
    _showWhenReady(outcome);
  }

  /// On a cold start the link can arrive before the first screen exists, so
  /// the snackbar waits (briefly, a few times) for the ScaffoldMessenger.
  void _showWhenReady(_Outcome outcome, [int attempt = 0]) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null || !messenger.mounted) {
      if (attempt >= 10) return;
      Future<void>.delayed(
        const Duration(milliseconds: 300),
        () => _showWhenReady(outcome, attempt + 1),
      );
      return;
    }
    _show(messenger, outcome);
  }

  void _show(ScaffoldMessengerState messenger, _Outcome outcome) {
    final urdu = LocaleController.urdu;
    final text = switch (outcome) {
      _Outcome.paid => urdu ? _paid.ur : _paid.en,
      _Outcome.attention => urdu ? _attention.ur : _attention.en,
      _Outcome.failed => urdu ? _failed.ur : _failed.en,
    };

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: outcome == _Outcome.attention ? 10 : 5),
        content: Text(text),
        // "Paid but not booked" is the one outcome where trying again would
        // charge the patient twice, so it offers the phone instead.
        action: outcome == _Outcome.attention
            ? SnackBarAction(
                label: urdu ? _call.ur : _call.en,
                onPressed: () {
                  unawaited(launchUrl(
                    Uri(scheme: 'tel', path: AppConfig.clinicPhoneE164),
                    mode: LaunchMode.externalApplication,
                  ).catchError((Object _) => false));
                },
              )
            : null,
      ),
    );
  }

  // Local on purpose: lib/i18n/strings.dart is owned elsewhere. Worded to
  // match the website's own result page (book.result.* in its dictionaries).
  static const _paid = (
    en: 'Payment received — your appointment is confirmed.',
    ur: 'ادائیگی موصول ہو گئی — آپ کی ملاقات پکی ہو گئی ہے۔',
  );
  static const _failed = (
    en: 'Payment not completed. You can try again from your appointments.',
    ur: 'ادائیگی مکمل نہیں ہوئی۔ آپ اپنی ملاقاتوں میں جا کر دوبارہ کوشش کر سکتے ہیں۔',
  );
  static const _attention = (
    en: 'Your payment was received, but the booking needs a check. '
        'Please call the clinic on ${AppConfig.clinicPhoneDisplay} — do not pay again.',
    ur: 'آپ کی ادائیگی موصول ہو گئی ہے، لیکن بکنگ کی تصدیق باقی ہے۔ '
        'براہِ کرم کلینک کو ${AppConfig.clinicPhoneDisplay} پر فون کریں — دوبارہ ادائیگی نہ کریں۔',
  );
  static const _call = (en: 'Call', ur: 'فون کریں');
}

enum _Outcome { paid, attention, failed }
