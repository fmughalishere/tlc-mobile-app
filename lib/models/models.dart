/// The shapes the server actually returns.
///
/// These mirror `src/types/index.ts` and `src/types/slot.ts` in the website,
/// field for field and name for name. Where the website's type says a field is
/// optional, it is nullable here — that is not caution, it is accurate: a
/// service written before the Urdu columns existed has no `nameUr`, an
/// appointment booked without a slot has no `doctorId`, and a `null` check in
/// the app is the difference between a blank line and a crash.
///
/// Every `fromJson` is written to survive a field it has never seen and a
/// field that has gone missing, because the website ships independently of the
/// app and will do both.
library;

String _str(dynamic v) => v == null ? '' : v.toString();
String? _strOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

num? _numOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  return num.tryParse(v.toString());
}

List<String> _strList(dynamic v) {
  if (v is List) {
    return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }
  return const [];
}

/// Picks Urdu when it exists and the reader wants Urdu, English otherwise.
///
/// The website's `lib/bilingual.ts` does exactly this, including the silent
/// fallback: a catalogue is translated one service at a time over weeks, and
/// during those weeks an Urdu reader should see English words rather than a
/// gap where a treatment name belongs.
String biPick(bool urdu, String? english, String? urduText) {
  if (urdu) {
    final trimmed = urduText?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return english?.trim() ?? '';
}

/// The list form. A list that is half Urdu and half English, interleaved by
/// index, reads as a fault rather than as a translation in progress — so the
/// Urdu list is used only when it is at least as long as the English one.
List<String> biPickList(bool urdu, List<String> english, List<String> urduList) {
  if (urdu && urduList.isNotEmpty && urduList.length >= english.length) {
    return urduList;
  }
  return english;
}

// ─────────────────────────────────────────────────────────────── Service ────

class Service {
  const Service({
    required this.id,
    required this.slug,
    required this.category,
    required this.name,
    required this.short,
    required this.intro,
    required this.points,
    required this.treatments,
    this.nameUr,
    this.shortUr,
    this.introUr,
    this.pointsUr = const [],
    this.treatmentsUr = const [],
    this.price,
    this.advancePayment,
    this.durationMinutes,
    this.image,
    this.order = 0,
  });

  final String id;
  final String slug;
  final String category;
  final String name;
  final String short;
  final String intro;
  final List<String> points;
  final List<String> treatments;

  final String? nameUr;
  final String? shortUr;
  final String? introUr;
  final List<String> pointsUr;
  final List<String> treatmentsUr;

  final num? price;

  /// What is taken online to hold the appointment when that is less than the
  /// full price. Absent means "charge the full price"; zero means "charge
  /// nothing" — two different things, which is why this is nullable and not 0.
  final num? advancePayment;
  final num? durationMinutes;
  final String? image;
  final int order;

  factory Service.fromJson(Map<String, dynamic> json) => Service(
        id: _str(json['id']),
        slug: _str(json['slug']),
        category: _str(json['category']),
        name: _str(json['name']),
        short: _str(json['short']),
        intro: _str(json['intro']),
        points: _strList(json['points']),
        treatments: _strList(json['treatments']),
        nameUr: _strOrNull(json['nameUr']),
        shortUr: _strOrNull(json['shortUr']),
        introUr: _strOrNull(json['introUr']),
        pointsUr: _strList(json['pointsUr']),
        treatmentsUr: _strList(json['treatmentsUr']),
        price: _numOrNull(json['price']),
        advancePayment: _numOrNull(json['advancePayment']),
        durationMinutes: _numOrNull(json['durationMinutes']),
        image: _strOrNull(json['image']),
        order: (_numOrNull(json['order']) ?? 0).toInt(),
      );

  String displayName(bool urdu) => biPick(urdu, name, nameUr);
  String displayShort(bool urdu) => biPick(urdu, short, shortUr);
  String displayIntro(bool urdu) => biPick(urdu, intro, introUr);
  List<String> displayPoints(bool urdu) => biPickList(urdu, points, pointsUr);
  List<String> displayTreatments(bool urdu) => biPickList(urdu, treatments, treatmentsUr);

  /// What the patient pays now to hold the booking.
  num get payableNow => advancePayment ?? price ?? 0;
}

// ──────────────────────────────────────────────────────────────── Doctor ────

class Doctor {
  const Doctor({
    required this.uid,
    required this.name,
    this.specialization,
    this.bio,
    this.photoURL,
    this.online = false,
    this.active = true,
  });

  final String uid;
  final String name;
  final String? specialization;
  final String? bio;
  final String? photoURL;

  /// Computed server-side from the doctor's heartbeat, never read from the
  /// document — a doctor whose session ended without a clean goodbye stops
  /// showing as available once the window lapses.
  final bool online;
  final bool active;

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
        uid: _str(json['uid']),
        name: _str(json['name']),
        specialization: _strOrNull(json['specialization']),
        bio: _strOrNull(json['bio']),
        photoURL: _strOrNull(json['photoURL']),
        online: json['online'] == true,
        active: json['active'] != false,
      );

  /// "Dr. " is added here rather than stored, so the clinic never has to
  /// remember to type it and no name ends up with two of them.
  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Doctor';
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('dr ') || lower.startsWith('dr.')) return trimmed;
    return 'Dr. $trimmed';
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String first(String s) => s.substring(0, 1).toUpperCase();
    if (parts.length == 1) return first(parts.first);
    return '${first(parts.first)}${first(parts.last)}';
  }
}

// ────────────────────────────────────────────────────────────────── Slot ────

class Slot {
  const Slot({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.date,
    required this.time,
    this.service,
    this.mode = 'online',
    this.durationMinutes = 30,
    this.status = 'available',
  });

  final String id;
  final String doctorId;
  final String doctorName;

  /// YYYY-MM-DD
  final String date;

  /// HH:mm, 24-hour
  final String time;

  /// Unset means the slot is open to any service under this doctor.
  final String? service;

  /// "in-clinic" or "online". Slots created before this field existed have
  /// none, and the website treats those as online — so this defaults to it.
  final String mode;
  final num durationMinutes;
  final String status;

  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
        id: _str(json['id']),
        doctorId: _str(json['doctorId']),
        doctorName: _str(json['doctorName']),
        date: _str(json['date']),
        time: _str(json['time']),
        service: _strOrNull(json['service']),
        mode: _strOrNull(json['mode']) ?? 'online',
        durationMinutes: _numOrNull(json['durationMinutes']) ?? 30,
        status: _strOrNull(json['status']) ?? 'available',
      );

  bool get isOnline => mode != 'in-clinic';
}

// ─────────────────────────────────────────────────────────── Appointment ────

class Appointment {
  const Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.service,
    required this.status,
    required this.mode,
    this.patientPhone,
    required this.date,
    required this.time,
    required this.amount,
    required this.paymentStatus,
    required this.bookingType,
    required this.createdAt,
    this.doctorId,
    this.doctorName,
    this.consultMode,
    this.notes,
    this.roomUrl,
    this.sessionStatus,
    this.prescription,
    this.prescriptionImages = const [],
    this.rating,
    this.ratingComment,
    this.cancelReason,
    this.needsDoctor = false,
    this.preferredWhen,
  });

  final String id;
  final String patientId;
  final String patientName;

  /// The number the clinic actually rings to confirm an unpaid booking, and
  /// the one a doctor taps to call a patient back. Optional because a booking
  /// made from an account that has no number on it does not carry one.
  final String? patientPhone;
  final String service;

  /// pending · awaiting-payment · confirmed · completed · cancelled
  final String status;

  /// video · audio · chat · in-person
  final String mode;
  final String date;
  final String time;
  final num amount;

  /// unpaid · paid · refunded
  final String paymentStatus;

  /// online-payment · call-back · doctor-request · follow-up
  final String bookingType;
  final String createdAt;

  final String? doctorId;
  final String? doctorName;

  /// in-clinic · online — copied from the slot the patient picked.
  final String? consultMode;
  final String? notes;
  final String? roomUrl;

  /// not_started · live · ended. Separate from `status` because "confirmed"
  /// only means the booking is held; the session itself becomes live at the
  /// scheduled time.
  final String? sessionStatus;
  final String? prescription;
  final List<String> prescriptionImages;
  final num? rating;
  final String? ratingComment;
  final String? cancelReason;

  /// Set when no doctor covering this service had an open slot, so the clinic
  /// has to assign one.
  final bool needsDoctor;
  final String? preferredWhen;

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: _str(json['id']),
        patientId: _str(json['patientId']),
        patientName: _str(json['patientName']),
        patientPhone: _strOrNull(json['patientPhone']),
        service: _str(json['service']),
        status: _strOrNull(json['status']) ?? 'pending',
        mode: _strOrNull(json['mode']) ?? 'video',
        date: _str(json['date']),
        time: _str(json['time']),
        amount: _numOrNull(json['amount']) ?? 0,
        paymentStatus: _strOrNull(json['paymentStatus']) ?? 'unpaid',
        bookingType: _strOrNull(json['bookingType']) ?? 'call-back',
        createdAt: _str(json['createdAt']),
        doctorId: _strOrNull(json['doctorId']),
        doctorName: _strOrNull(json['doctorName']),
        consultMode: _strOrNull(json['consultMode']),
        notes: _strOrNull(json['notes']),
        roomUrl: _strOrNull(json['roomUrl']),
        sessionStatus: _strOrNull(json['sessionStatus']),
        prescription: _strOrNull(json['prescription']),
        prescriptionImages: _strList(json['prescriptionImages']),
        rating: _numOrNull(json['rating']),
        ratingComment: _strOrNull(json['ratingComment']),
        cancelReason: _strOrNull(json['cancelReason']),
        needsDoctor: json['needsDoctor'] == true,
        preferredWhen: _strOrNull(json['preferredWhen']),
      );

  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
  bool get isUpcoming => !isCancelled && !isCompleted;
  bool get awaitingPayment => status == 'awaiting-payment';
  bool get canBeRated => isCompleted && rating == null;

  /// A doctor-request has no date at all until the clinic schedules it.
  bool get hasSchedule => date.isNotEmpty && time.isNotEmpty;

  /// Sorting key. Unscheduled requests sort to the end rather than to 1970.
  String get sortKey => hasSchedule ? '$date $time' : '9999-99-99';
}

// ────────────────────────────────────────────────────────── Notification ────

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    required this.createdAt,
    this.appointmentId,
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final bool read;
  final String createdAt;
  final String? appointmentId;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: _str(json['id']),
        title: _str(json['title']),
        message: _str(json['message']),
        type: _str(json['type']),
        read: json['read'] == true,
        createdAt: _str(json['createdAt']),
        appointmentId: _strOrNull(json['appointmentId']),
      );
}

// ─────────────────────────────────────────────────────────────── Profile ────

class Profile {
  const Profile({
    required this.uid,
    required this.role,
    required this.name,
    this.email,
    this.phone,
    this.photoURL,
    this.locale,
    this.specialization,
    this.bio,
    this.notificationSound = true,
    this.messageSound = true,
    this.presenceVisible = true,
  });

  final String uid;
  final String role;
  final String name;
  final String? email;
  final String? phone;
  final String? photoURL;
  final String? locale;
  final String? specialization;
  final String? bio;

  /// The three preference switches the website also has. All of them default
  /// to on, and the website's own reader treats "not set yet" the same way —
  /// so `!= false` rather than `== true`, because an account created before
  /// these fields existed has none of them and should still get the chime.
  final bool notificationSound;
  final bool messageSound;

  /// Doctors only: opt out of showing as online. There is deliberately no
  /// manual "I am online" switch anywhere — presence is derived from the
  /// heartbeat, and this only suppresses it.
  final bool presenceVisible;

  bool get isDoctor => role == 'doctor';

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        uid: _str(json['uid']),
        role: _strOrNull(json['role']) ?? 'patient',
        name: _str(json['name']),
        email: _strOrNull(json['email']),
        phone: _strOrNull(json['phone']),
        photoURL: _strOrNull(json['photoURL']),
        locale: _strOrNull(json['locale']),
        specialization: _strOrNull(json['specialization']),
        bio: _strOrNull(json['bio']),
        notificationSound: json['notificationSound'] != false,
        messageSound: json['messageSound'] != false,
        presenceVisible: json['presenceVisible'] != false,
      );

  Profile copyWith({
    String? name,
    String? email,
    String? phone,
    String? specialization,
    String? bio,
    bool? notificationSound,
    bool? messageSound,
    bool? presenceVisible,
  }) =>
      Profile(
        uid: uid,
        role: role,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        photoURL: photoURL,
        locale: locale,
        specialization: specialization ?? this.specialization,
        bio: bio ?? this.bio,
        notificationSound: notificationSound ?? this.notificationSound,
        messageSound: messageSound ?? this.messageSound,
        presenceVisible: presenceVisible ?? this.presenceVisible,
      );

  /// The same thing, but taking the very map that is about to be sent to
  /// `PATCH /api/profile`.
  ///
  /// It exists so the settings screen can show a change immediately and undo
  /// it if the server refuses — and it reads the same keys the server does, so
  /// the optimistic copy and the saved one cannot drift apart. A key the
  /// server would ignore is ignored here too.
  Profile withChanges(Map<String, dynamic> changes) {
    String? text(String key, String? fallback) {
      if (!changes.containsKey(key)) return fallback;
      final value = changes[key];
      if (value is! String) return fallback;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    bool flag(String key, bool fallback) =>
        changes[key] is bool ? changes[key] as bool : fallback;

    return Profile(
      uid: uid,
      role: role,
      name: text('name', name) ?? name,
      email: text('email', email),
      phone: text('phone', phone),
      photoURL: text('photoURL', photoURL),
      locale: text('locale', locale),
      specialization: text('specialization', specialization),
      bio: text('bio', bio),
      notificationSound: flag('notificationSound', notificationSound),
      messageSound: flag('messageSound', messageSound),
      presenceVisible: flag('presenceVisible', presenceVisible),
    );
  }
}

// ───────────────────────────────────────────────────────────────── Leave ────

/// A stretch of days a doctor is unavailable.
///
/// Stored separately from slots because leave covers *time*, not slots:
/// booking a fortnight off has to close the days nobody has opened yet as well
/// as the ones already on the calendar.
class Leave {
  const Leave({
    required this.id,
    required this.from,
    required this.to,
    this.reason,
    this.doctorName = '',
  });

  final String id;

  /// YYYY-MM-DD, inclusive.
  final String from;
  final String to;
  final String? reason;
  final String doctorName;

  factory Leave.fromJson(Map<String, dynamic> json) => Leave(
        id: _str(json['id']),
        from: _str(json['from']),
        to: _str(json['to']),
        reason: _strOrNull(json['reason']),
        doctorName: _str(json['doctorName']),
      );

  bool get isSingleDay => from == to || to.isEmpty;
}

// ─────────────────────────────────────────────────────────── Doctor stats ────

/// The four numbers on the doctor's overview.
///
/// Counted server-side with Firestore's `count()` rather than by fetching the
/// rows — a doctor with two thousand appointments should not download two
/// thousand documents to see the number 2000.
class DoctorStats {
  const DoctorStats({
    this.todays = 0,
    this.upcoming = 0,
    this.completed = 0,
    this.uniquePatients = 0,
    this.indexHint,
  });

  final int todays;
  final int upcoming;
  final int completed;
  final int uniquePatients;

  /// Set when a Firestore composite index is missing. It names the index and
  /// links the console, and it is worth surfacing rather than swallowing —
  /// otherwise the tiles just read zero and nobody knows why.
  final String? indexHint;

  factory DoctorStats.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'];
    final c = counts is Map ? Map<String, dynamic>.from(counts) : json;
    int pick(String key) => (_numOrNull(c[key]) ?? 0).toInt();
    return DoctorStats(
      todays: pick('todays'),
      upcoming: pick('upcoming'),
      completed: pick('completed'),
      uniquePatients: pick('uniquePatients'),
      indexHint: _strOrNull(json['indexHint']),
    );
  }
}

// ────────────────────────────────────────────────────── Patient summary ────

/// One of a doctor's patients, rolled up from their appointments.
///
/// There is no patients collection to read — a "patient of Dr X" is a person
/// who has an appointment with Dr X, and that is exactly how the website
/// builds this list too.
class PatientSummary {
  PatientSummary({
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    this.totalSessions = 0,
    this.completed = 0,
    this.lastSeen = '',
    this.nextUpcoming,
  });

  final String patientId;
  String patientName;
  String? patientPhone;
  int totalSessions;
  int completed;
  String lastSeen;
  Appointment? nextUpcoming;

  /// Groups a flat list of appointments into one row per person, most recently
  /// seen first.
  static List<PatientSummary> from(List<Appointment> appointments, String todayIso) {
    final byPatient = <String, PatientSummary>{};

    for (final a in appointments) {
      final isUpcoming = a.date.compareTo(todayIso) >= 0 && a.status == 'confirmed';
      final existing = byPatient[a.patientId];

      if (existing == null) {
        byPatient[a.patientId] = PatientSummary(
          patientId: a.patientId,
          patientName: a.patientName,
          patientPhone: a.patientPhone,
          totalSessions: 1,
          completed: a.isCompleted ? 1 : 0,
          lastSeen: a.date,
          nextUpcoming: isUpcoming ? a : null,
        );
        continue;
      }

      existing.totalSessions += 1;
      if (a.isCompleted) existing.completed += 1;
      if (a.date.compareTo(existing.lastSeen) > 0) existing.lastSeen = a.date;
      if (existing.patientPhone == null && a.patientPhone != null) {
        existing.patientPhone = a.patientPhone;
      }
      // The *soonest* upcoming one, not the last one seen in the list.
      if (isUpcoming &&
          (existing.nextUpcoming == null ||
              a.date.compareTo(existing.nextUpcoming!.date) < 0)) {
        existing.nextUpcoming = a;
      }
    }

    final list = byPatient.values.toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return list;
  }

  String get initials {
    final parts = patientName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String first(String s) => s.substring(0, 1).toUpperCase();
    if (parts.length == 1) return first(parts.first);
    return '${first(parts.first)}${first(parts.last)}';
  }
}

// ────────────────────────────────────────────────────────────── Coupon ────

class Coupon {
  const Coupon({
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.maxUses = 1,
    this.usedCount = 0,
    this.expiresAt,
    this.active = true,
    this.restrictedEmails = const [],
  });

  final String code;

  /// "percent" or "flat".
  final String discountType;
  final num discountValue;
  final int maxUses;
  final int usedCount;
  final String? expiresAt;
  final bool active;
  final List<String> restrictedEmails;

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
        code: _str(json['code']),
        discountType: _strOrNull(json['discountType']) ?? 'percent',
        discountValue: _numOrNull(json['discountValue']) ?? 0,
        maxUses: (_numOrNull(json['maxUses']) ?? 1).toInt(),
        usedCount: (_numOrNull(json['usedCount']) ?? 0).toInt(),
        expiresAt: _strOrNull(json['expiresAt']),
        active: json['active'] != false,
        restrictedEmails: _strList(json['restrictedEmails']),
      );

  bool get isPercent => discountType == 'percent';
  bool get exhausted => usedCount >= maxUses;

  /// Expired, spent, or switched off — three different reasons a code will
  /// not work, and a list that shows only "inactive" cannot tell them apart.
  bool get expired {
    final at = expiresAt;
    if (at == null) return false;
    final parsed = DateTime.tryParse(at);
    if (parsed == null) return false;
    return parsed.isBefore(DateTime.now());
  }

  bool get usable => active && !exhausted && !expired;
}

// ──────────────────────────────────────────────────────────── Blog post ────

class BlogPost {
  const BlogPost({
    required this.id,
    required this.title,
    required this.slug,
    required this.excerpt,
    required this.content,
    this.coverImage,
    this.authorName = '',
    this.published = false,
    this.createdAt = '',
  });

  final String id;
  final String title;
  final String slug;
  final String excerpt;
  final String content;
  final String? coverImage;
  final String authorName;
  final bool published;
  final String createdAt;

  factory BlogPost.fromJson(Map<String, dynamic> json) => BlogPost(
        id: _str(json['id']),
        title: _str(json['title']),
        slug: _str(json['slug']),
        excerpt: _str(json['excerpt']),
        content: _str(json['content']),
        coverImage: _strOrNull(json['coverImage']),
        authorName: _str(json['authorName']),
        published: json['published'] == true,
        createdAt: _str(json['createdAt']),
      );
}

// ─────────────────────────────────────────────────────────── Admin stats ────

/// One question's average across every rated visit in the window.
class QuestionAverage {
  const QuestionAverage({required this.key, required this.average, required this.count});

  final String key;
  final double? average;
  final int count;

  factory QuestionAverage.fromJson(String key, Map<String, dynamic> json) =>
      QuestionAverage(
        key: key,
        average: (_numOrNull(json['average']))?.toDouble(),
        count: (_numOrNull(json['count']) ?? 0).toInt(),
      );
}

/// One doctor's line in the admin's rollup.
class DoctorRow {
  const DoctorRow({required this.name, required this.completed, this.avgRating});

  final String name;
  final int completed;
  final double? avgRating;

  factory DoctorRow.fromJson(Map<String, dynamic> json) => DoctorRow(
        name: _str(json['name']),
        completed: (_numOrNull(json['completed']) ?? 0).toInt(),
        avgRating: (_numOrNull(json['avgRating']))?.toDouble(),
      );
}

class AdminStats {
  const AdminStats({
    this.patients = 0,
    this.appointments = 0,
    this.callBacks = 0,
    this.services = 0,
    this.blogs = 0,
    this.paidRevenue = 0,
    this.refunded = 0,
    this.completed = 0,
    this.avgRating,
    this.ratingCount = 0,
    this.ratingQuestions = const [],
    this.doctorRows = const [],
    this.windowDays = 0,
    this.indexHint,
  });

  final int patients;
  final int appointments;

  /// Bookings still waiting for the clinic to phone. This is the one number on
  /// the screen that is a to-do list rather than a report.
  final int callBacks;
  final int services;
  final int blogs;

  final num paidRevenue;
  final num refunded;
  final int completed;
  final double? avgRating;
  final int ratingCount;

  /// Which part of a visit the clinic is actually being marked down on. The
  /// overall average cannot answer that — 3.6 tells nobody anything, while
  /// "waiting time: Poor, quality of care: Excellent" says what to fix and
  /// what to leave alone.
  final List<QuestionAverage> ratingQuestions;
  final List<DoctorRow> doctorRows;
  final int windowDays;
  final String? indexHint;

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] is Map
        ? Map<String, dynamic>.from(json['counts'] as Map)
        : <String, dynamic>{};
    final an = json['analytics'] is Map
        ? Map<String, dynamic>.from(json['analytics'] as Map)
        : <String, dynamic>{};

    int c(String k) => (_numOrNull(counts[k]) ?? 0).toInt();

    final questions = <QuestionAverage>[];
    final rq = an['ratingQuestions'];
    if (rq is Map) {
      rq.forEach((key, value) {
        if (value is Map) {
          questions.add(
            QuestionAverage.fromJson('$key', Map<String, dynamic>.from(value)),
          );
        }
      });
    } else if (rq is List) {
      for (final row in rq) {
        if (row is Map) {
          final m = Map<String, dynamic>.from(row);
          questions.add(QuestionAverage.fromJson(_str(m['key']), m));
        }
      }
    }

    return AdminStats(
      patients: c('patients'),
      appointments: c('appointments'),
      callBacks: c('callBacks'),
      services: c('services'),
      blogs: c('blogs'),
      paidRevenue: _numOrNull(an['paidRevenue']) ?? 0,
      refunded: _numOrNull(an['refunded']) ?? 0,
      completed: (_numOrNull(an['completed']) ?? 0).toInt(),
      avgRating: (_numOrNull(an['avgRating']))?.toDouble(),
      ratingCount: (_numOrNull(an['ratingCount']) ?? 0).toInt(),
      ratingQuestions: questions,
      doctorRows: (an['doctorRows'] is List)
          ? (an['doctorRows'] as List)
              .whereType<Map>()
              .map((e) => DoctorRow.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      windowDays: (_numOrNull(json['windowDays']) ?? 0).toInt(),
      indexHint: _strOrNull(json['indexHint']),
    );
  }
}
