import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

/// Mirrors ApiError in frontend/src/api/client.js.
class ApiException implements Exception {
  ApiException(this.message, this.status, [this.code]);
  final String message;
  final int status;
  final String? code;

  @override
  String toString() => message;
}

/// Names the address actually in use, so a wrong API_BASE_URL is obvious.
String get _unreachable => AppConfig.isConfigured
    ? 'Cannot reach the server at ${AppConfig.apiBaseUrl} — check that the API is running.'
    : 'This build has no server address. Rebuild it with --dart-define=API_BASE_URL=https://…';

const _fallback = {
  401: 'Your session has expired — sign in again.',
  403: 'You do not have permission to do that.',
  404: 'That item no longer exists.',
  413: 'Those files are too large. Each file must be 5 MB or smaller.',
  500: 'The server could not complete that request. Try again in a moment.',
};

/// Thin JSON client over the existing Spring Boot API. Only calls endpoints
/// the web app already uses.
class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
    : _http = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'tideline.token';

  final http.Client _http;

  /// The session token is kept in the platform keystore (Keychain / EncryptedSharedPreferences).
  final FlutterSecureStorage _storage;
  String? _token;

  /// Called when the server answers 401 to a signed-in request.
  void Function()? onUnauthorized;

  String? get token => _token;

  /// Loads a remembered session token, if any.
  Future<void> restore() async {
    try {
      _token = await _storage.read(key: _tokenKey);
    } catch (_) {
      _token = null; // unreadable keystore: treat as signed out
    }
  }

  /// "Remember me" persists the token; otherwise it lives only until the app closes.
  Future<void> setToken(String token, {bool remember = true}) async {
    _token = token;
    try {
      if (remember) {
        await _storage.write(key: _tokenKey, value: token);
      } else {
        await _storage.delete(key: _tokenKey);
      }
    } catch (_) {
      // The session still works in memory if the keystore is unavailable.
    }
  }

  Future<void> clearToken() async {
    _token = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  Future<dynamic> get(
    String path, {
    Map<String, String?>? query,
    bool auth = true,
  }) => _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> put(String path, {Object? body, bool auth = true}) =>
      _send('PUT', path, body: body, auth: auth);

  Future<dynamic> delete(String path, {bool auth = true}) =>
      _send('DELETE', path, auth: auth);

  /// Headers for loading protected files (e.g. Image.network on an authenticated URL).
  Map<String, String> get authHeaders =>
      _token == null ? const {} : {'Authorization': 'Bearer $_token'};

  /// multipart/form-data POST. [json] is sent as a single `data` part with
  /// content type application/json (what @RequestPart expects); [files] are
  /// added as-is under their own field names.
  Future<dynamic> postMultipart(
    String path, {
    Object? json,
    String jsonField = 'data',
    List<http.MultipartFile> files = const [],
    bool auth = true,
    String method = 'POST',
  }) async {
    final request =
        http.MultipartRequest(method, Uri.parse('${AppConfig.apiBaseUrl}$path'))
          ..headers['Accept'] = 'application/json'
          ..files.addAll(files);
    if (json != null) {
      request.files.insert(
        0,
        http.MultipartFile.fromString(
          jsonField,
          jsonEncode(json),
          contentType: MediaType('application', 'json'),
        ),
      );
    }
    if (auth && _token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(const Duration(seconds: 90)),
      );
    } catch (_) {
      throw ApiException(_unreachable, 0);
    }
    return _decode(response, auth: auth);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String?>? query,
    Object? body,
    bool auth = true,
  }) async {
    final params = <String, String>{
      for (final e in (query ?? const <String, String?>{}).entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}$path',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final headers = <String, String>{'Accept': 'application/json'};
    if (auth && _token != null) headers['Authorization'] = 'Bearer $_token';
    if (body != null) headers['Content-Type'] = 'application/json';

    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(
        await _http.send(request).timeout(const Duration(seconds: 20)),
      );
    } catch (_) {
      throw ApiException(_unreachable, 0);
    }

    return _decode(response, auth: auth);
  }

  dynamic _decode(http.Response response, {required bool auth}) {
    dynamic payload;
    if (response.body.isNotEmpty) {
      try {
        payload = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        payload = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 && auth && _token != null) {
        onUnauthorized?.call();
      }
      final map = payload is Map<String, dynamic> ? payload : null;
      throw ApiException(
        (map?['message'] as String?) ??
            _fallback[response.statusCode] ??
            'Request failed (${response.statusCode}).',
        response.statusCode,
        map?['code'] as String?,
      );
    }
    return payload;
  }
}
