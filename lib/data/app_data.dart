import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/models.dart';
import 'repository.dart';

/// The data the app already has, so screens do not start by waiting.
///
/// ── Why this exists ──
///
/// Before it, every tab owned its own `FutureBuilder` and started its request
/// when it was first built. That meant the home screen began fetching services
/// at the moment it appeared — after the splash, after Firebase, after the
/// role came back — and the patient watched a spinner for a second on a screen
/// that had nothing else to show.
///
/// The services list needs no token, so there is nothing to wait for: it is
/// requested the instant the app process starts, in parallel with Firebase
/// booting. By the time the splash has finished doing what it must do anyway,
/// the answer is usually already here and Home draws with content.
///
/// Everything else — appointments, notifications, the profile — needs a signed
/// in user, so those start the moment there is one. `signedIn()` is called by
/// the session gate, not by a screen.
///
/// The rule this class follows everywhere: **keep what you had**. A refresh
/// that fails leaves the previous list on screen and records the error beside
/// it. A patient looking at their appointments on a train through a tunnel
/// should see their appointments, not an error page replacing them.
class AppData extends ChangeNotifier {
  AppData({Repository? repository}) : _repo = repository ?? Repository();

  final Repository _repo;

  List<Service> _services = const [];
  bool _servicesLoading = false;
  Object? _servicesError;
  bool _servicesLoaded = false;

  List<Appointment> _appointments = const [];
  bool _appointmentsLoading = false;
  Object? _appointmentsError;
  bool _appointmentsLoaded = false;

  List<AppNotification> _notifications = const [];
  bool _notificationsLoading = false;
  Object? _notificationsError;
  bool _notificationsLoaded = false;

  Profile? _profile;

  // ── What screens read ─────────────────────────────────────────────────────

  List<Service> get services => _services;
  bool get servicesLoading => _servicesLoading;
  Object? get servicesError => _servicesError;

  /// True once a request has come back, successfully or not. A screen shows a
  /// spinner while this is false and the list is empty — and never again after
  /// that, because a refresh should not blank out what is already there.
  bool get servicesLoaded => _servicesLoaded;

  List<Appointment> get appointments => _appointments;
  bool get appointmentsLoading => _appointmentsLoading;
  Object? get appointmentsError => _appointmentsError;
  bool get appointmentsLoaded => _appointmentsLoaded;

  List<AppNotification> get notifications => _notifications;
  bool get notificationsLoading => _notificationsLoading;
  Object? get notificationsError => _notificationsError;
  bool get notificationsLoaded => _notificationsLoaded;

  Profile? get profile => _profile;

  /// Soonest first. Sorted here rather than in three separate screens.
  List<Appointment> get upcoming {
    final list = _appointments.where((a) => a.isUpcoming).toList()
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return list;
  }

  /// Most recent first — which for a finished visit means the one that
  /// happened last, not the one booked longest ago.
  List<Appointment> get past {
    final list = _appointments.where((a) => !a.isUpcoming).toList()
      ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return list;
  }

  int get unreadCount => _notifications.where((n) => !n.read).length;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Called from main() before the first frame. Only the public catalogue —
  /// there is no user yet, and asking for one's appointments before Firebase
  /// has finished starting would just be a 401.
  void warmUp() {
    refreshServices();
  }

  /// How many appointments to hold.
  ///
  /// A patient has a handful. A doctor's Patients tab is rolled up from this
  /// same list — "a patient of Dr X" is defined by having an appointment with
  /// Dr X — so a doctor needs a much wider window or their older patients
  /// simply vanish from it. 500 is the server's own cap, and the roll-up is
  /// ordered by last-seen, so the rows that fall off past it are the ones seen
  /// longest ago.
  int _appointmentsLimit = 100;

  /// Who is signed in, kept only so a missing `users/{uid}` document can be
  /// written back. See `_healProfile`.
  String? _uid;
  String _signInName = '';
  String? _signInEmail;
  String? _signInPhone;

  /// Called by the gate the moment a signed-in user with a known role appears.
  ///
  /// The three fetches are started together, not one after another. They are
  /// independent requests to the same host, and awaiting them in a row would
  /// make the app wait for the sum of three round trips where it could wait
  /// for the longest one.
  void onSignedIn({
    bool staff = false,
    String? uid,
    String name = '',
    String? email,
    String? phone,
  }) {
    _appointmentsLimit = staff ? 500 : 100;
    _uid = uid;
    _signInName = name;
    _signInEmail = email;
    _signInPhone = phone;
    refreshAppointments();
    refreshNotifications();
    refreshProfile();
  }

  /// Called on sign-out. Not doing this is how the next person to sign in on a
  /// shared phone sees the previous patient's appointments for a second.
  void onSignedOut() {
    _appointments = const [];
    _appointmentsLoaded = false;
    _appointmentsError = null;
    _notifications = const [];
    _notificationsLoaded = false;
    _notificationsError = null;
    _profile = null;
    _uid = null;
    _signInName = '';
    _signInEmail = null;
    _signInPhone = null;
    notifyListeners();
  }

  // ── Refreshers ────────────────────────────────────────────────────────────

  Future<void> refreshServices() async {
    if (_servicesLoading) return;
    _servicesLoading = true;
    _servicesError = null;
    notifyListeners();
    try {
      _services = await _repo.services();
      _servicesError = null;
    } catch (error) {
      _servicesError = error;
      debugPrint('[AppData] services failed: $error');
    } finally {
      _servicesLoading = false;
      _servicesLoaded = true;
      notifyListeners();
    }
  }

  Future<void> refreshAppointments() async {
    if (_appointmentsLoading) return;
    _appointmentsLoading = true;
    _appointmentsError = null;
    notifyListeners();
    try {
      _appointments = await _repo.appointments(limit: _appointmentsLimit);
      _appointmentsError = null;
    } catch (error) {
      _appointmentsError = error;
      debugPrint('[AppData] appointments failed: $error');
    } finally {
      _appointmentsLoading = false;
      _appointmentsLoaded = true;
      notifyListeners();
    }
  }

  Future<void> refreshNotifications() async {
    if (_notificationsLoading) return;
    _notificationsLoading = true;
    _notificationsError = null;
    notifyListeners();
    try {
      _notifications = await _repo.notifications();
      _notificationsError = null;
    } catch (error) {
      _notificationsError = error;
      debugPrint('[AppData] notifications failed: $error');
    } finally {
      _notificationsLoading = false;
      _notificationsLoaded = true;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    try {
      _profile = await _repo.profile();
      notifyListeners();
    } on ApiException catch (error) {
      if (error.isNotFound) {
        await _healProfile();
        return;
      }
      debugPrint('[AppData] profile failed: $error');
    } catch (error) {
      debugPrint('[AppData] profile failed: $error');
    }
  }

  /// Writes the `users/{uid}` document that should already exist, then reads
  /// the profile once more.
  ///
  /// It can be missing for a real reason: an account made by phone OTP whose
  /// registration call failed after Firebase had already created the account,
  /// or one made straight in the Firebase console. That leaves a person signed
  /// in with no profile at all — every settings row blank, and a 404 on the
  /// screen that is supposed to let them fix it. Rather than telling them to
  /// sign up again, the app writes the record it expected to find. The route
  /// merges, so it cannot flatten a document that turns out to be there.
  bool _healing = false;

  Future<void> _healProfile() async {
    final uid = _uid;
    if (uid == null || _healing) return;
    _healing = true;
    try {
      await _repo.registerProfile(
        uid: uid,
        name: _signInName.trim().isEmpty ? 'Patient' : _signInName.trim(),
        email: _signInEmail,
        phone: _signInPhone,
      );
      _profile = await _repo.profile();
      notifyListeners();
    } catch (error) {
      debugPrint('[AppData] profile heal failed: $error');
    } finally {
      _healing = false;
    }
  }

  /// Saves a change and keeps the local copy in step, so the settings screen
  /// does not have to re-fetch to show what the person just typed.
  ///
  /// The change is applied locally *before* the request goes out, so the row
  /// updates the instant the dialog closes rather than after a round trip, and
  /// put back the way it was if the server refuses it. A settings screen that
  /// freezes for a second on every tap feels broken even when it is working.
  Future<void> saveProfile(Map<String, dynamic> changes) async {
    if (changes.isEmpty) return;

    final previous = _profile;
    if (previous != null) {
      _profile = previous.withChanges(changes);
      notifyListeners();
    }

    try {
      final saved = await _repo.updateProfile(changes);
      if (saved != null) {
        _profile = saved;
        notifyListeners();
      } else {
        // Accepted, but the reply carried no profile. The optimistic copy is
        // a guess at that point, so it is checked against the server — in the
        // background, because the screen is already showing the right thing
        // and has nothing to wait for.
        unawaited(refreshProfile());
      }
    } on ApiException catch (error) {
      if (error.isNotFound) {
        // The document was never written. Create it, then apply the change to
        // it — the person should not lose what they just typed to a problem
        // that is not theirs.
        await _healProfile();
        final saved = await _repo.updateProfile(changes);
        if (saved != null) {
          _profile = saved;
          notifyListeners();
        }
        return;
      }
      _profile = previous;
      notifyListeners();
      rethrow;
    } catch (error) {
      _profile = previous;
      notifyListeners();
      rethrow;
    }
  }

  // ── Small local updates ───────────────────────────────────────────────────

  /// Marks one notification read on the server and in the list we already
  /// hold, rather than refetching fifty of them to change one boolean.
  Future<void> markNotificationRead(String id) async {
    _notifications = [
      for (final n in _notifications)
        if (n.id == id)
          AppNotification(
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            read: true,
            createdAt: n.createdAt,
            appointmentId: n.appointmentId,
          )
        else
          n,
    ];
    notifyListeners();
    try {
      await _repo.markNotificationRead(id);
    } catch (error) {
      debugPrint('[AppData] mark read failed: $error');
      await refreshNotifications();
    }
  }

  Future<void> markAllNotificationsRead() async {
    _notifications = [
      for (final n in _notifications)
        AppNotification(
          id: n.id,
          title: n.title,
          message: n.message,
          type: n.type,
          read: true,
          createdAt: n.createdAt,
          appointmentId: n.appointmentId,
        ),
    ];
    notifyListeners();
    try {
      await _repo.markAllNotificationsRead();
    } catch (error) {
      debugPrint('[AppData] mark all read failed: $error');
      await refreshNotifications();
    }
  }

  @override
  void dispose() {
    _repo.close();
    super.dispose();
  }
}
