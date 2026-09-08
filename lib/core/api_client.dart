import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Everything the app asks the server for.
///
/// ── Why there is no new backend ──
///
/// The website already has thirty-nine API routes behind
/// tlcmedclinics.com/api/*, and every one of them authorises the caller the
/// same way: a Firebase ID token in an `Authorization: Bearer` header, which
/// the route verifies with the Admin SDK and turns into a uid and a role.
///
/// A phone can send exactly that header. So the app is a second client of the
/// system that already exists, not a second system. Booking rules, slot
/// overlap checks, payment handling, the rating survey — all of it stays in
/// one place and cannot drift between web and mobile, because there is only
/// one copy of it.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  /// True when the server refused the caller rather than the request — the
  /// token has expired, or this account is not allowed here. The UI treats
  /// these differently: one is "sign in again", the other is "you can't".
  bool get isAuth => statusCode == 401 || statusCode == 403;

  /// Nothing reached the server at all: no connection, DNS, a timeout. Worth
  /// telling apart from a refusal, because "try again in a moment" is useful
  /// advice for one and useless for the other.
  bool get isNetwork => statusCode == 0;

  /// The thing being asked for is not there.
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? _shared,
        _ownsClient = client != null;

  /// One HTTP client for the whole app.
  ///
  /// Every screen builds its own `Repository`, and each of those used to build
  /// its own client — which meant a fresh TCP connection and a fresh TLS
  /// handshake for the first request on every screen. On a phone that is most
  /// of the wait. One shared client keeps the connection open and hands the
  /// second screen a warm socket.
  ///
  /// It is deliberately never closed. A screen closing its own repository must
  /// not take the connection away from the four other screens still using it —
  /// which is exactly what would happen if `close()` reached this.
  static final http.Client _shared = http.Client();

  /// No trailing slash. Set from AppConfig so a debug build can point at a
  /// laptop on the same wifi without touching this file.
  final String baseUrl;
  final http.Client _client;
  final bool _ownsClient;

  /// Long enough for a slow mobile connection on a cold serverless function,
  /// short enough that a spinner is never the last thing that ever happens.
  ///
  /// Without this, `http` waits indefinitely: a request that is never going to
  /// be answered leaves the screen loading until the person force-closes the
  /// app, and there is no worse outcome than that.
  static const timeout = Duration(seconds: 20);

  Future<Map<String, String>> _headers({bool json = true}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) headers['Content-Type'] = 'application/json';

    // Firebase refreshes this itself when it is close to expiring, so asking
    // for it on every call is correct and cheap — it is a cached read almost
    // every time. Forcing a refresh here would add a network round trip to
    // every single request.
    //
    // Wrapped, because a token read can itself fail offline — and when it
    // does, the request should still go out and come back as a clean 401
    // rather than as an exception from a header builder.
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken().timeout(const Duration(seconds: 10));
        if (token != null) headers['Authorization'] = 'Bearer $token';
      }
    } catch (error) {
      debugPrint('[ApiClient] could not read the ID token: $error');
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleaned = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$cleaned').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);

  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body);

  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);

  /// DELETE with a body.
  ///
  /// Unusual, and deliberate: the clinic's routes identify what to remove in
  /// the JSON body (`{ "id": "..." }`) rather than in the path, so a DELETE
  /// without one would always be a 400.
  Future<dynamic> delete(String path, [Object? body]) =>
      _send('DELETE', path, body: body);

  /// One place every request goes through, so the timeout, the network-error
  /// translation and the response decoding are written once rather than five
  /// times with three of them slightly different.
  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final uri = _uri(path, query);
    final headers = await _headers(json: body != null);
    final encoded = body == null ? null : jsonEncode(body);

    Future<http.Response> send() {
      switch (method) {
        case 'POST':
          return _client.post(uri, headers: headers, body: encoded);
        case 'PATCH':
          return _client.patch(uri, headers: headers, body: encoded);
        case 'PUT':
          return _client.put(uri, headers: headers, body: encoded);
        case 'DELETE':
          return _client.delete(uri, headers: headers, body: encoded);
        default:
          return _client.get(uri, headers: headers);
      }
    }

    try {
      final res = await send().timeout(timeout);
      return _decode(res, method, path);
    } on TimeoutException {
      throw ApiException(
        0,
        'The clinic\'s server took too long to answer. Check your connection and try again.',
      );
    } on SocketException {
      throw ApiException(0, 'No connection. Check your internet and try again.');
    } on http.ClientException catch (e) {
      // Covers a connection dropped mid-response, and a client closed under
      // the request. Neither is worth showing raw.
      debugPrint('[ApiClient] $method $path failed: $e');
      throw ApiException(0, 'The connection dropped. Please try again.');
    }
  }

  /// A response becomes either data or an exception, and nothing else.
  ///
  /// ── Why the JSON decode is guarded ──
  ///
  /// These routes answer JSON when they answer at all. When something in front
  /// of them fails — the host's own 502 page, a redirect to a login wall, a
  /// gateway timeout — what comes back is HTML, and `jsonDecode` throws a
  /// `FormatException: Unexpected character` naming a column number. That
  /// reached the screen verbatim: a patient tapping Save on their own name was
  /// shown a parser error about character 1.
  ///
  /// So a body that is not JSON is reported as what it actually is — the
  /// server not answering properly — with its status code, which is the part
  /// that is genuinely useful.
  dynamic _decode(http.Response res, String method, String path) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    final raw = res.body.trim();

    dynamic body;
    if (raw.isNotEmpty) {
      try {
        body = jsonDecode(raw);
      } catch (_) {
        debugPrint(
          '[ApiClient] $method $path returned ${res.statusCode} '
          'but not JSON: ${raw.length > 200 ? '${raw.substring(0, 200)}…' : raw}',
        );
        if (ok) {
          // A 200 with an unreadable body is a server fault, not a user one.
          throw ApiException(
            502,
            'The server answered with something the app could not read.',
          );
        }
        throw ApiException(
          res.statusCode,
          _statusMessage(res.statusCode),
        );
      }
    }

    if (ok) return body;

    // The routes write their errors for a person to read — "You can only rate
    // a completed appointment", not "ERR_INVALID_STATE" — so that message is
    // carried through rather than replaced.
    final message = body is Map && body['error'] is String
        ? body['error'] as String
        : _statusMessage(res.statusCode);
    throw ApiException(res.statusCode, message);
  }

  static String _statusMessage(int status) {
    if (status == 401) return 'Please sign in again.';
    if (status == 403) return 'You do not have permission to do that.';
    if (status == 404) return 'That is not there any more.';
    if (status == 409) return 'Somebody else got there first. Please try again.';
    if (status >= 500) return 'The clinic\'s server had a problem. Please try again.';
    return 'Something went wrong. Please try again.';
  }

  /// Closes only a client this instance created. The shared one stays open for
  /// the life of the app — see the note on `_shared`.
  void close() {
    if (_ownsClient) _client.close();
  }
}
