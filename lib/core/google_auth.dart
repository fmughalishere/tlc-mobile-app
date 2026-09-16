import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../i18n/strings.dart';

import '../data/repository.dart';

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
class GoogleAuthResult {
  const GoogleAuthResult({
    required this.cancelled,
    this.createdAccount = false,
    this.doctorPending = false,
  });

  /// The person closed the Google sheet. Not an error, and nothing should be
  /// shown for it — they simply changed their mind.
  final bool cancelled;

  /// A profile document was written for the first time.
  final bool createdAccount;

  /// They asked to join as a doctor, and that request is now waiting for an
  /// admin. The screen says so; there is nothing useful behind the dashboard
  /// until somebody approves it.
  final bool doctorPending;
}

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
    return const GoogleAuthResult(cancelled: true);
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

  // Does this person already exist here?
  var exists = false;
  try {
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    exists = snap.exists;
  } catch (error) {
    // The read failed — offline, or rules refused it. Assume they exist and do
    // nothing: not writing a profile leaves an account that can be repaired on
    // the next launch, whereas writing one over a doctor's record cannot be
    // undone.
    debugPrint('[google] profile check failed: $error');
    exists = true;
  }

  if (exists) {
    return const GoogleAuthResult(cancelled: false);
  }

  final pending = await repository.registerProfile(
    uid: user.uid,
    name: (user.displayName ?? '').trim().isEmpty
        ? (account.email.split('@').first)
        : user.displayName!.trim(),
    email: user.email ?? account.email,
    phone: user.phoneNumber,
    role: role,
    specialization: specialization,
  );

  // The token in hand was minted a second ago, before the role claim existed.
  // Without forcing a refresh the very next API call goes out claim-less and
  // comes back 403 — which looks, from the outside, exactly like a broken
  // sign-in.
  await user.getIdToken(true);

  return GoogleAuthResult(
    cancelled: false,
    createdAccount: true,
    doctorPending: pending,
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
