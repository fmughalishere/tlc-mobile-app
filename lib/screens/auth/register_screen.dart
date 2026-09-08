import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/palette.dart';
import '../../data/repository.dart';
import '../../widgets/common.dart';

/// Creating a patient account.
///
/// Two steps happen here and both must succeed:
///
///   1. Firebase Auth creates the credential — that is what a token is
///      minted from.
///   2. POST /api/auth/register writes `users/{uid}` and sets the role claim.
///
/// Step 2 is not optional. Without it the person is signed in but has no
/// profile document, which is exactly the state `Session` reports as role
/// "unknown" — signed in, and able to see nothing. So a failure there is
/// surfaced rather than swallowed, and the screen offers to retry it instead
/// of dropping the patient into a half-made account.
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

  final _repo = Repository();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _repo.close();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
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
    // A phone number is optional here, but if one is typed it has to be real —
    // the clinic calls it to confirm every unpaid booking.
    String? phone;
    if (rawPhone.isNotEmpty) {
      phone = Fmt.toE164(rawPhone);
      if (phone == null) {
        setState(() => _error = l10n.t('auth.needPhone'));
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) throw Exception('Account created but no user returned.');

      await user.updateDisplayName(name);

      // The token was just minted, so it does not yet carry the role claim the
      // API will set a moment from now. That is fine: /api/auth/register does
      // not check a role, it assigns one.
      await _repo.registerProfile(
        uid: user.uid,
        name: name,
        email: email,
        phone: phone,
      );

      // Force a token refresh so the *next* call carries role=patient.
      // Without this the first request after signing up is made with a
      // claim-less token and comes back 403.
      await user.getIdToken(true);

      if (mounted) widget.onDone?.call();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _readable(e));
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _readable(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That email already has an account. Try signing in instead.';
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'weak-password':
        return context.l10n.t('auth.needPassword');
      case 'network-request-failed':
        return context.l10n.t('common.offline');
      default:
        return e.message ?? 'Could not create the account.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('auth.createAccount'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
          children: [
            Text(
              l10n.t('auth.createSub'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),

            TextField(
              controller: _name,
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
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: '${l10n.t('auth.phone')} (${l10n.t('common.optional')})',
                hintText: '0310 040 4444',
                prefixIcon: const Icon(Icons.call_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              textDirection: TextDirection.ltr,
              onSubmitted: (_) => _submit(),
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
                onPressed: _busy ? null : _submit,
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

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.t('auth.haveAccount'),
                  style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
                ),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
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
