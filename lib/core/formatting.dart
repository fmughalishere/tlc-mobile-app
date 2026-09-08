import 'package:intl/intl.dart';

/// Turning the server's strings into something a person reads.
///
/// The website stores dates as `YYYY-MM-DD` and times as 24-hour `HH:mm`,
/// both as plain strings rather than timestamps. That is a deliberate choice
/// there — a clinic slot at 3pm is 3pm in Lahore regardless of what the
/// phone's timezone says — so the app must not parse them into a UTC DateTime
/// and hand back a different hour. Everything here works on the strings.
class Fmt {
  const Fmt._();

  /// "2026-09-14" → "Mon, 14 Sep"
  static String date(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('EEE, d MMM').format(parsed);
  }

  /// "2026-09-14" → "14 September 2026"
  static String dateLong(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('d MMMM yyyy').format(parsed);
  }

  /// "15:30" → "3:30 PM". Kept as string arithmetic on purpose: building a
  /// DateTime to format a wall-clock time is how an app ends up showing 8:30
  /// PM to someone in a different timezone for a slot that is at 3:30.
  static String time(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return '—';
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return hhmm;
    final suffix = h < 12 ? 'AM' : 'PM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:${m.toString().padLeft(2, '0')} $suffix';
  }

  /// A full ISO timestamp (createdAt, ratedAt…) → "14 Sep, 3:30 PM"
  static String stamp(String? isoTimestamp) {
    if (isoTimestamp == null || isoTimestamp.isEmpty) return '';
    final parsed = DateTime.tryParse(isoTimestamp);
    if (parsed == null) return isoTimestamp;
    return DateFormat('d MMM, h:mm a').format(parsed.toLocal());
  }

  /// How long ago, in words. Used on the notifications list, where the exact
  /// minute matters far less than "is this new".
  static String ago(String? isoTimestamp) {
    final parsed = isoTimestamp == null ? null : DateTime.tryParse(isoTimestamp);
    if (parsed == null) return '';
    final diff = DateTime.now().difference(parsed.toLocal());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(parsed.toLocal());
  }

  /// PKR, grouped, no decimals. The clinic prices in whole rupees.
  static String money(num? amount) {
    if (amount == null) return '—';
    return 'PKR ${NumberFormat.decimalPattern().format(amount.round())}';
  }

  /// "+923100404444" → "0310 040 4444".
  ///
  /// The same rule as the website's `formatPhone`, and it has to stay the
  /// same rule: a patient comparing the number on the site with the number in
  /// the app should not have to work out whether they match.
  static String phone(String? e164) {
    if (e164 == null || e164.isEmpty) return '';
    final digits = e164.replaceAll(RegExp(r'\D'), '');
    final national = digits.startsWith('92') ? digits.substring(2) : digits;
    if (national.length < 10) return e164;
    return '0${national.substring(0, 3)} ${national.substring(3, 6)} ${national.substring(6)}';
  }

  /// "0310-040-4444" → "+923100404444", or null when it cannot be a number.
  ///
  /// A direct port of the website's `toE164`. Firebase's OTP and the clinic's
  /// records both key on the E.164 form, so a number typed the way people say
  /// it has to become that form before it is sent anywhere.
  static String? toE164(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('+')) {
      final digits = trimmed.substring(1).replaceAll(RegExp(r'\D'), '');
      return digits.length >= 8 ? '+$digits' : null;
    }

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    if (digits.startsWith('0')) {
      final national = digits.substring(1);
      return national.length >= 9 ? '+92$national' : null;
    }
    if (digits.startsWith('92')) return '+$digits';
    return digits.length >= 9 ? '+92$digits' : null;
  }

  /// Today as the server spells it.
  static String todayIso() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// First name only, for a greeting. "Fizza Khalid" → "Fizza".
  static String firstName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}
