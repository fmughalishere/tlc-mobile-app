import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/api_client.dart';
import '../core/chat_crypto.dart';
import '../core/config.dart';
import '../core/session_window.dart';
import '../i18n/chat_strings.dart';
import '../models/models.dart';

/// One decrypted chat message.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.sentAt,
    required this.pending,
  });

  final String id;
  final String senderId;

  /// patient · doctor · admin — the website writes the sender's role, not
  /// their name, so the screen names people from the appointment.
  final String senderRole;
  final String text;

  /// Null only if the document has no timestamp at all.
  final DateTime? sentAt;

  /// True while this phone's own write has not reached the server yet.
  final bool pending;
}

/// Why chat is open or closed for an appointment, following the website.
///
/// On the website chat is not a general inbox: it is the "chat" consultation
/// mode, opened with the same join button as a video call and gated by the
/// same session window (`src/lib/session-window.ts`). A patient can open it
/// from the appointment's time until the session is ended; the doctor, as
/// host, may also open it early. Once ended the website offers no way back
/// into the thread, so neither does the app.
class ChatAccess {
  const ChatAccess._();

  /// Null when chat is open for this viewer, otherwise the reason (a
  /// translated sentence) it is closed.
  static String? closedReason(Appointment a, {required bool asHost, DateTime? now}) {
    final at = now ?? DateTime.now();
    if (a.mode != 'chat') return ChatStrings.t('chat.closed.notChat');
    if (a.doctorId == null || a.doctorId!.isEmpty) return ChatStrings.t('chat.closed.noDoctor');
    if (a.sessionStatus == 'ended') return ChatStrings.t('chat.closed.ended');
    if (a.status != 'confirmed') return ChatStrings.t('chat.closed.notConfirmed');
    if (SessionWindow.canJoin(a, at)) return null;
    if (asHost && SessionWindow.canStartEarly(a, at)) return null;
    return ChatStrings.t('chat.closed.notYet');
  }

  /// Whether to show the entry point at all: only on a chat consultation with
  /// a doctor, and not once the session is over or the booking cancelled.
  static bool isChatAppointment(Appointment a) =>
      a.mode == 'chat' &&
      a.doctorId != null &&
      a.doctorId!.isNotEmpty &&
      a.status != 'cancelled';
}

/// Reads and writes one appointment's chat thread — the same Firestore
/// documents the website's ChatPanel uses:
///
///   chatThreads/{appointmentId}/messages/{auto-id}
///     senderId:   uid
///     senderRole: 'patient' | 'doctor' | 'admin'
///     cipherText: base64(AES-GCM ciphertext + 16-byte tag)
///     iv:         base64(12 random bytes)
///     createdAt:  server timestamp
///
/// Nothing else is written, and no plaintext ever leaves the phone.
class ChatRepository {
  ChatRepository({required this.threadId, ApiClient? api})
      : _api = api ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  /// The appointment id. The website's key route and Firestore rules both
  /// look the appointment up by this id.
  final String threadId;
  final ApiClient _api;

  /// Only the tail of a long consultation, as on the website.
  static const messageLimit = 200;

  ChatCrypto? _crypto;
  Future<ChatCrypto>? _pendingKey;
  final Map<String, String> _plainCache = {};

  CollectionReference<Map<String, dynamic>> get _messages => FirebaseFirestore.instance
      .collection('chatThreads')
      .doc(threadId)
      .collection('messages');

  String? get viewerUid => FirebaseAuth.instance.currentUser?.uid;

  /// Fetches the thread key once and keeps it for as long as this repository
  /// lives — in memory only, never on disk, as the website does.
  ///
  /// A failed fetch is not cached, so "try again" really tries again.
  Future<ChatCrypto> key() {
    final ready = _crypto;
    if (ready != null) return Future.value(ready);
    return _pendingKey ??= _fetchKey().then((crypto) {
      _crypto = crypto;
      return crypto;
    }).whenComplete(() => _pendingKey = null);
  }

  Future<ChatCrypto> _fetchKey() async {
    final body = await _api.get('/api/chat/${Uri.encodeComponent(threadId)}/key');
    final raw = body is Map ? body['key'] : null;
    if (raw is! String || raw.isEmpty) {
      throw ApiException(502, ChatStrings.t('chat.keyError'));
    }
    return ChatCrypto.fromBase64Key(raw);
  }

  /// The conversation, oldest first, decrypted — ordered exactly like the
  /// website: `orderBy('createdAt', 'asc')` with `limitToLast(200)`.
  ///
  /// Each message is decrypted once; later snapshots reuse the result.
  Stream<List<ChatMessage>> messages() async* {
    final crypto = await key();
    final query = _messages.orderBy('createdAt').limitToLast(messageLimit);
    await for (final snap in query.snapshots(includeMetadataChanges: true)) {
      final out = <ChatMessage>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        var text = _plainCache[doc.id];
        if (text == null) {
          text = await crypto.decrypt(
            (data['cipherText'] as String?) ?? '',
            (data['iv'] as String?) ?? '',
            fallback: ChatStrings.t('chat.undecryptable'),
          );
          _plainCache[doc.id] = text;
        }
        final created = data['createdAt'];
        out.add(ChatMessage(
          id: doc.id,
          senderId: (data['senderId'] as String?) ?? '',
          senderRole: (data['senderRole'] as String?) ?? '',
          text: text,
          // A server timestamp reads as null until the write is acknowledged;
          // "now" is the honest estimate for a message this phone just sent.
          sentAt: created is Timestamp
              ? created.toDate()
              : (doc.metadata.hasPendingWrites ? DateTime.now() : null),
          pending: doc.metadata.hasPendingWrites,
        ));
      }
      yield out;
    }
  }

  /// Encrypts and writes one message with exactly the fields the website
  /// writes. The plaintext is cached under the new id so this phone does not
  /// decrypt its own message back.
  Future<void> send(String text, {required String senderRole}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final uid = viewerUid;
    if (uid == null) throw ApiException(401, ChatStrings.t('chat.sendError'));

    final crypto = await key();
    final sealed = await crypto.encrypt(trimmed);
    final ref = _messages.doc();
    _plainCache[ref.id] = trimmed;
    await ref.set(<String, dynamic>{
      'senderId': uid,
      'senderRole': senderRole,
      'cipherText': sealed.cipherText,
      'iv': sealed.iv,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void close() => _api.close();
}
