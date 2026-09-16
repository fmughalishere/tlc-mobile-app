import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/repository.dart';
import '../../i18n/strings.dart';
import '../../widgets/common.dart';

/// Signing in with a phone number and a 6-digit code.
///
/// The code comes from the clinic's own server, over Twilio Verify — the same
/// path the website uses. This screen never decides whether a code was right;
/// it sends what was typed, and the server answers with a Firebase custom
/// token or with a reason.
///
/// ── Why not Firebase Phone Auth ──
///
/// It was, and it had a trap with no clue attached: Android refuses to send
/// the SMS until the app's SHA-1 and SHA-256 are registered in the Firebase
/// console, and an unregistered build fails with `app-not-authorized` — no
/// text, no explanation. It also meant the clinic ran two OTP systems for one
/// set of patients, with two sets of credentials and two delivery records to
/// check when somebody said "no code arrived".
///
/// Errors arrive as i18n keys, so every one of them is shown in the patient's
/// own language. Nothing on this screen is hard-coded English.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _repo = Repository();

  /// The number the code went to. Null until one has been sent, which is
  /// also what tells the screen which of its two stages it is on — there is no
  /// separate flag to fall out of step with it.
  String? _sentTo;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    _repo.close();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final l10n = context.read<LocaleController>();
    final e164 = Fmt.toE164(_phone.text);
    if (e164 == null) {
      setState(() => _error = l10n.t('auth.needPhone'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _repo.requestPhoneCode(e164);
      if (!mounted) return;
      setState(() => _sentTo = e164);
    } catch (e) {
      if (mounted) setState(() => _error = _readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final l10n = context.read<LocaleController>();
    final phone = _sentTo;
    final code = _code.text.trim();
    if (phone == null) return;
    if (code.length < 6) {
      setState(() => _error = l10n.t('auth.enterCode'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final token = await _repo.verifyPhoneCode(phone, code);
      await FirebaseAuth.instance.signInWithCustomToken(token);
      await _ensureProfile(phone);
      if (mounted) widget.onDone?.call();
    } catch (e) {
      if (mounted) setState(() => _error = _readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A phone sign-in creates the Firebase credential but not the profile
  /// document, and a returning patient already has one. So: try to read it,
  /// and only write when there is nothing there.
  ///
  /// The name is asked for on this screen for exactly that case — a brand new
  /// patient. It is ignored for a returning one, whose name the clinic already
  /// has and may have corrected.
  Future<void> _ensureProfile(String e164) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final existing = await _repo.profile();
      if (existing != null) return;
    } catch (_) {
      // A 404 here is the normal "new patient" case, and any other failure is
      // better handled by attempting the write than by refusing to.
    }
    final name = _name.text.trim().isEmpty
        ? Fmt.phone(e164)
        : _name.text.trim();
    await _repo.registerProfile(uid: user.uid, name: name, phone: e164);
    await user.getIdToken(true);
  }

  /// Anything thrown, as a sentence in the patient's own language.
  ///
  /// The server answers with i18n keys rather than English prose precisely so
  /// that this can happen — "auth.codeExpired" becomes the Urdu sentence when
  /// the app is in Urdu. A message that is not a key falls through to the
  /// shared handler, and an unrecognised key never reaches the screen as a
  /// key: `t()` returns the key itself when it does not know it, which is how
  /// "auth.somethingNew" would end up printed on a patient's phone.
  String _readable(Object error) {
    final l10n = context.read<LocaleController>();

    if (error is ApiException) {
      final key = error.message.trim();
      if (key.startsWith('auth.') || key.startsWith('common.')) {
        final text = l10n.t(key);
        if (text != key) return text;
        return l10n.t('common.somethingWrong');
      }
    }
    return errorText(error);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final codeStage = _sentTo != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.t('auth.signIn')} — ${l10n.t('auth.withPhone')}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
          children: [
            if (!codeStage) ...[
              Text(
                l10n.t('auth.phoneHelp'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.t('auth.phone'),
                  hintText: '0310 040 4444',
                  prefixIcon: const Icon(Icons.smartphone_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: '${l10n.t('auth.name')} (${l10n.t('common.optional')})',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                ),
              ),
            ] else ...[
              Text(
                '${l10n.t('auth.codeSentTo')} ${Fmt.phone(_sentTo)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 22, letterSpacing: 8),
                textAlign: TextAlign.center,
                onSubmitted: (_) => _verify(),
                decoration: InputDecoration(
                  labelText: l10n.t('auth.enterCode'),
                  counterText: '',
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Palette.dangerSoft,
                  borderRadius: BorderRadius.circular(Palette.radiusSm),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Palette.crimsonDeep,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : (codeStage ? _verify : _sendCode),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Palette.paper),
                        ),
                      )
                    : Text(codeStage ? l10n.t('auth.verify') : l10n.t('auth.sendCode')),
              ),
            ),

            if (codeStage) ...[
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          // Back to the number, not a silent re-send.
                          // Twilio counts sends per number and refuses after a
                          // few, so a button that quietly fires another one is
                          // a button that locks the patient out of their own
                          // sign-in. They confirm the number and press send.
                          setState(() {
                            _sentTo = null;
                            _code.clear();
                            _error = null;
                          });
                        },
                  child: Text(l10n.t('auth.resend')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
