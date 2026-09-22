import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// The app's half of the website's chat encryption
/// (`src/lib/chat-crypto-client.ts`), and it has to match it byte for byte:
/// a patient on the phone and a doctor on the website read the same thread.
///
///   · AES-256-GCM with a 32-byte key the server derives per thread and hands
///     out from `GET /api/chat/{threadId}/key` as `{ "key": "<base64>" }`.
///   · a fresh random 12-byte IV per message, stored base64 in `iv`.
///   · `cipherText` is base64 of the ciphertext WITH the 16-byte GCM tag
///     appended — that is what WebCrypto's `encrypt` returns.
///
/// The `cryptography` package keeps the tag apart (`SecretBox.mac`), so it is
/// glued on when encrypting and split off the end when decrypting. Getting
/// that wrong is silent: both sides would write messages the other cannot
/// read.
class ChatCrypto {
  ChatCrypto._(this._key);

  static final AesGcm _algorithm = AesGcm.with256bits();
  static const int _ivLength = 12;
  static const int _tagLength = 16;

  final SecretKey _key;

  /// Imports the thread key from the endpoint's base64. Throws a
  /// FormatException when the key is not 32 bytes — that is a server fault
  /// worth surfacing, not something to encrypt with.
  static ChatCrypto fromBase64Key(String base64Key) {
    final raw = base64.decode(base64.normalize(base64Key.trim()));
    if (raw.length != 32) {
      throw FormatException('Chat key has ${raw.length} bytes, expected 32');
    }
    return ChatCrypto._(SecretKey(Uint8List.fromList(raw)));
  }

  /// Returns the two strings the message document stores.
  Future<({String cipherText, String iv})> encrypt(String plainText) async {
    final nonce = _algorithm.newNonce();
    final box = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: _key,
      nonce: nonce,
    );
    final combined = Uint8List(box.cipherText.length + box.mac.bytes.length)
      ..setAll(0, box.cipherText)
      ..setAll(box.cipherText.length, box.mac.bytes);
    return (cipherText: base64.encode(combined), iv: base64.encode(nonce));
  }

  /// Decrypts one message, or returns [fallback]. Never throws: one corrupt
  /// or foreign message must not take the whole conversation down with it.
  Future<String> decrypt(String cipherText, String iv, {required String fallback}) async {
    try {
      final combined = base64.decode(base64.normalize(cipherText.trim()));
      final nonce = base64.decode(base64.normalize(iv.trim()));
      if (nonce.length != _ivLength || combined.length < _tagLength) return fallback;
      final split = combined.length - _tagLength;
      final box = SecretBox(
        combined.sublist(0, split),
        nonce: nonce,
        mac: Mac(combined.sublist(split)),
      );
      final clear = await _algorithm.decrypt(box, secretKey: _key);
      return utf8.decode(clear);
    } catch (error) {
      debugPrint('[ChatCrypto] could not decrypt a message: $error');
      return fallback;
    }
  }
}
