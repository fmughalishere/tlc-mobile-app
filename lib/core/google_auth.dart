import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../i18n/strings.dart';

import '../data/repository.dart';
import 'account_setup.dart';

/// "Continue with Google", shared by the sign-in and the create-account
/// screens.
///
/// ── Why this is one function and not two ──
///
/// On the website, /login and /register both have a Google button and they do
/// almost the same thing: sign in with Google, then — only if this Google
/// account has never been here before — write the `users/{uid}` document. The
/// single difference is what role that new document gets, and that is a
/// parameter, not a second copy of the flow.
///
/// The check for "never been here before" reads the user's own document
/// directly from Firestore, exactly as the website does. It is one small read
/// against a document the rules already let this person see, and it is what
/// stops a returning doctor from being quietly re-registered as a patient:
/// `POST /api/auth/register` **overwrites** the document rather than merging
/// into it, so calling it for somebody who already exists would erase their
/// role, their approval and the date they joined.
///
/// Kept as a name so older call sites read the same. The result, and the
/// whole post-sign-in step, is shared with "Sign in with Apple" — see
/// core/account_setup.dart.
typedef GoogleAuthResult = SocialAuthResult;

/// Signs in with Google and makes sure a profile exists behind it.
///
/// Throws on a real failure. A cancelled sign-in comes back as a result, not
/// an exception, because "I changed my mind" is not a problem to report.
Future<GoogleAuthResult> signInWithGoogle({
  required Repository repository,
  String role = 'patient',
  String? specialization,
}) async {
  // `scopes` is deliberately just the two the sign-in itself needs. Asking for
  // more — contacts, calendar — would make Google show a longer, scarier
  // consent screen for permissions the clinic has no use for.
  final google = GoogleSignIn(scopes: const ['email', 'profile']);

  final account = await google.signIn();
  if (account == null) {
    return const SocialAuthResult(cancelled: true);
  }

  final auth = await account.authentication;
  final credential = GoogleAuthProvider.credential(
    accessToken: auth.accessToken,
    idToken: auth.idToken,
  );

  final result = await FirebaseAuth.instance.signInWithCredential(credential);
  final user = result.user;
  if (user == null) {
    throw FirebaseAuthException(
      code: 'no-user',
      message: LocaleController.tr('auth.googleNoAccount'),
    );
  }

  return ensureProfileAfterSignIn(
    repository: repository,
    user: user,
    name: user.displayName,
    email: user.email ?? account.email,
    role: role,
    specialization: specialization,
  );
}

/// Clears the Google session too, so the next "Continue with Google" shows the
/// account chooser instead of silently signing the last person back in. On a
/// shared or family phone that is the difference between signing out and
/// appearing to sign out.
Future<void> signOutFromGoogle() async {
  try {
    await GoogleSignIn().signOut();
  } catch (error) {
    debugPrint('[google] sign-out failed: $error');
  }
}
