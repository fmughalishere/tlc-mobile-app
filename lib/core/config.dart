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
}
