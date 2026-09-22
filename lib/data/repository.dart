import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;

import '../core/api_client.dart';
import '../i18n/strings.dart';
import '../core/config.dart';
import '../models/models.dart';

/// Every call the app makes to the clinic's server, in one file.
///
/// ── Why the screens do not call the API directly ──
///
/// Because the endpoints are shared with the website and will change there.
/// When `/api/appointments` starts returning `{ items: [...] }` instead of a
/// bare array — the kind of change that happens the day someone adds paging —
/// exactly one function in this file needs editing, not eleven screens.
///
/// It also means every screen gets the same treatment of a list response.
/// These routes answer with a bare JSON array today, but a 500 answers with
/// `{ "error": "..." }`, and `_list` below is where that difference is
/// settled rather than in each `build`.
class Repository {
  Repository({ApiClient? api})
      : _api = api ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _api;

  List<Map<String, dynamic>> _list(dynamic body, [String? key]) {
    if (body is List) {
      return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (body is Map && key != null && body[key] is List) {
      return (body[key] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Map<String, dynamic> _map(dynamic body) =>
      body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};

  // ── Catalogue ─────────────────────────────────────────────────────────────
  // Public: no token needed. That is what lets the app show the clinic's
  // services on the very first launch, before anyone has signed in — a patient
  // deciding whether to make an account should be able to see what is on offer
  // first.

  Future<List<Service>> services() async {
    final rows = _list(await _api.get('/api/services'), 'services');
    final list = rows.map(Service.fromJson).toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  Future<Service?> service(String id) async {
    final body = _map(await _api.get('/api/services/$id'));
    if (body.isEmpty) return null;
    // The route answers with the document itself, but a wrapped shape is
    // cheap to tolerate and expensive to be surprised by.
    final inner = body['service'];
    return Service.fromJson(inner is Map ? Map<String, dynamic>.from(inner) : body);
  }

  // ── Doctors ───────────────────────────────────────────────────────────────
  // Needs a token. A patient is only ever sent the approved, active doctors,
  // and never their contact details — the filtering happens server-side.

  Future<List<Doctor>> doctors() async {
    final rows = _list(await _api.get('/api/doctors'), 'doctors');
    return rows.map(Doctor.fromJson).where((d) => d.active).toList();
  }

  // ── Slots ─────────────────────────────────────────────────────────────────

  /// Open slots from today onward.
  ///
  /// `service` is matched loosely by the server: a slot with no service set is
  /// open to any service under that doctor, so it comes back too. `mode` is
  /// "online" or "in-clinic".
  Future<List<Slot>> availableSlots({
    String? service,
    String? mode,
    String? doctorId,
    String? from,
    String? to,
  }) async {
    final rows = _list(
      await _api.get('/api/slots', query: {
        'onlyAvailable': 'true',
        if (service != null && service.isNotEmpty) 'service': service,
        if (mode != null && mode.isNotEmpty) 'mode': mode,
        if (doctorId != null && doctorId.isNotEmpty) 'doctorId': doctorId,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      }),
      'slots',
    );
    return rows.map(Slot.fromJson).where((s) => s.status == 'available').toList();
  }

  // ── Appointments ──────────────────────────────────────────────────────────

  /// The caller's own appointments. Scoping is done by the server from the
  /// token — a patient gets theirs, a doctor gets the ones assigned to them.
  /// The app never sends a patient id, and could not usefully lie about one.
  Future<List<Appointment>> appointments({String? status, int limit = 50}) async {
    final rows = _list(
      await _api.get('/api/appointments', query: {
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
      }),
      'appointments',
    );
    return rows.map(Appointment.fromJson).toList();
  }

  /// Books a slot.
  ///
  /// `bookingType: "call-back"` is the unpaid path — the clinic phones the
  /// patient to confirm. It is what the app uses today, deliberately: taking
  /// money needs the payment gateway's own flow, and a booking that reaches
  /// the clinic and gets a phone call is a real booking, not a placeholder.
  Future<Appointment> book({
    required String service,
    required String slotId,
    required String patientName,
    String? patientPhone,
    String mode = 'video',
    num amount = 0,
    String? notes,
    String patientType = 'new',
  }) async {
    final body = _map(await _api.post('/api/appointments', {
      'service': service,
      'slotId': slotId,
      'bookingType': 'call-back',
      'patientName': patientName,
      if (patientPhone != null && patientPhone.isNotEmpty) 'patientPhone': patientPhone,
      'mode': mode,
      'amount': amount,
      'patientType': patientType,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    }));
    final inner = body['appointment'];
    return Appointment.fromJson(
      inner is Map ? Map<String, dynamic>.from(inner) : body,
    );
  }

  // ── Paying ────────────────────────────────────────────────────────────────
  //
  // The app never holds a merchant key and never talks to a gateway directly.
  // It asks the clinic's own server to start a payment, gets back the one
  // thing it needs — where to send the patient — and opens that. Every secret
  // stays on the server, which matters more here than anywhere else in the
  // app: an APK is a file anybody can download and unzip, so a merchant secret
  // compiled into one is a merchant secret published.

  /// Asks the clinic's server to text a sign-in code to this number.
  ///
  /// ── Why this does not use Firebase Phone Auth ──
  ///
  /// The app used to, and the website never did — it has always gone through
  /// Twilio Verify on the clinic's own server. Two OTP systems for one clinic
  /// is two sets of credentials, two delivery records and two things to be
  /// broken at once; and the Firebase one carried a trap of its own, because
  /// Android refuses to send the SMS until the app's SHA-1 and SHA-256 are
  /// registered in the Firebase console. An unregistered build fails with
  /// `app-not-authorized` and no code ever arrives.
  ///
  /// Going through the server removes both problems. Twilio owns the code, its
  /// expiry and its retry limits; the server checks it and mints a Firebase
  /// custom token, so Firebase is still the identity system — it simply is not
  /// the one sending the text.
  ///
  /// Errors come back as i18n keys ("auth.invalidPhone"), so the screen can
  /// show them in the patient's own language rather than in whatever language
  /// the server happens to be written in.
  Future<void> requestPhoneCode(String phoneE164) async {
    await _api.post('/api/auth/phone/start', {'phone': phoneE164});
  }

  /// Submits the code and returns a Firebase custom token to sign in with.
  ///
  /// The token is only minted after Twilio approves the code, so nothing the
  /// app sends can claim a number the person does not hold.
  Future<String> verifyPhoneCode(String phoneE164, String code) async {
    final body = _map(await _api.post('/api/auth/phone/verify', {
      'phone': phoneE164,
      'code': code,
    }));
    final token = body['token'];
    if (token is! String || token.isEmpty) {
      throw ApiException(502, 'common.somethingWrong');
    }
    return token;
  }

  /// Tells the server which phone to send notifications to.
  ///
  /// The uid is never sent — the server takes it from the ID token on the
  /// request. A body that says who you are is a body that can lie, and the
  /// thing being claimed here is "deliver this person's medical appointments
  /// to my device".
  Future<void> registerPushToken(
    String token, {
    String? platform,
    String? locale,
  }) async {
    await _api.post('/api/push/token', {
      'token': token,
      if (platform != null) 'platform': platform,
      // Which language the server should write this phone's lock-screen
      // notifications in. The OS draws those itself, so the choice has to be
      // made when the push is sent, not when it arrives.
      if (locale != null) 'locale': locale,
    });
  }

  /// Stops notifications reaching this phone. Called on sign-out, while the
  /// user is still signed in — the request needs a token the server accepts.
  Future<void> unregisterPushToken(String token) async {
    await _api.delete('/api/push/token', {'token': token});
  }

  /// Which ways of paying the clinic can actually take today.
  ///
  /// A failure here is not fatal and must not be: the booking screen falls
  /// back to the unpaid path, where the clinic rings to confirm. A patient who
  /// cannot see a card button still gets an appointment.
  Future<List<PaymentMethod>> paymentMethods() async {
    final rows = _list(await _api.get('/api/payments/methods'), 'methods');
    return rows.map(PaymentMethod.fromJson).where((m) => m.usable).toList();
  }

  /// Starts a payment for a *new* booking and returns where to send the
  /// patient.
  ///
  /// The server holds the slot and writes down the amount before answering, so
  /// nothing that happens in the WebView afterwards can change what is
  /// charged or let two people pay for the same 3pm. If the patient abandons
  /// the gateway, the callback releases the slot again.
  Future<PaymentHandover> startBookingPayment({
    required String gateway,
    required String service,
    required Slot slot,
    required String patientName,
    required num amount,
    String? patientPhone,
    String? notes,
    String patientType = 'new',
  }) async {
    final body = _map(await _api.post('/api/payments/start', {
      'gateway': gateway,
      'service': service,
      'slotId': slot.id,
      // The server reads the authoritative date and time off the slot document
      // inside its transaction; these are sent because the route requires them
      // present, not because it trusts them.
      'date': slot.date,
      'time': slot.time,
      'mode': slot.isOnline ? 'video' : 'in-person',
      'amount': amount,
      'patientName': patientName,
      if (patientPhone != null && patientPhone.isNotEmpty) 'patientPhone': patientPhone,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'patientType': patientType,
    }));
    return PaymentHandover.fromJson(body);
  }

  /// The same, for a follow-up the doctor already scheduled and left unpaid.
  /// No amount is sent: the server reads it off the appointment, so a browser
  /// claiming a different figure is ignored.
  Future<PaymentHandover> startAppointmentPayment({
    required String gateway,
    required String appointmentId,
  }) async {
    final body = _map(await _api.post('/api/payments/start', {
      'gateway': gateway,
      'appointmentId': appointmentId,
    }));
    return PaymentHandover.fromJson(body);
  }

  /// When no doctor covering the service has an open slot. The clinic assigns
  /// someone and schedules it, so there is no slot to hold and no date to send.
  Future<Appointment> requestAppointment({
    required String service,
    required String patientName,
    String? patientPhone,
    String? preferredWhen,
    String? notes,
  }) async {
    final body = _map(await _api.post('/api/appointments', {
      'service': service,
      'bookingType': 'doctor-request',
      'patientName': patientName,
      if (patientPhone != null && patientPhone.isNotEmpty) 'patientPhone': patientPhone,
      if (preferredWhen != null && preferredWhen.isNotEmpty) 'preferredWhen': preferredWhen,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'mode': 'video',
      'amount': 0,
    }));
    final inner = body['appointment'];
    return Appointment.fromJson(
      inner is Map ? Map<String, dynamic>.from(inner) : body,
    );
  }

  /// A patient may cancel their own booking; the server frees the slot.
  Future<void> cancelAppointment(String id, {String? reason}) async {
    await _api.patch('/api/appointments', {
      'id': id,
      'status': 'cancelled',
      if (reason != null && reason.isNotEmpty) 'cancelReason': reason,
    });
  }

  /// The five-question survey. `answers` is keyed by question id and every
  /// question must be answered — the server rejects a partial set rather than
  /// averaging over the ones that were filled in.
  Future<void> rateAppointment(
    String id, {
    required Map<String, int> answers,
    String? comment,
  }) async {
    await _api.post('/api/appointments/$id/rate', {
      'answers': answers,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<Profile?> profile() async {
    final body = _map(await _api.get('/api/profile'));
    if (body.isEmpty) return null;
    return Profile.fromJson(body);
  }

  /// The one PATCH the settings screen uses.
  ///
  /// The server answers 400 "Nothing to update" when the payload contains no
  /// field it recognises. That sentence is written for whoever wrote the
  /// request, not for the person holding the phone — "Nothing to update" after
  /// they have plainly just updated something reads as nonsense. It is
  /// rephrased here into what actually happened, and it stays an error: the
  /// change really was not stored, and saying otherwise would be a lie that
  /// only comes out on the next refresh.
  Future<Profile?> updateProfile(Map<String, dynamic> changes) async {
    if (changes.isEmpty) return null;
    try {
      final body = _map(await _api.patch('/api/profile', changes));
      final inner = body['profile'];
      if (inner is Map) return Profile.fromJson(Map<String, dynamic>.from(inner));
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 400 &&
          e.message.toLowerCase().contains('nothing to update')) {
        throw ApiException(400, LocaleController.tr('net.notSaved'));
      }
      rethrow;
    }
  }

  /// Called right after a Firebase account is created. It is what turns an
  /// authenticated stranger into a patient — or into a doctor waiting to be
  /// approved: it sets the role claim and writes the `users/{uid}` document
  /// every other route reads.
  ///
  /// `role` can only ever be patient or doctor. The server enforces that too —
  /// an admin account is made by a script at the clinic, never by anyone
  /// filling in a form — but sending it honestly from here keeps the app and
  /// the website telling the same story.
  ///
  /// Returns true when the account was created as a doctor awaiting approval,
  /// so the screen can say so rather than dropping them into a dashboard that
  /// will refuse them.
  Future<bool> registerProfile({
    required String uid,
    required String name,
    String? email,
    String? phone,
    String role = 'patient',
    String? specialization,
  }) async {
    final wantsDoctor = role == 'doctor';
    final body = _map(await _api.post('/api/auth/register', {
      'uid': uid,
      'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'role': wantsDoctor ? 'doctor' : 'patient',
      if (wantsDoctor && specialization != null && specialization.trim().isNotEmpty)
        'specialization': specialization.trim(),
    }));
    return body['approvalStatus'] == 'pending' || (wantsDoctor && body['role'] == 'doctor');
  }

  /// Closes the signed-in patient's account for good: `POST /api/account/delete`
  /// with `{ "confirm": "DELETE" }`.
  ///
  /// The server cancels upcoming appointments and frees their slots, takes the
  /// patient's name and phone off past visits (the clinical record itself is
  /// kept), removes push tokens, empties the profile, and deletes the Firebase
  /// Auth user last. It answers `{ ok: true }`; a doctor or admin gets 403, a
  /// missing confirmation 400, and a failure part-way 500 with an `error`.
  ///
  /// `"DELETE"` is sent whatever language the person typed the confirmation
  /// in — it is the server's own guard word, not what they saw.
  ///
  /// A 401 means the token went stale, not that the account cannot be closed:
  /// the token is force-refreshed once and the request tried again. The Admin
  /// SDK does the deletion, so Firebase's "requires recent login" does not
  /// apply here.
  Future<void> deleteAccount() async {
    const body = {'confirm': 'DELETE'};
    try {
      await _api.post('/api/account/delete', body);
    } on ApiException catch (e) {
      final user = FirebaseAuth.instance.currentUser;
      if (e.statusCode != 401 || user == null) rethrow;
      await user.getIdToken(true);
      await _api.post('/api/account/delete', body);
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<List<AppNotification>> notifications() async {
    final rows = _list(await _api.get('/api/notifications'), 'notifications');
    return rows.map(AppNotification.fromJson).toList();
  }

  Future<void> markNotificationRead(String id) async {
    await _api.patch('/api/notifications', {'id': id});
  }

  Future<void> markAllNotificationsRead() async {
    await _api.patch('/api/notifications', {'all': true});
  }

  // ── Doctor: the clinic side ───────────────────────────────────────────────
  //
  // Everything below is scoped by the server from the caller's token. The app
  // never sends a doctorId and could not usefully lie about one: `/api/slots`
  // POST reads it from the token, `/api/appointments` GET filters on it, and
  // the prescription route refuses anyone but the treating doctor. What
  // follows is an interface to permissions that already exist, not a new set.

  /// The four numbers on the doctor's overview, counted server-side.
  Future<DoctorStats> doctorStats() async {
    return DoctorStats.fromJson(_map(await _api.get('/api/appointments/stats')));
  }

  /// Confirm / complete / cancel. The same PATCH the website's status dropdown
  /// sends.
  Future<void> setAppointmentStatus(String id, String status) async {
    await _api.patch('/api/appointments', {'id': id, 'status': status});
  }

  /// Opens the room and marks the session live.
  ///
  /// Returns the updated appointment and, for video and audio, a Daily join
  /// token. The token is what makes the doctor the *host* — it is what lets
  /// them admit the patient and end the call — so it must be carried into the
  /// room URL rather than dropped.
  Future<({Appointment appointment, String? joinToken})> startSession(String id) async {
    final body = _map(await _api.post('/api/appointments/$id/session', {'action': 'start'}));
    final inner = body['appointment'];
    return (
      appointment: Appointment.fromJson(
        inner is Map ? Map<String, dynamic>.from(inner) : body,
      ),
      joinToken: body['joinToken'] is String ? body['joinToken'] as String : null,
    );
  }

  /// Ends it. The server also marks the appointment completed — one action,
  /// because a session that ended and a visit that did not happen is a state
  /// nobody wants to have to reconcile later.
  Future<Appointment> endSession(String id) async {
    final body = _map(await _api.post('/api/appointments/$id/session', {'action': 'end'}));
    final inner = body['appointment'];
    return Appointment.fromJson(inner is Map ? Map<String, dynamic>.from(inner) : body);
  }

  /// The e-prescription, plus up to six photographs of a written slip or a lab
  /// form — which in practice is often the whole prescription.
  Future<void> savePrescription(
    String id, {
    required String prescription,
    List<String> images = const [],
  }) async {
    await _api.patch('/api/appointments', {
      'id': id,
      'prescription': prescription,
      if (images.isNotEmpty) 'prescriptionImages': images.take(6).toList(),
    });
  }

  /// Books the next visit from this one. The patient then pays to hold it —
  /// which is why it lands as "awaiting-payment" rather than confirmed.
  Future<Appointment> scheduleFollowUp(
    String id, {
    required String slotId,
    String? note,
  }) async {
    final body = _map(await _api.post('/api/appointments/$id/follow-up', {
      'slotId': slotId,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    }));
    final inner = body['appointment'];
    return Appointment.fromJson(inner is Map ? Map<String, dynamic>.from(inner) : body);
  }

  // ── Doctor: the calendar ──────────────────────────────────────────────────

  /// Every slot of the calling doctor's, open and booked alike — the doctor's
  /// own view of their diary, not the patient's list of what is bookable.
  Future<List<Slot>> mySlots() async {
    final rows = _list(await _api.get('/api/slots'), 'slots');
    return rows.map(Slot.fromJson).toList()
      ..sort((a, b) => (a.date + a.time).compareTo(b.date + b.time));
  }

  /// Opens times. `times` rather than one `time` so a whole morning is one
  /// request and one round trip rather than eight.
  Future<int> openSlots({
    required String date,
    required List<String> times,
    String? service,
    String mode = 'online',
    int durationMinutes = 30,
  }) async {
    await _api.post('/api/slots', {
      'date': date,
      'times': times,
      'mode': mode,
      'durationMinutes': durationMinutes,
      if (service != null && service.isNotEmpty) 'service': service,
    });
    return times.length;
  }

  Future<void> removeSlot(String id) async {
    await _api.delete('/api/slots', {'id': id});
  }

  Future<List<Leave>> leaves() async {
    final rows = _list(await _api.get('/api/leaves'), 'leaves');
    return rows.map(Leave.fromJson).toList()
      ..sort((a, b) => a.from.compareTo(b.from));
  }

  /// Marks days away.
  ///
  /// Returns how many open times the server cleared, and how many bookings it
  /// found that it would NOT clear. That second number matters: those are real
  /// patients with a real appointment, and the right answer is to tell the
  /// doctor so the clinic can reschedule them — not to delete them quietly.
  Future<({int removedSlots, int bookedSlots})> addLeave({
    required String from,
    required String to,
    String? reason,
  }) async {
    final body = _map(await _api.post('/api/leaves', {
      'from': from,
      'to': to.isEmpty ? from : to,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    }));
    final booked = body['bookedSlots'];
    return (
      removedSlots: (body['removedSlots'] is num)
          ? (body['removedSlots'] as num).toInt()
          : 0,
      bookedSlots: booked is List ? booked.length : 0,
    );
  }

  Future<void> removeLeave(String id) async {
    await _api.delete('/api/leaves', {'id': id});
  }

  /// A doctor's own patients: everyone they have ever had an appointment with.
  ///
  /// There is no patients collection to read — "a patient of Dr X" is defined
  /// by having an appointment with Dr X, which is how the website builds this
  /// list too. Bounded at 500: the roll-up is ordered by last-seen, so if a
  /// doctor ever passes that the rows that fall off are the ones they saw
  /// longest ago.
  Future<List<Appointment>> doctorAppointments({int limit = 500, String? patientId}) async {
    final rows = _list(
      await _api.get('/api/appointments', query: {
        'limit': '$limit',
        if (patientId != null && patientId.isNotEmpty) 'patientId': patientId,
      }),
      'appointments',
    );
    return rows.map(Appointment.fromJson).toList();
  }

  // ── Admin ─────────────────────────────────────────────────────────────────
  //
  // Every route below refuses anyone whose token does not carry the admin
  // claim. Nothing here is a permission check — the screens simply are not
  // reachable without the role, and the server would refuse them anyway.

  Future<AdminStats> adminStats() async {
    return AdminStats.fromJson(_map(await _api.get('/api/appointments/stats')));
  }

  /// Every doctor, including the ones still pending approval — which is what
  /// makes the approvals list possible. A patient calling the same endpoint
  /// gets a filtered, contact-free version; the difference is decided by the
  /// token, not by a query parameter.
  Future<List<Doctor>> allDoctors() async {
    return (await allDoctorsRaw()).map(Doctor.fromJson).toList();
  }

  /// The same call, undecoded.
  ///
  /// `approvalStatus` is not on the `Doctor` model, because a patient never
  /// sees it and the model is the shape both roles share. Admin needs it to
  /// build the approvals list, so that one screen reads the raw rows rather
  /// than every other screen carrying a field it has no use for.
  Future<List<Map<String, dynamic>>> allDoctorsRaw() async {
    return _list(await _api.get('/api/doctors'), 'doctors');
  }

  /// Creates a doctor account outright — the clinic's real onboarding: admin
  /// issues the account, hands over the credentials, the doctor signs in.
  /// Accounts made this way are approved immediately; a doctor who signs
  /// themselves up on the website starts pending instead.
  Future<void> createDoctor({
    required String name,
    required String email,
    required String password,
    String? specialization,
    String? bio,
  }) async {
    await _api.post('/api/doctors', {
      'name': name,
      'email': email,
      'password': password,
      if (specialization != null && specialization.isNotEmpty)
        'specialization': specialization,
      if (bio != null && bio.isNotEmpty) 'bio': bio,
    });
  }

  /// Approve or reject a self-registered doctor. Approving activates the
  /// account and makes them visible to patients; rejecting disables sign-in
  /// outright, so a rejected request cannot get into a half-built dashboard.
  Future<void> setDoctorApproval(String uid, String approvalStatus) async {
    await _api.patch('/api/doctors', {'uid': uid, 'approvalStatus': approvalStatus});
  }

  /// Suspend or reinstate. Suspending disables the Firebase account, so a
  /// suspended doctor cannot read patient data even with an unexpired token.
  Future<void> setDoctorActive(String uid, bool active) async {
    await _api.patch('/api/doctors', {'uid': uid, 'active': active});
  }

  /// Puts a doctor on a booking that arrived without one.
  Future<void> assignDoctor(String appointmentId, Doctor doctor) async {
    await _api.patch('/api/appointments', {
      'id': appointmentId,
      'doctorId': doctor.uid,
      'doctorName': doctor.name,
    });
  }

  /// Moves a booking to a different open time. The server does it in a
  /// transaction — frees the old slot, claims the new one, updates the date —
  /// so two reschedules racing each other cannot double-book.
  Future<void> reschedule(String appointmentId, String newSlotId) async {
    await _api.patch('/api/appointments', {'id': appointmentId, 'newSlotId': newSlotId});
  }

  /// A real refund through the payment provider. Not reversible from here,
  /// which is why the screen asks twice.
  Future<void> issueRefund(String appointmentId) async {
    await _api.post('/api/appointments/$appointmentId/refund');
  }

  /// Every slot in the clinic, whoever it belongs to.
  Future<List<Slot>> allSlots({String? doctorId, String? from}) async {
    final rows = _list(
      await _api.get('/api/slots', query: {
        if (doctorId != null && doctorId.isNotEmpty) 'doctorId': doctorId,
        if (from != null && from.isNotEmpty) 'from': from,
      }),
      'slots',
    );
    return rows.map(Slot.fromJson).toList()
      ..sort((a, b) => (a.date + a.time).compareTo(b.date + b.time));
  }

  // ── Admin: the catalogue ──────────────────────────────────────────────────

  Future<Service> createService(Map<String, dynamic> body) async {
    final res = _map(await _api.post('/api/services', body));
    final inner = res['service'];
    return Service.fromJson(inner is Map ? Map<String, dynamic>.from(inner) : res);
  }

  Future<void> updateService(String id, Map<String, dynamic> body) async {
    await _api.put('/api/services/$id', body);
  }

  Future<void> deleteService(String id) async {
    await _api.delete('/api/services/$id');
  }

  // ── Admin: coupons ────────────────────────────────────────────────────────

  Future<List<Coupon>> coupons() async {
    final rows = _list(await _api.get('/api/coupons'), 'coupons');
    return rows.map(Coupon.fromJson).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  Future<void> createCoupon({
    required String code,
    required String discountType,
    required num discountValue,
    int maxUses = 1,
    String? expiresAt,
  }) async {
    await _api.post('/api/coupons', {
      'code': code.toUpperCase(),
      'discountType': discountType,
      'discountValue': discountValue,
      'maxUses': maxUses,
      if (expiresAt != null && expiresAt.isNotEmpty) 'expiresAt': expiresAt,
    });
  }

  Future<void> setCouponActive(String code, bool active) async {
    await _api.patch('/api/coupons/${Uri.encodeComponent(code)}', {'active': active});
  }

  Future<void> deleteCoupon(String code) async {
    await _api.delete('/api/coupons/${Uri.encodeComponent(code)}');
  }

  // ── Admin: blog ───────────────────────────────────────────────────────────

  /// `all=true` returns drafts as well, and is admin-only. Without it the
  /// route answers with the published posts, which is what the public site
  /// reads.
  Future<List<BlogPost>> blogs({bool includeDrafts = false}) async {
    final rows = _list(
      await _api.get('/api/blogs', query: {if (includeDrafts) 'all': 'true'}),
      'posts',
    );
    return rows.map(BlogPost.fromJson).toList();
  }

  Future<void> createBlog(Map<String, dynamic> body) async {
    await _api.post('/api/blogs', body);
  }

  Future<void> updateBlog(String id, Map<String, dynamic> body) async {
    await _api.put('/api/blogs/$id', body);
  }

  Future<void> deleteBlog(String id) async {
    await _api.delete('/api/blogs/$id');
  }

  // ── Booking, field for field with the website ─────────────────────────────
  //
  // `book`, `startBookingPayment` and `requestAppointment` above predate the
  // website's visit type, session length and coupon. These three send
  // everything the website's booking page sends (src/app/patient/book/page.tsx),
  // so a booking made in the app is indistinguishable from one made on the web.
  // The older three are left as they were for anything still calling them.

  /// The unpaid path with every field the website sends. See [book].
  ///
  /// `amount` and a discount are only ever the app's estimate: the server
  /// prices the booking itself from the service and the coupon documents
  /// (lib/pricing.ts on the website), and a figure sent from here is ignored.
  Future<Appointment> bookCallBack({
    required String service,
    required String slotId,
    required String patientName,
    String? patientPhone,
    String mode = 'video',
    num amount = 0,
    String? notes,
    String patientType = 'new',
    String? sessionType,
    String? couponCode,
  }) async {
    final body = _map(await _api.post('/api/appointments', {
      'service': service,
      'slotId': slotId,
      'bookingType': 'call-back',
      'patientName': patientName,
      if (patientPhone != null && patientPhone.isNotEmpty) 'patientPhone': patientPhone,
      'mode': mode,
      'amount': amount,
      'patientType': patientType,
      if (sessionType != null && sessionType.isNotEmpty) 'sessionType': sessionType,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    }));
    final inner = body['appointment'];
    return Appointment.fromJson(
      inner is Map ? Map<String, dynamic>.from(inner) : body,
    );
  }

  /// [startBookingPayment] with every field the website sends.
  ///
  /// The server re-prices the booking and charges its own figure whatever
  /// `amount` says; `amount` is read there only to log a disagreement. A code
  /// the server will not honour (expired a minute ago, restricted to another
  /// account) is dropped rather than refused, and the patient is charged the
  /// normal price — see `quoteBooking` on the website.
  Future<PaymentHandover> startNewBookingPayment({
    required String gateway,
    required String service,
    required Slot slot,
    required String patientName,
    required num amount,
    String? mode,
    String? patientPhone,
    String? notes,
    String patientType = 'new',
    String? sessionType,
    String? couponCode,
  }) async {
    final body = _map(await _api.post('/api/payments/start', {
      'gateway': gateway,
      'service': service,
      'slotId': slot.id,
      // Required present by the route; the real date and time come off the
      // slot document on the server.
      'date': slot.date,
      'time': slot.time,
      'mode': mode ?? (slot.isOnline ? 'video' : 'in-person'),
      'amount': amount,
      'patientName': patientName,
      if (patientPhone != null && patientPhone.isNotEmpty) 'patientPhone': patientPhone,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'patientType': patientType,
      if (sessionType != null && sessionType.isNotEmpty) 'sessionType': sessionType,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
    }));
    return PaymentHandover.fromJson(body);
  }

  /// [requestAppointment] with every field the website sends.
  Future<Appointment> requestDoctorAssignment({
    required String service,
    required String patientName,
    String? patientPhone,
    String? preferredWhen,
    String? notes,
    String mode = 'video',
    num amount = 0,
    String patientType = 'new',
    String? sessionType,
    String? couponCode,
  }) async {
    final body = _map(await _api.post('/api/appointments', {
      'service': service,
      'bookingType': 'doctor-request',
      'patientName': patientName,
      if (patientPhone != null && patientPhone.isNotEmpty) 'patientPhone': patientPhone,
      if (preferredWhen != null && preferredWhen.isNotEmpty) 'preferredWhen': preferredWhen,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'mode': mode,
      'amount': amount,
      'patientType': patientType,
      if (sessionType != null && sessionType.isNotEmpty) 'sessionType': sessionType,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
    }));
    final inner = body['appointment'];
    return Appointment.fromJson(
      inner is Map ? Map<String, dynamic>.from(inner) : body,
    );
  }

  /// Checks a coupon code the way the website's booking page does, through
  /// `GET /api/coupons/{code}`, and then applies the same tests the server's
  /// own pricing will — so the patient hears "not valid for this account" now
  /// rather than being quietly charged the full price later.
  ///
  /// The route answers with the whole coupon document, including the list of
  /// email addresses a restricted code was issued to. That list is read here
  /// only to compare against the patient's own address and is never kept:
  /// [CouponCheck] carries the code and its discount and nothing else.
  Future<CouponCheck> checkCoupon(String code, {String? patientEmail}) async {
    final wanted = code.trim().toUpperCase();
    if (wanted.isEmpty) return const CouponCheck.rejected('book.couponInvalid');

    dynamic raw;
    try {
      raw = await _api.get('/api/coupons/${Uri.encodeComponent(wanted)}');
    } on ApiException catch (e) {
      if (e.statusCode == 404) return const CouponCheck.rejected('book.couponNotFound');
      rethrow;
    }

    final body = _map(raw);
    final doc = body['coupon'];
    if (doc is! Map) return const CouponCheck.rejected('book.couponInvalid');

    num? number(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');

    // In the order the server checks them (quoteBooking, lib/pricing.ts), so
    // the reason given here is the one the server would have given.
    if (doc['active'] != true) return const CouponCheck.rejected('book.couponInactive');

    final expiresAt = doc['expiresAt'];
    if (expiresAt is String && expiresAt.isNotEmpty) {
      final at = DateTime.tryParse(expiresAt);
      if (at != null && at.isBefore(DateTime.now())) {
        return const CouponCheck.rejected('book.couponExpired');
      }
    }

    final maxUses = number(doc['maxUses']) ?? 0;
    final usedCount = number(doc['usedCount']) ?? 0;
    if (maxUses > 0 && usedCount >= maxUses) {
      return const CouponCheck.rejected('book.couponUsedUp');
    }

    // The server no longer sends the list of patients a restricted coupon was
    // issued to — it answers `eligible` for the signed-in caller instead.
    if (doc['restricted'] == true && body['eligible'] != true) {
      return const CouponCheck.rejected('book.couponNotForYou');
    }

    if (body['valid'] != true) return const CouponCheck.rejected('book.couponInvalid');

    final type = doc['discountType'] == 'flat' ? 'flat' : 'percent';
    final value = number(doc['discountValue']) ?? 0;
    if (value <= 0) return const CouponCheck.rejected('book.couponInvalid');

    return CouponCheck(
      valid: true,
      code: wanted,
      discountType: type,
      discountValue: value,
    );
  }

  // ── Contact ───────────────────────────────────────────────────────────────

  /// The website's "Send us a message" form (`POST /api/contact`). No sign-in
  /// needed there, and none needed here.
  ///
  /// The route stores `email`, `name` and `message` and nothing else — it has
  /// no phone field. A phone number the patient gives is added to the end of
  /// the message so the clinic still sees it, rather than being sent as a
  /// field the server would silently drop.
  ///
  /// `website` is the form's honeypot. It is sent empty, as a person's
  /// browser sends it; a value there makes the server discard the message.
  Future<void> sendContactMessage({
    required String email,
    required String message,
    String? name,
    String? phone,
  }) async {
    final text = message.trim();
    final number = phone?.trim() ?? '';
    await _api.post('/api/contact', {
      'email': email.trim(),
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'message': number.isEmpty ? text : '$text\n\nPhone: $number',
      'website': '',
    });
  }

  void close() => _api.close();
}
