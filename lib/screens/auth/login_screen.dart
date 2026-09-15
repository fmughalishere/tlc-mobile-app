import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../core/google_auth.dart';
import '../../core/palette.dart';
import '../../core/session.dart';
import '../../data/repository.dart';
import '../../i18n/strings.dart';
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
  final _repo = Repository();

  /// Which door they think they are coming through.
  ///
  /// It is worth being clear about what this does and does not do. The role
  /// lives on the account, not on this screen — a patient who taps "I'm a
  /// doctor" is still a patient, and no switch here could change that without
  /// being a security hole. What it does is set expectations, and catch the
  /// mistake out loud: if the account turns out to be something else, the app
  /// says so before it takes them somewhere they were not expecting.
  AccountRole _role = AccountRole.patient;

  bool _busy = false;
  bool _google = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _repo.close();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = context.read<LocaleController>().t('auth.needEmail'));
      return;
    }
    if (password.length < 6) {
      setState(() => _error = context.read<LocaleController>().t('auth.needPassword'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      await _sayIfRoleDiffers(credential.user?.uid);
      // Nothing else to do on success: Session is listening to
      // authStateChanges and the gate above this screen swaps it out.
      // Navigating from here as well would race that and pop a screen that
      // has already been replaced.
      if (mounted) widget.onDone?.call();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _readable(e));
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Says so, out loud, when the account is not the kind they picked.
  ///
  /// The switch above the form is a statement of expectation, and the honest
  /// thing to do with an expectation that turns out to be wrong is to name it.
  /// Without this, a doctor who left the switch on "patient" would simply find
  /// themselves in the doctor app with no explanation, and would reasonably
  /// wonder whether the switch had done something they did not intend.
  ///
  /// The message is a toast rather than a dialog because it is information,
  /// not a decision — there is nothing for them to do about it, and the app is
  /// already taking them to the right place. `ScaffoldMessenger` lives above
  /// the gate, so the toast survives this screen being swapped out from under
  /// it a frame later.
  Future<void> _sayIfRoleDiffers(String? uid) async {
    if (uid == null) return;
    final l10n = context.read<LocaleController>();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 6));
      final actual = roleFrom(snap.data()?['role']);

      // An unknown role means the profile has not arrived or has none on it.
      // Saying nothing is right: the app already treats that as "patient for
      // now", and announcing a role we are not sure of would be worse than
      // saying nothing at all.
      if (actual == Role.unknown) return;

      final expected =
          _role == AccountRole.doctor ? Role.doctor : Role.patient;
      if (actual == expected) return;

      if (!mounted) return;
      showToast(
        context,
        switch (actual) {
          Role.doctor => l10n.t('auth.roleDoctorActually'),
          Role.admin => l10n.t('auth.roleAdminActually'),
          _ => l10n.t('auth.rolePatientActually'),
        },
      );
    } catch (error) {
      // Purely cosmetic, so a failure here must never fail the sign-in. They
      // are already in; the gate will route them correctly regardless.
      debugPrint('[login] role check failed: $error');
    }
  }

  /// Google, on the sign-in screen.
  ///
  /// A Google account that has never been here before is created as a patient,
  /// which is what the website does from this same button. Someone applying to
  /// join as a doctor goes through Create account, where they can say so and
  /// give a specialisation — an application, not a sign-in.
  Future<void> _continueWithGoogle() async {
    setState(() {
      _google = true;
      _error = null;
    });
    try {
      final result = await signInWithGoogle(repository: _repo);
      if (result.cancelled) return;
      if (!mounted) return;
      // Nothing to navigate here either: Session hears the auth change and the
      // gate replaces this screen.
      widget.onDone?.call();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _readable(e));
    } catch (e) {
      if (mounted) {
        setState(() => _error = _googleMessage(e));
      }
    } finally {
      if (mounted) setState(() => _google = false);
    }
  }

  /// Google's own failures are terse and numeric — `PlatformException(sign_in
  /// _failed, ..., 10, null)` is the famous one, and it means exactly one
  /// thing: this build's signing fingerprint is not registered in the Firebase
  /// project. Saying that plainly is the difference between a five-minute fix
  /// and an afternoon.
  String _googleMessage(Object error) {
    final text = error.toString();
    if (text.contains('sign_in_failed') || text.contains('ApiException: 10')) {
      return 'Google sign-in is not set up for this build yet — the app\'s '
          'SHA-1 fingerprint needs adding in the Firebase console.';
    }
    if (text.contains('network')) return context.read<LocaleController>().t('common.offline');
    return context.read<LocaleController>().t('auth.googleFailed');
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = context.read<LocaleController>().t('auth.needEmail'));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) showToast(context, context.read<LocaleController>().t('auth.resetSent'));
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
        return context.read<LocaleController>().t('auth.blocked');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes.';
      case 'network-request-failed':
        return context.read<LocaleController>().t('common.offline');
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
              l10n.t(_role == AccountRole.doctor
                  ? 'auth.doctorLoginIntro'
                  : 'auth.welcomeSub'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 20),
            RoleSwitch(
              role: _role,
              enabled: !(_busy || _google),
              onChanged: (r) => setState(() {
                _role = r;
                _error = null;
              }),
            ),
            const SizedBox(height: 22),

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
                onPressed: (_busy || _google) ? null : _resetPassword,
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
                onPressed: (_busy || _google) ? null : _signIn,
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
            OrDivider(label: l10n.t('auth.or')),
            const SizedBox(height: 18),

            GoogleButton(
              busy: _google,
              onPressed: _busy ? null : _continueWithGoogle,
              label: l10n.t('auth.continueWithGoogle'),
            ),

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_busy || _google)
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
                  onPressed: (_busy || _google)
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
