import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/repository.dart';
import '../../widgets/common.dart';

/// Signing in with a phone number and a 6-digit code.
///
/// ── The one thing that will bite ──
///
/// Android will refuse to send the SMS until the app's SHA-1 and SHA-256
/// fingerprints are registered in the Firebase console. It is not a code
/// problem and there is nothing to fix in this file when it happens: Firebase
/// verifies the app itself before it will spend an SMS on it, and an
/// unregistered build fails that check. The error it returns is
/// `app-not-authorized`, and this screen says so in plain words rather than
/// showing "an error occurred" — because the fix is a two-minute change in the
/// console, and only if someone knows that is what is wrong.
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

  String? _verificationId;
  String? _sentTo;
  int? _resendToken;
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
    final e164 = Fmt.toE164(_phone.text);
    if (e164 == null) {
      setState(() => _error = context.l10n.t('auth.needPhone'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: e164,
        forceResendingToken: _resendToken,

        // Android can read the SMS itself and sign in without the patient
        // typing anything. When that happens there is no code to enter, so
        // this path completes the sign-in directly.
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            await _ensureProfile(e164);
            if (mounted) widget.onDone?.call();
          } catch (e) {
            if (mounted) setState(() => _error = errorText(e));
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          if (mounted) setState(() => _error = _readable(e));
        },

        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _sentTo = e164;
          });
        },

        // Only the auto-retrieval window lapsing. The code is still valid and
        // the patient can still type it, so this is deliberately not an error.
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) setState(() => _verificationId = verificationId);
        },

        timeout: const Duration(seconds: 60),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _readable(e));
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final id = _verificationId;
    final code = _code.text.trim();
    if (id == null) return;
    if (code.length < 6) {
      setState(() => _error = context.l10n.t('auth.enterCode'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final credential =
          PhoneAuthProvider.credential(verificationId: id, smsCode: code);
      await FirebaseAuth.instance.signInWithCredential(credential);
      await _ensureProfile(_sentTo ?? '');
      if (mounted) widget.onDone?.call();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _readable(e));
    } catch (e) {
      setState(() => _error = errorText(e));
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

  String _readable(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return context.l10n.t('auth.needPhone');
      case 'invalid-verification-code':
        return 'That code is not right. Check it and try again.';
      case 'session-expired':
        return 'That code has expired. Ask for a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes.';
      case 'network-request-failed':
        return context.l10n.t('common.offline');
      case 'app-not-authorized':
      case 'missing-client-identifier':
        // The precise wording matters here: without it this reads as a bug in
        // the app, and someone spends an afternoon in Dart code looking for it.
        return 'This build is not yet registered for SMS sign-in. '
            'The app\'s SHA-1 and SHA-256 fingerprints need adding to the '
            'Firebase console. Use email sign-in in the meantime.';
      case 'billing-not-enabled':
        return 'SMS sign-in is not enabled on the Firebase project yet.';
      default:
        return e.message ?? 'Could not send the code.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final codeStage = _verificationId != null;

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
                          setState(() {
                            _verificationId = null;
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
