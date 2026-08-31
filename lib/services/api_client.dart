import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thin HTTP layer over the Fitrybe backend.
///
/// Owns the base URL resolution, JWT storage, and automatic access-token
/// refresh so the feature services can stay focused on payload shapes.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const String _tokenKey = 'fitrybe_access_token';
  static const String _refreshTokenKey = 'fitrybe_refresh_token';

  /// Production deployed backend host on Railway
  static const String _productionHost =
      'https://fitrybe-backend-production.up.railway.app';
  static const String _localHostAndroid = 'http://127.0.0.1:4000';
  static const String _localHostDefault = 'http://localhost:4000';

  /// Override at build time:
  /// `flutter run --dart-define=FITRYBE_API_HOST=production` or `192.168.1.50`
  static const String _hostOverride =
      String.fromEnvironment('FITRYBE_API_HOST', defaultValue: '');

  String? _resolvedOrigin;

  String get _defaultLocalHost =>
      defaultTargetPlatform == TargetPlatform.android
          ? _localHostAndroid
          : _localHostDefault;

  /// Host origin (no `/api` suffix) — also used to resolve `/uploads/...` media.
  String get origin {
    if (_resolvedOrigin != null) return _resolvedOrigin!;
    if (_hostOverride.isNotEmpty) {
      if (_hostOverride == 'production' || _hostOverride == 'prod') {
        return _productionHost;
      }
      return _hostOverride.startsWith('http')
          ? _hostOverride
          : 'http://$_hostOverride:4000';
    }
    return _productionHost;
  }

  String get baseUrl => '$origin/api';

  String get socketUrl => origin;

  /// Turns a backend-relative upload path into an absolute URL.
  /// Passes through absolute URLs (seed data uses remote image hosts).
  String? resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return path.startsWith('/') ? '$origin$path' : '$origin/$path';
  }

  String? _accessToken;
  String? _refreshToken;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
  }

  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;
  String? get token => _accessToken;

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Map<String, String> get _headers {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      map['Authorization'] = 'Bearer $_accessToken';
    }
    return map;
  }

  Uri _uriFor(String base, String endpoint) => Uri.parse('$base/api$endpoint');

  /// Executes request against primary host; if network/DNS lookup fails, seamlessly falls back.
  Future<http.Response> _execute(
    String endpoint,
    Future<http.Response> Function(Uri uri) req,
  ) async {
    final primary = origin;
    try {
      final res = await req(_uriFor(primary, endpoint));
      _resolvedOrigin = primary;
      return res;
    } catch (e) {
      // If primary host fails with network/socket/DNS error, try fallback host
      final fallback =
          primary == _productionHost ? _defaultLocalHost : _productionHost;
      if (_hostOverride.isEmpty ||
          _hostOverride == 'production' ||
          _hostOverride == 'prod') {
        try {
          final res = await req(_uriFor(fallback, endpoint));
          _resolvedOrigin = fallback;
          return res;
        } catch (_) {
          // If fallback fails too, rethrow original error
        }
      }
      rethrow;
    }
  }

  /// Runs [send], and if the access token has expired, refreshes it once and
  /// replays the request with the new credentials.
  Future<http.Response> _withRefresh(
    Future<http.Response> Function() send,
  ) async {
    final res = await send();
    if (res.statusCode == 401 && _refreshToken != null) {
      if (await refreshToken()) {
        return send();
      }
    }
    return res;
  }

  Future<http.Response> get(String endpoint) =>
      _withRefresh(() => _execute(endpoint, (uri) => http.get(uri, headers: _headers)));

  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) =>
      _withRefresh(() => _execute(
            endpoint,
            (uri) => http.post(
              uri,
              headers: _headers,
              body: body != null ? jsonEncode(body) : null,
            ),
          ));

  Future<http.Response> put(String endpoint, {Map<String, dynamic>? body}) =>
      _withRefresh(() => _execute(
            endpoint,
            (uri) => http.put(
              uri,
              headers: _headers,
              body: body != null ? jsonEncode(body) : null,
            ),
          ));

  Future<http.Response> patch(String endpoint, {Map<String, dynamic>? body}) =>
      _withRefresh(() => _execute(
            endpoint,
            (uri) => http.patch(
              uri,
              headers: _headers,
              body: body != null ? jsonEncode(body) : null,
            ),
          ));

  Future<http.Response> delete(String endpoint) =>
      _withRefresh(() => _execute(endpoint, (uri) => http.delete(uri, headers: _headers)));

  Future<http.Response> multipartPost(
    String endpoint, {
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
  }) async {
    // MultipartFile streams are single-use, so buffer them into bytes to allow
    // the request to be rebuilt on a token refresh retry.
    final buffered = <List<int>>[];
    if (files != null) {
      for (final f in files) {
        buffered.add(await f.finalize().toBytes());
      }
    }

    Future<http.Response> sendWithUri(Uri uri) async {
      final request = http.MultipartRequest('POST', uri);
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }
      if (fields != null) request.fields.addAll(fields);
      if (files != null) {
        for (var i = 0; i < files.length; i++) {
          request.files.add(http.MultipartFile.fromBytes(
            files[i].field,
            buffered[i],
            filename: files[i].filename,
            contentType: files[i].contentType,
          ));
        }
      }
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }

    return _withRefresh(() => _execute(endpoint, sendWithUri));
  }

  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;
    try {
      final res = await _execute(
        '/auth/refresh',
        (uri) => http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': _refreshToken}),
        ),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final newAccess = data['accessToken'] as String?;
        final newRefresh = data['refreshToken'] as String?;
        if (newAccess != null) {
          await saveTokens(newAccess, newRefresh ?? _refreshToken!);
          return true;
        }
      }
      await clearTokens();
      return false;
    } catch (_) {
      return false;
    }
  }
}
