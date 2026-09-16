import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../i18n/strings.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// The gateway's own page, inside the app.
///
/// ── Why a WebView and not a native card form ──
///
/// Because the card number must never touch this app. A native form would put
/// a PAN into the app's memory, its logs and its crash reports, and would drag
/// the clinic into a level of PCI scope it has no reason to be in. The
/// gateway's hosted page keeps the card on the gateway's side of the wall —
/// which is the entire point of a hosted page, and why every gateway offers
/// one.
///
/// ── How it knows the payment finished ──
///
/// It watches where the browser goes. Whatever the gateway does in between,
/// it ends by sending the patient to the clinic's own callback, which verifies
/// the signature server-side and then redirects to
/// `/patient/book/result?status=ok|failed&message=…`.
///
/// That redirect is the signal, and it is worth being precise about what it
/// is and is not. It is **not** proof of payment — this screen never decides
/// that. By the time that URL appears the server has already checked the
/// gateway's signature against the secret only it holds, found the attempt it
/// wrote down before the patient left, and written the appointment. The page
/// is the server reporting a decision it already made. The app is reading the
/// answer, not producing it.
///
/// So: no amount, no reference and no status is trusted from anything the
/// WebView says. Only `status=ok` on the clinic's own origin, and the
/// appointment list is refreshed from the server afterwards regardless.
class PaymentResult {
  const PaymentResult({
    required this.paid,
    this.message,
    this.cancelled = false,
    this.attention = false,
    this.openedInBrowser = false,
  });

  final bool paid;
  final String? message;

  /// The patient left for the phone's own browser to pay.
  ///
  /// The app cannot watch what happens there, so this is neither success nor
  /// failure — it is "go and look at the server". The screen that receives it
  /// refreshes from the server and tells them how to check.
  final bool openedInBrowser;

  /// Not paid, and not safely failed either.
  ///
  /// The server says so when it cannot tell: the gateway unreachable, a
  /// payment still in flight, a charge that does not match the booking. The
  /// distinction is the whole point — a failure invites another attempt, and
  /// another attempt here is how somebody gets charged twice. The slot is left
  /// held and the patient is asked to call rather than retry.
  final bool attention;

  /// The patient backed out. Not a failure, and not something to apologise
  /// for — the slot is released by the server's callback either way.
  final bool cancelled;
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.handover,
    required this.methodLabel,
    required this.amountPkr,
  });

  final PaymentHandover handover;
  final String methodLabel;
  final num amountPkr;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Palette.paper)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            // Checked on *start*, not on finish. The result page is the
            // clinic's own and renders fine, but there is no reason to make
            // someone who has just paid watch it load before the app reacts.
            _checkForResult(url);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _loading = false);
            _checkForResult(url);
          },
          onNavigationRequest: (request) {
            if (_checkForResult(request.url)) {
              // Stop: the app is about to close this screen, and loading a
              // page we are leaving wastes a second of the patient's time on
              // a spinner that means nothing.
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            // A sub-resource failing (a font, an analytics script) is not the
            // payment failing, and gateways load plenty of both. Only a
            // failure of the main document is worth telling anyone about.
            // `== false`, not `!`. The flag is nullable, and a null means the
            // platform did not say — which is not the same as "yes, the page
            // failed", and is not worth alarming anyone over.
            if (error.isForMainFrame == false) return;
            if (!mounted || _finished) return;
            setState(() => _loading = false);
            showToast(context, context.read<LocaleController>().t('pay.pageFailed'),
                error: true);
          },
        ),
      );

    final handover = widget.handover;
    if (handover.kind == 'form' && (handover.action ?? '').isNotEmpty) {
      _controller.loadHtmlString(_formShell(handover), baseUrl: AppConfig.apiBaseUrl);
    } else if ((handover.url ?? '').isNotEmpty) {
      _controller.loadRequest(Uri.parse(handover.url!));
    }
  }

  /// The wallets only document an HTML form post, so the app builds the one
  /// page that performs it and submits it on load.
  ///
  /// Everything interpolated is escaped. The field values come from the
  /// clinic's own server rather than from a patient, but a value containing a
  /// quote would break out of the attribute and silently mangle the payment
  /// request — and a mangled payment request fails at the gateway, where it is
  /// hardest to diagnose.
  String _formShell(PaymentHandover handover) {
    final inputs = handover.fields.entries
        .map((e) => '<input type="hidden" name="${_esc(e.key)}" value="${_esc(e.value)}">')
        .join('\n');
    return '''
<!doctype html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font:15px system-ui;display:flex;align-items:center;justify-content:center;
height:100vh;margin:0;color:#5b6670}</style></head>
<body onload="document.forms[0].submit()">
<form method="POST" action="${_esc(handover.action!)}">$inputs</form>
<p>Taking you to the payment page…</p>
</body></html>''';
  }

  static String _esc(String value) => const HtmlEscape().convert(value);

  /// True when this URL is the clinic's result page — and the screen is done.
  bool _checkForResult(String url) {
    if (_finished) return true;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (!uri.path.contains('/patient/book/result')) return false;

    // The origin is checked, not just the path. Without this, a gateway page
    // that happened to link somewhere ending in the same path could close the
    // screen with a "paid" the clinic never said.
    final expected = Uri.tryParse(AppConfig.apiBaseUrl);
    if (expected != null && uri.host.isNotEmpty && uri.host != expected.host) {
      return false;
    }

    final status = uri.queryParameters['status'];
    final message = uri.queryParameters['message'];
    _finished = true;

    // Popped after this frame: this can be called from inside a navigation
    // callback, and popping a route while the WebView is mid-decision is how
    // a half-disposed controller gets asked to keep navigating.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(
        PaymentResult(
          paid: status == 'ok',
          attention: status == 'attention',
          message: message,
        ),
      );
    });
    return true;
  }

  /// Hands the payment to the phone's own browser instead.
  ///
  /// ── Why this exists ──
  ///
  /// The in-app WebView is the better experience when it works: the patient
  /// never leaves the app, and the app sees the clinic's result page the
  /// moment the gateway redirects to it. But it is a platform view, drawn by
  /// the device's own WebView engine, and on a phone whose WebView or GPU
  /// driver is unwell that engine can take more than the app down with it. An
  /// out-of-date Android System WebView is the usual culprit and is not
  /// something this app can fix from inside itself.
  ///
  /// So there is a door. Chrome renders the same gateway page, in a process
  /// this app does not own, and the patient can see the real address and the
  /// padlock while they type a card — which is a fair argument for this being
  /// the safer path anyway.
  ///
  /// What is given up is the automatic result: the redirect lands in the
  /// browser, not here. Nothing is guessed from that — the appointment list is
  /// reloaded from the server, which is the only thing that knows whether the
  /// money arrived.
  Future<void> _payInBrowser() async {
    final l10n = context.read<LocaleController>();
    final url = widget.handover.url;

    // Only for the gateways that hand over a URL. JazzCash and EasyPaisa
    // document an HTML form POST, and a POST cannot be handed to a browser as
    // a link — there is nothing honest to open.
    if (widget.handover.kind != 'url' || url == null || url.isEmpty) {
      showToast(context, l10n.t('pay.browserUnavailable'), error: true);
      return;
    }

    await openUrl(context, url);
    if (!mounted) return;

    _finished = true;
    Navigator.of(context).pop(
      const PaymentResult(paid: false, openedInBrowser: true),
    );
  }

  Future<void> _confirmLeave() async {
    final l10n = context.read<LocaleController>();
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('pay.leaveTitle')),
        content: Text(l10n.t('pay.leaveBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('pay.keepPaying')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Palette.crimsonDeep),
            child: Text(l10n.t('pay.leave')),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      Navigator.of(context).pop(const PaymentResult(paid: false, cancelled: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PopScope(
      // Leaving mid-payment is one of the few places in this app where a
      // stray back-swipe costs something real: the patient may have paid and
      // not yet come back, and closing here means the app does not learn about
      // it until the next refresh.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _confirmLeave,
          ),
          actions: [
            if (widget.handover.kind == 'url')
              IconButton(
                tooltip: l10n.t('pay.openInBrowser'),
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                onPressed: _payInBrowser,
              ),
          ],
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.methodLabel, style: const TextStyle(fontSize: 15)),
              Text(
                Fmt.money(widget.amountPkr),
                style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const ColoredBox(
                color: Palette.paper,
                child: SizedBox.expand(child: LoadingView()),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 14, color: Palette.inkSoft),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    l10n.t('pay.secureNote'),
                    style: const TextStyle(fontSize: 11.5, color: Palette.inkSoft),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
