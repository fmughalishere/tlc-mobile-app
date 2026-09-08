import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../widgets/common.dart';
import 'phone_login_screen.dart';
import 'register_screen.dart';

/// Signing in.
///
/// Two ways in, because the clinic's patients arrive with two different
/// things: some made an account on the website with an email, and many have
/// only a phone number. The website supports both, so the app has to as well —
/// an app that can only do email would lock out the people most likely to use
/// a phone app.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onDone});

  /// Called after a successful sign-in when this screen was pushed on top of
  /// something (booking, say) rather than shown as the app's root.
  final VoidCallback? onDone;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = context.l10n.t('auth.needEmail'));
      return;
    }
    if (password.length < 6) {
      setState(() => _error = context.l10n.t('auth.needPassword'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      // Nothing to do on success: Session is listening to authStateChanges and
      // the gate above this screen swaps it out. Navigating from here as well
      // would race that and pop a screen that has already been replaced.
      if (mounted) widget.onDone?.call();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _readable(e));
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = context.l10n.t('auth.needEmail'));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) showToast(context, context.l10n.t('auth.resetSent'));
    } on FirebaseAuthException catch (e) {
      if (mounted) showToast(context, _readable(e), error: true);
    }
  }

  /// Firebase's codes turned into something a patient can act on.
  ///
  /// `invalid-credential` deliberately does not say which half was wrong.
  /// Firebase stopped distinguishing them on purpose — telling a stranger
  /// "that email exists but the password is wrong" tells them the email
  /// exists.
  String _readable(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'user-disabled':
        return context.l10n.t('auth.blocked');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes.';
      case 'network-request-failed':
        return context.l10n.t('common.offline');
      default:
        return e.message ?? 'Could not sign you in.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('auth.signIn')),
        actions: [
          TextButton(
            onPressed: l10n.toggle,
            child: Text(l10n.isUrdu ? 'English' : 'اردو'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          children: [
            Center(
              child: Image.asset(
                'assets/images/logo-icon.png',
                height: 84,
                errorBuilder: (_, __, ___) => const SizedBox(height: 84),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.t('auth.welcome'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.t('auth.welcomeSub'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 26),

            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              // The field holds an email address, which is Latin text even for
              // an Urdu reader — forcing LTR here stops the cursor and the
              // "@" from jumping to the wrong end.
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l10n.t('auth.email'),
                prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              textDirection: TextDirection.ltr,
              onSubmitted: (_) => _signIn(),
              decoration: InputDecoration(
                labelText: l10n.t('auth.password'),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),

            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _busy ? null : _resetPassword,
                child: Text(l10n.t('auth.forgot')),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Palette.dangerSoft,
                  borderRadius: BorderRadius.circular(Palette.radiusSm),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Palette.crimsonDeep, fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _signIn,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Palette.paper),
                        ),
                      )
                    : Text(l10n.t('auth.signIn')),
              ),
            ),

            const SizedBox(height: 18),
            Row(
              children: const [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: TextStyle(color: Palette.inkSoft, fontSize: 12)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PhoneLoginScreen(onDone: widget.onDone),
                          ),
                        ),
                icon: const Icon(Icons.smartphone_rounded, size: 19),
                label: Text('${l10n.t('auth.signIn')} — ${l10n.t('auth.withPhone')}'),
              ),
            ),

            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.t('auth.noAccount'),
                  style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => RegisterScreen(onDone: widget.onDone),
                            ),
                          ),
                  child: Text(l10n.t('auth.createAccount')),
                ),
              ],
            ),

            const SizedBox(height: 6),
            Center(
              // The clinic's number is on the sign-in screen deliberately:
              // this is the one place a patient may need a human *before* the
              // app can do anything for them.
              child: TextButton.icon(
                onPressed: () => dialClinic(context),
                icon: const Icon(Icons.call_outlined, size: 18),
                label: Text(
                  '${l10n.t('common.callClinic')} · ${Fmt.phone(AppConfig.clinicPhoneE164)}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
