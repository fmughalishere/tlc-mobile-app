import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Who is signed in, and what they are allowed to see.
///
/// This is the app's copy of the website's AuthContext, and it follows the
/// same two-step shape for the same reason: Firebase tells you there is a
/// user long before you know anything about them. `uid` arrives immediately
/// from the auth listener; the role — patient, doctor or admin — lives in the
/// user's Firestore document and takes a second round trip.
///
/// Getting that order wrong is how an app flashes the patient home screen at a
/// doctor for half a second before correcting itself. So `ready` stays false
/// until BOTH are known, and the splash screen waits on it.
enum Role { patient, doctor, admin, unknown }

Role roleFrom(Object? value) {
  switch (value) {
    case 'admin':
      return Role.admin;
    case 'doctor':
      return Role.doctor;
    case 'patient':
      return Role.patient;
    default:
      return Role.unknown;
  }
}

class Session extends ChangeNotifier {
  Session() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  User? _user;
  Map<String, dynamic>? _profile;
  Role _role = Role.unknown;
  bool _ready = false;

  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  Role get role => _role;

  /// False until we know both whether someone is signed in AND, if they are,
  /// what their role is. The splash screen holds on this.
  bool get ready => _ready;

  bool get signedIn => _user != null;
  String get name => (_profile?['name'] as String?)?.trim().isNotEmpty == true
      ? _profile!['name'] as String
      : (_user?.displayName ?? '');
  String? get photoURL => _profile?['photoURL'] as String? ?? _user?.photoURL;

  /// Set by the server when an account is suspended. A suspended user is
  /// signed in and must still be shown a clear message rather than a broken
  /// screen, so this is exposed rather than treated as "not signed in".
  bool get blocked => _profile?['active'] == false;

  void _onAuthChanged(User? user) {
    _user = user;
    _profileSub?.cancel();
    _profileSub = null;

    if (user == null) {
      _profile = null;
      _role = Role.unknown;
      _ready = true;
      notifyListeners();
      return;
    }

    // Live, not a one-off read: an admin changing someone's role or blocking
    // an account should take effect in the open app, not at the next restart.
    _profileSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
      (snap) {
        _profile = snap.data();
        _role = roleFrom(_profile?['role']);
        _ready = true;
        notifyListeners();
      },
      onError: (Object error) {
        // Signed in, but the profile could not be read — offline, or rules
        // refused it. Do not hang on the splash screen forever; let the app
        // through with an unknown role and let the screens say so.
        debugPrint('[Session] profile listener failed: $error');
        _ready = true;
        notifyListeners();
      },
    );
  }

  /// Signs out, and — importantly — moves the UI immediately.
  ///
  /// The naive version awaits `FirebaseAuth.signOut()` and lets the auth
  /// stream do the rest. That works only when the stream fires promptly, and
  /// on a phone with no connection it sometimes does not: the button appears
  /// to do nothing, which is the single worst outcome for a sign-out on a
  /// shared or borrowed device.
  ///
  /// So the local state is cleared and broadcast *first*. The gate above sees
  /// "nobody is signed in" on the next frame and shows the sign-in screen,
  /// whatever Firebase does afterwards. The real sign-out still runs, and
  /// still clears the stored credential; a failure there is reported to the
  /// caller so it can be shown, rather than leaving the person staring at an
  /// unchanged screen.
  Future<void> signOut() async {
    await _profileSub?.cancel();
    _profileSub = null;

    _user = null;
    _profile = null;
    _role = Role.unknown;
    _ready = true;
    notifyListeners();

    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
