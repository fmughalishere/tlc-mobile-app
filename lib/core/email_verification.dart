import 'package:firebase_auth/firebase_auth.dart';

import 'config.dart';

/// Whether this account has to prove it owns its email address before the app
/// will let it through.
///
/// Four things have to be true, and each exclusion is deliberate:
///
///   · **There is an email.** An account made with a phone number and a
///     6-digit code has none. There is nothing to verify and nothing to send,
///     and the number was already proved by the code itself.
///
///   · **It is not already verified.** Google says so for its own accounts on
///     the way in, which is why a "Continue with Google" account never sees
///     this screen: Google has already done the check, and asking again would
///     be asking the patient to prove something the app was just told.
///
///   · **There is a password sign-in on the account.** That is the only way in
///     where an unproved address can be typed, because it is the only one that
///     does not involve the address or the number answering back.
///
///   · **The account was made on or after the cut-off.** See
///     `AppConfig.verifyEmailFrom` — the rule is for accounts made from here
///     on, not for the people who signed up on the website years ago under a
///     form that never asked.
///
/// A missing creation time means "do not lock anybody out": the check errs
/// towards letting a real patient in, because the cost of wrongly blocking
/// somebody who needs a doctor is not the same as the cost of wrongly letting
/// one unverified address through.
bool needsEmailVerification(User? user) {
  if (user == null) return false;
  if (user.emailVerified) return false;

  final email = user.email;
  if (email == null || email.trim().isEmpty) return false;

  final hasPassword =
      user.providerData.any((provider) => provider.providerId == 'password');
  if (!hasPassword) return false;

  final created = user.metadata.creationTime;
  if (created == null) return false;

  return !created.toUtc().isBefore(AppConfig.verifyEmailFrom);
}
