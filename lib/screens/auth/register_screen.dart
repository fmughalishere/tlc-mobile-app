import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/google_auth.dart';
import '../../core/palette.dart';
import '../../data/repository.dart';
import '../../i18n/strings.dart';
import '../../widgets/common.dart';

/// Creating an account — as a patient, or as a doctor asking to join.
///
/// ── Why one screen and not two ──
///
/// It is the same form. The website's /register page works exactly this way:
/// a patient/doctor switch at the top, one extra field when "doctor" is
/// chosen, and the same two steps underneath. Splitting it would mean two
/// screens that must agree with each other forever.
///
/// ── The two steps ──
///
///   1. Firebase Auth creates the credential — that is what a token is
///      minted from.
///   2. POST /api/auth/register writes `users/{uid}` and sets the role claim.
///
/// Step 2 is not optional. Without it the person is signed in but has no
/// profile document, which is exactly the state `Session` reports as role
/// "unknown" — signed in, and able to see nothing.
///
/// ── What "doctor" actually does ──
///
/// It does not make a doctor. It files an application: the server writes the
/// account with `approvalStatus: "pending"` and `active: false`, and an admin
/// approves it from Admin → Doctors before the account can see a single
/// patient. The screen says so plainly, because someone who taps "I'm a
/// doctor" and lands on an empty dashboard will assume the app is broken
/// rather than that they are waiting.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _specialization = TextEditingController();

  final _repo = Repository();

  AccountRole _role = AccountRole.patient;
  bool _busy = false;
  bool _google = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  bool get _isDoctor => _role == AccountRole.doctor;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _specialization.dispose();
    _repo.close();
    super.dispose();
  }

  // ── Creating the account ──────────────────────────────────────────────────

  Future<void> _submit() async {
    final l10n = context.read<LocaleController>();
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final rawPhone = _phone.text.trim();

    if (name.isEmpty) {
      setState(() => _error = l10n.t('auth.needName'));
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = l10n.t('auth.needEmail'));
      return;
    }
    if (password.length < 6) {
      setState(() => _error = l10n.t('auth.needPassword'));
      return;
    }
    // Typed twice on purpose. A password is invisible while it is being typed,
    // and a mistyped one on a new account cannot be recovered by remembering
    // what was meant — only by a reset email.
    if (_confirm.text != password) {
      setState(() => _error = l10n.t('auth.passwordsDontMatch'));
      return;
    }

    // A phone number is optional for a patient, but if one is typed it has to
    // be real — the clinic calls it to confirm every unpaid booking. For a
    // doctor it is not optional at all: the clinic has to be able to reach the
    // person it is about to give patient records to.
    String? phone;
    if (rawPhone.isNotEmpty) {
      phone = Fmt.toE164(rawPhone);
      if (phone == null) {
        setState(() => _error = l10n.t('auth.needPhone'));
        return;
      }
    } else if (_isDoctor) {
      setState(() => _error = l10n.t('auth.needPhone'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) {
        // `l10n`, not `context.read(...)`. This line sits after an await, and
        // reaching through a BuildContext across an async gap is how a widget
        // that has been disposed in the meantime throws instead of showing the
        // message it was asked to show. The dictionary was read at the top of
        // this method, before any awaiting began.
        throw Exception(l10n.t('auth.noUserReturned'));
      }

      await user.updateDisplayName(name);

      // The token was just minted, so it does not yet carry the role claim the
      // API will set a moment from now. That is fine: /api/auth/register does
      // not check a role, it assigns one.
      final pending = await _repo.registerProfile(
        uid: user.uid,
        name: name,
        email: email,
        phone: phone,
        role: _isDoctor ? 'doctor' : 'patient',
        specialization: _specialization.text,
      );

      // Force a token refresh so the *next* call carries the role. Without
      // this the first request after signing up is made with a claim-less
      // token and comes back 403.
      await user.getIdToken(true);

      // The verification email goes out here, at the one moment we know the
      // address was just typed and the person is still holding the phone.
      // Its failure is not the account's failure: the account exists, and the
      // screen they land on has a "send it again" button, so a dropped
      // connection at this exact second costs one tap, not a sign-up.
      try {
        await user.sendEmailVerification();
      } catch (error) {
        debugPrint('[register] verification email failed: $error');
      }

      if (!mounted) return;
      if (pending) showToast(context, l10n.t('auth.doctorPending'));
      // Nothing to navigate: the gate sees an unverified new account and puts
      // the "check your inbox" screen up by itself.
      widget.onDone?.call();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _readable(e));
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The same account, made with Google instead of a password.
  ///
  /// The role switch above still applies: tapping this with "I'm a doctor"
  /// selected files the same application, with the name and email coming from
  /// the Google account rather than from the form.
  Future<void> _continueWithGoogle() async {
    final l10n = context.read<LocaleController>();
    setState(() {
      _google = true;
      _error = null;
    });
    try {
      final result = await signInWithGoogle(
        repository: _repo,
        role: _isDoctor ? 'doctor' : 'patient',
        specialization: _specialization.text,
      );
      if (result.cancelled) return;
      if (!mounted) return;
      if (result.doctorPending) showToast(context, l10n.t('auth.doctorPending'));
      widget.onDone?.call();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _readable(e));
    } catch (e) {
      if (mounted) setState(() => _error = _googleMessage(e));
    } finally {
      if (mounted) setState(() => _google = false);
    }
  }

  /// Google's own failures are terse and numeric. `sign_in_failed … 10` is the
  /// famous one and it means exactly one thing: this build's signing
  /// fingerprint is not registered in the Firebase project. Saying that
  /// plainly is the difference between a five-minute fix and an afternoon.
  String _googleMessage(Object error) {
    final text = error.toString();
    if (text.contains('sign_in_failed') || text.contains('ApiException: 10')) {
      return context.read<LocaleController>().t('auth.googleNotSetUp');
    }
    if (text.contains('network')) return context.read<LocaleController>().t('common.offline');
    return context.read<LocaleController>().t('auth.googleFailed');
  }

  String _readable(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return context.read<LocaleController>().t('auth.emailInUse');
      case 'invalid-email':
        return context.read<LocaleController>().t('auth.invalidEmail');
      case 'weak-password':
        return context.read<LocaleController>().t('auth.needPassword');
      case 'network-request-failed':
        return context.read<LocaleController>().t('common.offline');
      default:
        // Firebase's own `message` is English developer prose — not
        // something to put in front of a patient reading Urdu.
        return context.read<LocaleController>().t('auth.registerFailed');
    }
  }

  // ── Screen ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final working = _busy || _google;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('auth.createAccount'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
          children: [
            // ── Who is signing up ──
            RoleSwitch(
              role: _role,
              enabled: !working,
              onChanged: (r) => setState(() {
                _role = r;
                _error = null;
              }),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.t(_isDoctor ? 'auth.doctorIntro' : 'auth.patientIntro'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            if (_isDoctor) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Palette.warningSoft,
                  borderRadius: BorderRadius.circular(Palette.radiusSm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: Palette.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.t('auth.doctorNeedsEmail'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Palette.warning,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),

            TextField(
              controller: _name,
              enabled: !working,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.t('auth.name'),
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              enabled: !working,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l10n.t('auth.email'),
                prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              enabled: !working,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: _isDoctor
                    ? l10n.t('auth.phone')
                    : '${l10n.t('auth.phone')} (${l10n.t('common.optional')})',
                hintText: '0310 040 4444',
                prefixIcon: const Icon(Icons.call_outlined, size: 20),
              ),
            ),

            // Only a doctor is asked this, and it is the one field an admin
            // reads before approving — so it sits with the rest of the form
            // rather than being buried in settings afterwards.
            if (_isDoctor) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _specialization,
                enabled: !working,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText:
                      '${l10n.t('profile.specialization')} (${l10n.t('common.optional')})',
                  hintText: l10n.t('auth.specializationHint'),
                  prefixIcon:
                      const Icon(Icons.medical_information_outlined, size: 20),
                ),
              ),
            ],

            const SizedBox(height: 12),
            TextField(
              controller: _password,
              enabled: !working,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              textDirection: TextDirection.ltr,
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
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              enabled: !working,
              obscureText: _obscureConfirm,
              textDirection: TextDirection.ltr,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.t('auth.confirmPassword'),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),

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
                  style: const TextStyle(color: Palette.crimsonDeep, fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: working ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Palette.paper),
                        ),
                      )
                    : Text(l10n.t('auth.createAccount')),
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

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.t('auth.haveAccount'),
                  style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
                ),
                TextButton(
                  onPressed: working ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.t('auth.signIn')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
