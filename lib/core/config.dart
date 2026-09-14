/// Where the app points, and the few things that differ between builds.
///
/// `--dart-define` rather than a checked-in file, so that a debug build can be
/// aimed at a laptop on the same wifi without editing source and without that
/// edit ever being committed by accident:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000
///
/// Note for Android: `localhost` on a device means the device. Use the
/// laptop's LAN address, and remember that plain http needs the network
/// security config Android ships with debug builds.
class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tlcmedclinics.com',
  );

  /// The clinic's public number, used by the "call us" actions. Kept here and
  /// not in a screen so there is one copy of it.
  static const clinicPhoneE164 = '+923100404444';
  static const clinicPhoneDisplay = '+92 310 040 4444';
  static const supportEmail = 'info@tlcmedclinics.com';

  /// Email verification starts applying to accounts created on or after this
  /// date, and never to older ones.
  ///
  /// ── Why a date and not simply "everyone" ──
  ///
  /// Every patient who signed up on the website before today did so through a
  /// form that never asked them to verify anything. Turning the rule on for
  /// all of them at once would meet each of those people, the next time they
  /// opened the app, with a wall — for a step they were never told about, on
  /// an inbox some of them signed up with years ago and may no longer read.
  /// That is a real cost paid by people who did nothing wrong.
  ///
  /// So the rule looks forward. Accounts made from here on must verify;
  /// accounts that already exist keep working exactly as they do today. The
  /// clinic loses nothing — nobody was verifying before either — and gains a
  /// checked email address on every account from now on.
  ///
  /// The check is in `needsEmailVerification` (core/email_verification.dart),
  /// which is also where the other exemptions live: a phone-only account has
  /// no email to verify, and a Google account arrives already verified by
  /// Google.
  static final verifyEmailFrom = DateTime.utc(2026, 9, 14);
}
