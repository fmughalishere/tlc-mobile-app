import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/repository.dart';
import '../i18n/strings.dart';

/// What came of a sign-in through Google or Apple.
///
/// Shared by both, because after the provider sheet closes the two flows are
/// the same flow: a Firebase user exists, and it may or may not have a
/// `users/{uid}` profile behind it yet.
class SocialAuthResult {
  const SocialAuthResult({
    required this.cancelled,
    this.createdAccount = false,
    this.doctorPending = false,
  });

  /// The person closed the provider's sheet. Not an error, and nothing should
  /// be shown for it — they simply changed their mind.
  final bool cancelled;

  /// A profile document was written for the first time.
  final bool createdAccount;

  /// They asked to join as a doctor, and that request is now waiting for an
  /// admin.
  final bool doctorPending;
}

/// Makes sure a freshly signed-in social account has a profile behind it.
///
/// ── Why the existence check comes first ──
///
/// `POST /api/auth/register` refuses to overwrite an existing profile today,
/// but the check reads the user's own document directly from Firestore, as
/// the website does, so that a returning doctor is never even offered to the
/// register route as a "new patient". It is one small read against a document
/// the rules already let this person see.
///
/// [name] is whatever the provider told us. Apple gives a name only on the
/// very first sign-in with this app and never again, so the caller passes it
/// in the moment it has it. When there is none, the email prefix stands in,
/// and failing that the plain word "Patient" — the register route refuses an
/// empty name, and a blank name is worse than a placeholder the person can
/// edit from their profile.
Future<SocialAuthResult> ensureProfileAfterSignIn({
  required Repository repository,
  required User user,
  String? name,
  String? email,
  String role = 'patient',
  String? specialization,
}) async {
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
    debugPrint('[auth] profile check failed: $error');
    exists = true;
  }

  if (exists) {
    return const SocialAuthResult(cancelled: false);
  }

  final resolvedEmail = (email ?? '').trim().isNotEmpty
      ? email!.trim()
      : (user.email ?? '').trim();

  final pending = await repository.registerProfile(
    uid: user.uid,
    name: _bestName(name, user.displayName, resolvedEmail),
    email: resolvedEmail.isEmpty ? null : resolvedEmail,
    phone: user.phoneNumber,
    role: role,
    specialization: specialization,
  );

  // The token in hand was minted a second ago, before the role claim existed.
  // Without forcing a refresh the very next API call goes out claim-less and
  // comes back 403 — which looks, from the outside, exactly like a broken
  // sign-in.
  await user.getIdToken(true);

  return SocialAuthResult(
    cancelled: false,
    createdAccount: true,
    doctorPending: pending,
  );
}

String _bestName(String? given, String? displayName, String email) {
  final fromProvider = (given ?? '').trim();
  if (fromProvider.isNotEmpty) return fromProvider;
  final fromFirebase = (displayName ?? '').trim();
  if (fromFirebase.isNotEmpty) return fromFirebase;
  final prefix = email.split('@').first.trim();
  // Apple's "hide my email" relay addresses have a random prefix that is no
  // one's name; the plain word reads better than a string of letters.
  if (prefix.isNotEmpty && !email.endsWith('privaterelay.appleid.com')) {
    return prefix;
  }
  return LocaleController.tr('profile.unnamedPatient');
}
