import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'google_auth.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>?> register(String email, String password) async {
    try {
      final res = await _client.post('/auth/register', body: {
        'email': email,
        'password': password,
      });

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        await _client.saveTokens(data['accessToken'], data['refreshToken']);
        return data['user'];
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['error'] ?? 'Registration failed');
      }
    } catch (e) {
      debugPrint('AuthService Register error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final res = await _client.post('/auth/login', body: {
        'email': email,
        'password': password,
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await _client.saveTokens(data['accessToken'], data['refreshToken']);
        return data['user'];
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['error'] ?? 'Login failed');
      }
    } catch (e) {
      debugPrint('AuthService Login error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final res = await _client.get('/auth/me');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['user'];
      }
    } catch (e) {
      debugPrint('AuthService Me error: $e');
    }
    return null;
  }

  /// Revokes this account's refresh tokens server-side, then drops the local
  /// copies. A network failure must not strand the user signed in, so the
  /// local clear happens either way.
  ///
  /// The Google session is dropped too. Left in place, the next sign-in would
  /// silently pick the same account back up with no chance to switch.
  Future<void> logout() async {
    try {
      await _client.post('/auth/logout');
    } catch (e) {
      debugPrint('AuthService Logout error: $e');
    }
    await GoogleAuth.signOut();
    await _client.clearTokens();
  }
}
