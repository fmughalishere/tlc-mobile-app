import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../data/repository.dart';
import '../i18n/strings.dart';
import 'account_setup.dart';

/// "Sign in with Apple", on iOS only.
///
/// App Review Guideline 4.8: an app that offers Google sign-in must offer this
/// too. Android users keep Google, email and phone; showing an Apple button
/// there would open a web sheet most of them have no account for.
///
/// ── Why the package and not `signInWithProvider(AppleAuthProvider())` ──
///
/// The Firebase-only route is shorter, but it does not hand back the name.
/// Apple tells an app the person's name exactly once — on the very first
/// sign-in — and never again, not even after a reinstall. Missing it there
/// means the profile is created as "Patient" forever. `sign_in_with_apple`
/// returns `givenName`/`familyName` on that first sign-in, which is the whole
/// reason for the extra nonce handling below.
bool get appleSignInAvailable => !kIsWeb && Platform.isIOS;

/// Signs in with Apple and makes sure a profile exists behind it.
///
/// Mirrors `signInWithGoogle`: a cancel comes back as a result, a real
/// failure throws. After Firebase has the user, the rest — the profile
/// check, the register call, the token refresh — is the same shared step
/// Google uses, `ensureProfileAfterSignIn`.
Future<SocialAuthResult> signInWithApple({
  required Repository repository,
  String role = 'patient',
  String? specialization,
}) async {
  // Firebase checks that the SHA-256 of `rawNonce` is the nonce Apple signed
  // into the identity token — which is what stops a token lifted from one
  // sign-in being replayed into another.
  final rawNonce = _randomNonce();
  final hashedNonce = await _sha256Hex(rawNonce);

  final apple = await _appleCredential(hashedNonce);
  if (apple == null) return const SocialAuthResult(cancelled: true);

  final idToken = apple.identityToken;
  if (idToken == null) {
    throw FirebaseAuthException(
      code: 'no-user',
      message: LocaleController.tr('auth.appleFailed'),
    );
  }

  final credential = OAuthProvider('apple.com').credential(
    idToken: idToken,
    rawNonce: rawNonce,
    accessToken: apple.authorizationCode,
  );

  final result = await _firebaseSignIn(credential);
  if (result == null) return const SocialAuthResult(cancelled: true);

  final user = result.user;
  if (user == null) {
    throw FirebaseAuthException(
      code: 'no-user',
      message: LocaleController.tr('auth.appleFailed'),
    );
  }

  // Only present on the first sign-in. Kept on the Firebase user as well as
  // sent to the profile, so a later repair of a missing profile still has it.
  final fullName = [apple.givenName, apple.familyName]
      .where((part) => part != null && part.trim().isNotEmpty)
      .map((part) => part!.trim())
      .join(' ');
  if (fullName.isNotEmpty && (user.displayName ?? '').trim().isEmpty) {
    try {
      await user.updateDisplayName(fullName);
    } catch (error) {
      debugPrint('[apple] could not store the name: $error');
    }
  }

  return ensureProfileAfterSignIn(
    repository: repository,
    user: user,
    name: fullName.isNotEmpty ? fullName : user.displayName,
    email: apple.email ?? user.email,
    role: role,
    specialization: specialization,
  );
}

/// True when the signed-in account came in through Apple.
bool get signedInWithApple =>
    FirebaseAuth.instance.currentUser?.providerData
        .any((info) => info.providerId == 'apple.com') ??
    false;

/// Before an Apple account is deleted, tells Apple to forget this app.
///
/// Apple asks apps that offer its sign-in to revoke the user's tokens when
/// the account is closed, so "Apps using Apple ID" in the person's settings
/// stops listing the clinic. Revoking needs a fresh authorisation code, which
/// means one more Apple sheet.
///
/// Returns false if the person cancelled that sheet — the caller treats that
/// as "changed my mind" and stops. Any other failure is logged and swallowed:
/// the account is still deleted, and a leftover Apple link is not a reason to
/// refuse somebody who asked to leave.
Future<bool> revokeAppleSignIn() async {
  if (!appleSignInAvailable || !signedInWithApple) return true;
  try {
    final apple = await SignInWithApple.getAppleIDCredential(scopes: const []);
    await FirebaseAuth.instance
        .revokeTokenWithAuthorizationCode(apple.authorizationCode);
  } on SignInWithAppleAuthorizationException catch (e) {
    if (e.code == AuthorizationErrorCode.canceled) return false;
    debugPrint('[apple] revoke failed: $e');
  } catch (error) {
    debugPrint('[apple] revoke failed: $error');
  }
  return true;
}

/// Apple's sheet; null when the person closed it.
Future<AuthorizationCredentialAppleID?> _appleCredential(String hashedNonce) async {
  try {
    return await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
  } on SignInWithAppleAuthorizationException catch (e) {
    if (e.code == AuthorizationErrorCode.canceled) return null;
    rethrow;
  }
}

/// Firebase's half; null when it reports a cancel of its own.
Future<UserCredential?> _firebaseSignIn(AuthCredential credential) async {
  try {
    return await FirebaseAuth.instance.signInWithCredential(credential);
  } on FirebaseAuthException catch (e) {
    if (e.code == 'canceled' || e.code == 'web-context-canceled') return null;
    rethrow;
  }
}

String _randomNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)])
      .join();
}

Future<String> _sha256Hex(String input) async {
  final hash = await Sha256().hash(utf8.encode(input));
  return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
