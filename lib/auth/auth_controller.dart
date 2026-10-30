import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../models/models.dart';

/// Equivalent of AuthContext.jsx: restores a stored session, logs in and out.
class AuthController extends ChangeNotifier {
  AuthController(this.api) {
    api.onUnauthorized = _expire;
  }

  final ApiClient api;

  AppUser? user;
  bool ready = false;

  bool get isAuthenticated => user != null;

  Future<void> init() async {
    await api.restore();
    if (api.token != null) {
      try {
        user = AppUser.fromJson(
          await api.get('/api/users/me') as Map<String, dynamic>,
        );
      } on ApiException catch (e) {
        // Keep the stored session through a dropped connection; only a rejected token ends it.
        if (e.status != 0) await api.clearToken();
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<AppUser> login(String email, String password, bool remember) async {
    final result = AuthResult.fromJson(
      await api.post(
            '/api/auth/login',
            body: {
              'email': email,
              'password': password,
              'rememberMe': remember,
            },
            auth: false,
          )
          as Map<String, dynamic>,
    );
    if (result.token == null) {
      throw ApiException('Sign-in did not return a session.', 0);
    }
    await api.setToken(result.token!, remember: remember);
    user = result.user;
    notifyListeners();
    return result.user;
  }

  /// Re-reads the signed-in user from the API (profile pull-to-refresh).
  Future<void> refresh() async {
    user = AppUser.fromJson(
      await api.get('/api/users/me') as Map<String, dynamic>,
    );
    notifyListeners();
  }

  /// POST /api/auth/register (multipart). Community members are signed in straight away;
  /// divers, organisations and officials get no token until an administrator verifies them.
  Future<AuthResult> register(
    Map<String, Object?> data, {
    List<http.MultipartFile> certificates = const [],
    List<http.MultipartFile> licences = const [],
  }) async {
    final result = AuthResult.fromJson(
      await api.postMultipart(
            '/api/auth/register',
            json: data,
            files: [...certificates, ...licences],
            auth: false,
          )
          as Map<String, dynamic>,
    );
    if (result.token != null) {
      await api.setToken(result.token!);
      user = result.user;
      notifyListeners();
    }
    return result;
  }

  Future<void> forgotPassword(String email) => api.post(
    '/api/auth/forgot-password',
    body: {'email': email},
    auth: false,
  );

  /// PUT /api/users/me — only the fields present in [fields] are sent.
  Future<void> updateProfile(Map<String, Object?> fields) async {
    user = AppUser.fromJson(
      await api.put('/api/users/me', body: fields) as Map<String, dynamic>,
    );
    notifyListeners();
  }

  Future<void> updateDiverProfile(Map<String, Object?> fields) async {
    user = AppUser.fromJson(
      await api.put('/api/users/me/diver-profile', body: fields)
          as Map<String, dynamic>,
    );
    notifyListeners();
  }

  /// PUT /api/users/me/avatar (multipart, one `photo` part).
  Future<void> uploadAvatar(http.MultipartFile photo) async {
    user = AppUser.fromJson(
      await api.postMultipart(
            '/api/users/me/avatar',
            method: 'PUT',
            files: [photo],
          )
          as Map<String, dynamic>,
    );
    notifyListeners();
  }

  Future<void> removeAvatar() async {
    user = AppUser.fromJson(
      await api.delete('/api/users/me/avatar') as Map<String, dynamic>,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await api.clearToken();
    user = null;
    notifyListeners();
  }

  void _expire() {
    api.clearToken();
    user = null;
    notifyListeners();
  }
}
