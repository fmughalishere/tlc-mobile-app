import 'package:intl/intl.dart';

import '../i18n/strings.dart';

/// Turning the server's strings into something a person reads.
///
/// The website stores dates as `YYYY-MM-DD` and times as 24-hour `HH:mm`,
/// both as plain strings rather than timestamps. That is a deliberate choice
/// there — a clinic slot at 3pm is 3pm in Lahore regardless of what the
/// phone's timezone says — so the app must not parse them into a UTC DateTime
/// and hand back a different hour. Everything here works on the strings.
///
/// ── Why the Urdu is written out by hand ──
///
/// This file used to call `DateFormat('EEE, d MMM')` with no locale, which
/// means the device's — in practice English. So an app that was otherwise
/// fully translated still showed every appointment as "Mon, 14 Sep · 3:30 PM"
/// and every notification as "2h ago" to a patient reading Urdu. Dates and
/// times are the most-read text in the whole app; leaving them English made
/// the language switch look broken.
///
/// The fix is not `DateFormat(..., 'ur')`. That needs intl's locale data
/// initialised before first use, and it brings its own opinion about which
/// digits to use — Eastern Arabic-Indic (۱۴) in some builds, Latin in others.
/// The clinic's prices, phone numbers and the website all use Latin digits, so
/// a patient comparing the app with the site would see two different numbers
/// for the same appointment. Hand-written names keep the digits stable and the
/// wording the way people in Lahore actually say it.
class Fmt {
  const Fmt._();

  static bool get _ur => LocaleController.urdu;

  /// Gregorian months as Urdu speakers write them. Pakistan uses the Gregorian
  /// calendar for everything civil, so these are transliterations, not the
  /// Islamic months.
  static const _monthsUr = <String>[
    'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون',
    'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر',
  ];

  /// DateTime.weekday is 1 = Monday … 7 = Sunday.
  static const _weekdaysUr = <String>[
    'پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار',
  ];

  /// "2026-09-14" → "Mon, 14 Sep" / "پیر، 14 ستمبر"
  static String date(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    if (_ur) {
      return '${_weekdaysUr[parsed.weekday - 1]}، '
          '${parsed.day} ${_monthsUr[parsed.month - 1]}';
    }
    return DateFormat('EEE, d MMM').format(parsed);
  }

  /// "2026-09-14" → "14 September 2026" / "14 ستمبر 2026"
  static String dateLong(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    if (_ur) {
      return '${parsed.day} ${_monthsUr[parsed.month - 1]} ${parsed.year}';
    }
    return DateFormat('d MMMM yyyy').format(parsed);
  }

  /// "15:30" → "3:30 PM" / "3:30 دوپہر". Kept as string arithmetic on purpose:
  /// building a DateTime to format a wall-clock time is how an app ends up
  /// showing 8:30 PM to someone in a different timezone for a slot at 3:30.
  ///
  /// Urdu does not have a two-way AM/PM split. Saying "3:30 صبح" for the
  /// afternoon reads as wrong to anyone who speaks the language, so the day is
  /// divided the way it is spoken: morning, afternoon, evening, night.
  static String time(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return '—';
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return hhmm;
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    final minute = m.toString().padLeft(2, '0');
    if (_ur) return '$hour12:$minute ${_periodUr(h)}';
    return '$hour12:$minute ${h < 12 ? 'AM' : 'PM'}';
  }

  static String _periodUr(int hour24) {
    if (hour24 < 12) return 'صبح';
    if (hour24 < 16) return 'دوپہر';
    if (hour24 < 19) return 'شام';
    return 'رات';
  }

  /// A full ISO timestamp (createdAt, ratedAt…) → "14 Sep, 3:30 PM"
  static String stamp(String? isoTimestamp) {
    if (isoTimestamp == null || isoTimestamp.isEmpty) return '';
    final parsed = DateTime.tryParse(isoTimestamp);
    if (parsed == null) return isoTimestamp;
    final local = parsed.toLocal();
    if (_ur) {
      final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      return '${local.day} ${_monthsUr[local.month - 1]}، '
          '$hour12:$minute ${_periodUr(local.hour)}';
    }
    return DateFormat('d MMM, h:mm a').format(local);
  }

  /// How long ago, in words. Used on the notifications list, where the exact
  /// minute matters far less than "is this new".
  static String ago(String? isoTimestamp) {
    final parsed = isoTimestamp == null ? null : DateTime.tryParse(isoTimestamp);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final diff = DateTime.now().difference(local);
    if (_ur) {
      if (diff.inSeconds < 60) return 'ابھی ابھی';
      if (diff.inMinutes < 60) return '${diff.inMinutes} منٹ پہلے';
      if (diff.inHours < 24) return '${diff.inHours} گھنٹے پہلے';
      if (diff.inDays < 7) return '${diff.inDays} دن پہلے';
      return '${local.day} ${_monthsUr[local.month - 1]}';
    }
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(local);
  }

  /// PKR, grouped, no decimals. The clinic prices in whole rupees.
  ///
  /// Latin digits in both languages, on purpose: the website, the payment
  /// gateway's own page and the SMS receipt all use them, and a price a
  /// patient cannot match against the one they just paid is worse than a price
  /// in the wrong script.
  static String money(num? amount) {
    if (amount == null) return '—';
    final grouped = NumberFormat.decimalPattern('en').format(amount.round());
    return _ur ? '$grouped روپے' : 'PKR $grouped';
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

  /// Today as the server spells it. Never localised — this one is sent to the
  /// API, not shown to anybody.
  static String todayIso() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// First name only, for a greeting. "Fizza Khalid" → "Fizza".
  static String firstName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}
