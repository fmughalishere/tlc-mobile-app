import '../models/models.dart';

/// When an online session can be joined, and what to say about it.
///
/// A direct port of the website's `src/lib/session-window.ts`, and it has to
/// stay one: the server applies the same rule to the join request. If the app
/// were more generous the button would be enabled and then refused; if it were
/// stricter the doctor would sit looking at a disabled button while the
/// patient waited in the room.
class SessionWindow {
  const SessionWindow._();

  /// How early a session opens on its own, in minutes.
  ///
  /// Zero, matching the website. A session becomes joinable at exactly its own
  /// time and nobody has to be asked to open it. The clinic keeps a manual
  /// early start for the cases that need judgement — a patient who turns up
  /// early, a doctor running ahead — but that is an override, not the way in.
  static const autoJoinLeadMinutes = 0;

  /// The appointment's wall-clock time, as a local DateTime.
  ///
  /// The clinic is in one timezone and the dates are stored as plain
  /// `YYYY-MM-DD` and `HH:mm` strings, so this parses them as local time on
  /// the phone. That is right for a doctor in Lahore and wrong for one abroad
  /// — the website has the same property, and fixing it belongs in both at
  /// once rather than in one of them.
  static DateTime? scheduledAt(Appointment a) {
    if (a.date.isEmpty || a.time.isEmpty) return null;
    return DateTime.tryParse('${a.date} ${a.time}:00');
  }

  /// Whether the session can be joined right now.
  static bool canJoin(Appointment a, DateTime now) {
    if (a.mode == 'in-person') return false;
    if (a.status != 'confirmed') return false;
    if (a.sessionStatus == 'ended') return false;
    if (a.sessionStatus == 'live') return true;

    final scheduled = scheduledAt(a);
    if (scheduled == null) return false;
    return !now.isBefore(
      scheduled.subtract(const Duration(minutes: autoJoinLeadMinutes)),
    );
  }

  /// A host — doctor or admin — may open the room before its time. This is
  /// what turns "the patient is early and nobody can let them in" into
  /// something the doctor can settle themselves.
  static bool canStartEarly(Appointment a, DateTime now) =>
      a.status == 'confirmed' &&
      a.mode != 'in-person' &&
      a.sessionStatus != 'ended' &&
      !canJoin(a, now);

  static int? minutesUntil(Appointment a, DateTime now) {
    final scheduled = scheduledAt(a);
    if (scheduled == null) return null;
    return (scheduled.difference(now).inSeconds / 60).round();
  }

  /// The short line next to the join button.
  static String label(Appointment a, DateTime now) {
    if (a.mode == 'in-person') return 'In-person visit';
    if (a.status == 'cancelled') return 'Cancelled';
    if (a.status == 'pending') return 'Awaiting confirmation';
    if (a.status == 'awaiting-payment') return 'Awaiting patient payment';
    if (a.sessionStatus == 'ended') return 'Session ended';
    if (a.sessionStatus == 'live') return 'Live now';

    final mins = minutesUntil(a, now);
    if (mins == null) return 'Scheduled';
    // Past the scheduled time the session is open — say so, rather than
    // leaving "starting soon" beside a button that already works.
    if (mins <= 0) return 'Ready to join';
    if (mins <= 5) return 'Starting soon';
    if (mins < 60) return 'Starts in $mins min';
    return 'Starts in ${(mins / 60).round()}h';
  }
}
