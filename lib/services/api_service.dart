import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Single facade over the Fitrybe REST API.
///
/// Every call routes through [ApiClient] so auth headers and access-token
/// refresh are handled in one place. Read helpers degrade to empty
/// collections/null so screens can render an empty state instead of crashing,
/// while write helpers surface failures via [ApiException].
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiService {
  static final ApiClient _client = ApiClient();

  static String get baseUrl => _client.baseUrl;

  static String? media(String? path) => _client.resolveMediaUrl(path);

  // ── internals ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> _decodeMap(http.Response res) {
    if (res.body.isEmpty) return const {};
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  /// Throws [ApiException] carrying the backend's `error` message on non-2xx.
  static Map<String, dynamic> _ensureOk(http.Response res) {
    final body = _decodeMap(res);
    if (res.statusCode >= 300) {
      throw ApiException(
        res.statusCode,
        (body['error'] as String?) ?? 'Request failed (${res.statusCode})',
      );
    }
    return body;
  }

  static List<Map<String, dynamic>> _listOf(
      http.Response res, String key) {
    if (res.statusCode >= 300) return const [];
    final body = _decodeMap(res);
    final raw = body[key];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static String _query(Map<String, dynamic> params) {
    final entries = params.entries
        .where((e) => e.value != null && '${e.value}'.isNotEmpty)
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent('${e.value}')}');
    return entries.isEmpty ? '' : '?${entries.join('&')}';
  }

  static Future<List<http.MultipartFile>> _filesFrom(
    String field,
    List<File> files,
  ) async {
    final out = <http.MultipartFile>[];
    for (final f in files) {
      out.add(await http.MultipartFile.fromPath(
        field,
        f.path,
        filename: f.path.split(Platform.pathSeparator).last,
      ));
    }
    return out;
  }

  // ── 1. AUTH & ONBOARDING ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register(
      String email, String password) async {
    final res = await _client
        .post('/auth/register', body: {'email': email, 'password': password});
    final data = _ensureOk(res);
    if (data['accessToken'] != null) {
      await _client.saveTokens(data['accessToken'], data['refreshToken'] ?? '');
    }
    return data;
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final res = await _client
        .post('/auth/login', body: {'email': email, 'password': password});
    final data = _ensureOk(res);
    if (data['accessToken'] != null) {
      await _client.saveTokens(data['accessToken'], data['refreshToken'] ?? '');
    }
    return data;
  }

  static Future<Map<String, dynamic>?> me() async {
    final res = await _client.get('/auth/me');
    if (res.statusCode >= 300) return null;
    return _decodeMap(res)['user'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> updateProfile(
      Map<String, dynamic> body) async {
    final res = await _client.patch('/users/me', body: body);
    return _ensureOk(res)['user'] as Map<String, dynamic>?;
  }

  static Future<void> changePassword(
      String currentPassword, String newPassword) async {
    final res = await _client.post('/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    _ensureOk(res);
  }

  // ── 2. FEED & POSTS ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getFeed({
    String? authorId,
    String? type,
    String? cursor,
    int limit = 20,
  }) async {
    final res = await _client.get('/posts${_query({
          'authorId': authorId,
          'type': type,
          'cursor': cursor,
          'limit': limit,
        })}');
    return _listOf(res, 'posts');
  }

  static Future<Map<String, dynamic>?> createPost({
    required String caption,
    String type = 'Update',
    String audience = 'EVERYONE',
    String? locationTag,
    String? activityId,
    List<File> images = const [],
  }) async {
    final fields = <String, String>{
      'caption': caption,
      'type': type,
      'audience': audience,
      if (locationTag != null && locationTag.isNotEmpty)
        'locationTag': locationTag,
      if (activityId != null) 'activityId': activityId,
    };
    final res = await _client.multipartPost(
      '/posts',
      fields: fields,
      files: images.isEmpty ? null : await _filesFrom('images', images),
    );
    return _ensureOk(res)['post'] as Map<String, dynamic>?;
  }

  static Future<bool> setLiked(String postId, bool liked) async {
    final res = liked
        ? await _client.post('/posts/$postId/like')
        : await _client.delete('/posts/$postId/like');
    return res.statusCode < 300;
  }

  static Future<bool> deletePost(String postId) async {
    final res = await _client.delete('/posts/$postId');
    return res.statusCode < 300;
  }

  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final res = await _client.get('/posts/$postId/comments');
    return _listOf(res, 'comments');
  }

  static Future<Map<String, dynamic>?> addComment(
      String postId, String text) async {
    final res =
        await _client.post('/posts/$postId/comments', body: {'text': text});
    return _ensureOk(res)['comment'] as Map<String, dynamic>?;
  }

  // ── 3. ACTIVITIES & ANALYTICS ──────────────────────────────────────────────

  static Future<Map<String, dynamic>?> logActivity(
      Map<String, dynamic> activity) async {
    final res = await _client.post('/activities', body: activity);
    return _ensureOk(res)['activity'] as Map<String, dynamic>?;
  }

  static Future<List<Map<String, dynamic>>> getActivities({
    String? userId,
    String? type,
    int limit = 20,
  }) async {
    final res = await _client.get('/activities${_query({
          'userId': userId,
          'type': type,
          'limit': limit,
        })}');
    return _listOf(res, 'activities');
  }

  static Future<Map<String, dynamic>> getAnalytics() async {
    final res = await _client.get('/activities/analytics');
    if (res.statusCode >= 300) return const {};
    return _decodeMap(res);
  }

  static Future<bool> deleteActivity(String activityId) async {
    final res = await _client.delete('/activities/$activityId');
    return res.statusCode < 300;
  }

  // ── 4. GOALS ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getGoals() async {
    final res = await _client.get('/goals');
    if (res.statusCode >= 300) return const {};
    return _decodeMap(res);
  }

  static Future<Map<String, dynamic>?> updateGoals(
      Map<String, dynamic> goals) async {
    final res = await _client.put('/goals', body: goals);
    return _ensureOk(res)['goal'] as Map<String, dynamic>?;
  }

  // ── 5. TRYBES ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getTrybes({
    String? category,
    String? search,
    bool? mine,
    int limit = 20,
  }) async {
    final res = await _client.get('/trybes${_query({
          'category': category,
          'search': search,
          'mine': mine == true ? 'true' : null,
          'limit': limit,
        })}');
    return _listOf(res, 'trybes');
  }

  static Future<Map<String, dynamic>?> getTrybe(String trybeId) async {
    final res = await _client.get('/trybes/$trybeId');
    if (res.statusCode >= 300) return null;
    return _decodeMap(res)['trybe'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> createTrybe({
    required String name,
    String? description,
    String? category,
    String? location,
    bool isPublic = true,
    List<String> activityInterests = const [],
    File? image,
  }) async {
    final fields = <String, String>{
      'name': name,
      'isPublic': isPublic.toString(),
      if (description != null && description.isNotEmpty)
        'description': description,
      if (category != null && category.isNotEmpty) 'category': category,
      if (location != null && location.isNotEmpty) 'location': location,
      // Multipart fields can't repeat a key; the backend splits this list.
      if (activityInterests.isNotEmpty)
        'activityInterests': activityInterests.join(','),
    };
    final res = await _client.multipartPost(
      '/trybes',
      fields: fields,
      files: image == null ? null : await _filesFrom('image', [image]),
    );
    return _ensureOk(res)['trybe'] as Map<String, dynamic>?;
  }

  static Future<List<Map<String, dynamic>>> getTrybeMembers(
      String trybeId) async {
    final res = await _client.get('/trybes/$trybeId/members');
    return _listOf(res, 'members');
  }

  static Future<List<Map<String, dynamic>>> getTrybeLeaderboard(
      String trybeId) async {
    final res = await _client.get('/trybes/$trybeId/leaderboard');
    return _listOf(res, 'leaderboard');
  }

  static Future<List<Map<String, dynamic>>> getTrybePosts(
      String trybeId) async {
    final res = await _client.get('/trybes/$trybeId/posts');
    return _listOf(res, 'posts');
  }

  static Future<bool> setTrybeMembership(String trybeId, bool join) async {
    final res = join
        ? await _client.post('/trybes/$trybeId/join')
        : await _client.delete('/trybes/$trybeId/join');
    return res.statusCode < 300;
  }

  // ── 6. CLIQUES (live group sessions) ───────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getCliques({String? status}) async {
    final res = await _client.get('/cliques${_query({'status': status})}');
    return _listOf(res, 'sessions');
  }

  static Future<Map<String, dynamic>?> getClique(String sessionId) async {
    final res = await _client.get('/cliques/$sessionId');
    if (res.statusCode >= 300) return null;
    return _decodeMap(res)['session'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> createClique(
      Map<String, dynamic> body) async {
    final res = await _client.post('/cliques', body: body);
    return _ensureOk(res)['session'] as Map<String, dynamic>?;
  }

  static Future<bool> joinClique(String sessionId) async {
    final res = await _client.post('/cliques/$sessionId/join');
    return res.statusCode < 300;
  }

  static Future<bool> leaveClique(String sessionId) async {
    final res = await _client.post('/cliques/$sessionId/leave');
    return res.statusCode < 300;
  }

  static Future<Map<String, dynamic>?> updateCliqueStatus(
      String sessionId, String status) async {
    final res = await _client
        .patch('/cliques/$sessionId/status', body: {'status': status});
    return _ensureOk(res)['session'] as Map<String, dynamic>?;
  }

  // ── 7. CHAT ────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getConversations() async {
    final res = await _client.get('/chat/conversations');
    return _listOf(res, 'conversations');
  }

  /// Returns the id of the direct/Trybe conversation, creating it on first use.
  static Future<String?> createConversation({
    String? userId,
    String? trybeId,
  }) async {
    final res = await _client.post('/chat/conversations', body: {
      if (userId != null) 'recipientId': userId,
      if (trybeId != null) 'trybeId': trybeId,
    });
    return _ensureOk(res)['conversationId'] as String?;
  }

  /// Uploads a chat attachment and returns its absolute URL.
  static Future<String?> uploadChatImage(File file) async {
    final res = await _client.multipartPost('/chat/upload',
        files: await _filesFrom('image', [file]));
    return _ensureOk(res)['url'] as String?;
  }

  static Future<List<Map<String, dynamic>>> getMessages(
      String conversationId) async {
    final res =
        await _client.get('/chat/conversations/$conversationId/messages');
    return _listOf(res, 'messages');
  }

  static Future<Map<String, dynamic>?> sendMessage(
    String conversationId,
    String text, {
    String? mediaUrl,
  }) async {
    final res = await _client.post(
      '/chat/conversations/$conversationId/messages',
      body: {
        'text': text,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
      },
    );
    return _ensureOk(res)['message'] as Map<String, dynamic>?;
  }

  static Future<void> markConversationRead(String conversationId) async {
    await _client.post('/chat/conversations/$conversationId/read');
  }

  // ── 8. NOTIFICATIONS ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getNotifications(
      {bool unreadOnly = false}) async {
    final res = await _client
        .get('/notifications${_query({'unreadOnly': unreadOnly ? 'true' : null})}');
    if (res.statusCode >= 300) return const {'notifications': [], 'unreadCount': 0};
    return _decodeMap(res);
  }

  static Future<bool> markNotificationRead(String id) async {
    final res = await _client.patch('/notifications/$id/read');
    return res.statusCode < 300;
  }

  static Future<bool> markAllNotificationsRead() =>
      markNotificationRead('all');

  static Future<bool> deleteNotification(String id) async {
    final res = await _client.delete('/notifications/$id');
    return res.statusCode < 300;
  }

  // ── 9. USERS & SOCIAL GRAPH ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final res = await _client.get('/users/$userId');
    if (res.statusCode >= 300) return const {};
    return _decodeMap(res);
  }

  static Future<List<Map<String, dynamic>>> searchUsers(
    String query, {
    bool suggested = false,
    int limit = 20,
  }) async {
    final res = await _client.get('/users/search${_query({
          'query': query,
          'suggested': suggested ? 'true' : null,
          'limit': limit,
        })}');
    return _listOf(res, 'users');
  }

  static Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    final res = await _client.get('/users/$userId/followers');
    return _listOf(res, 'followers');
  }

  static Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    final res = await _client.get('/users/$userId/following');
    return _listOf(res, 'following');
  }

  static Future<bool> setFollowing(String userId, bool follow) async {
    final res = follow
        ? await _client.post('/users/$userId/follow')
        : await _client.delete('/users/$userId/follow');
    return res.statusCode < 300;
  }

  static Future<Map<String, dynamic>?> uploadAvatar(File file) async {
    final res = await _client.multipartPost('/users/me/avatar',
        files: await _filesFrom('avatar', [file]));
    return _ensureOk(res)['user'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> uploadBanner(File file) async {
    final res = await _client.multipartPost('/users/me/banner',
        files: await _filesFrom('banner', [file]));
    return _ensureOk(res)['user'] as Map<String, dynamic>?;
  }

  // ── 10. SUBSCRIPTION & ACHIEVEMENTS ────────────────────────────────────────

  static Future<Map<String, dynamic>> getSubscriptionStatus() async {
    final res = await _client.get('/subscription/status');
    if (res.statusCode >= 300) return const {'isPro': false};
    return _decodeMap(res);
  }

  static Future<Map<String, dynamic>> subscribe(String plan) async {
    final res = await _client.post('/subscription/subscribe', body: {'plan': plan});
    return _ensureOk(res);
  }

  static Future<Map<String, dynamic>> cancelSubscription() async {
    final res = await _client.post('/subscription/cancel');
    return _ensureOk(res);
  }

  static Future<Map<String, dynamic>> getAchievements() async {
    final res = await _client.get('/achievements');
    if (res.statusCode >= 300) {
      return const {'unlockedMap': {}, 'unlockedCount': 0, 'totalCount': 0};
    }
    return _decodeMap(res);
  }

  static Future<Map<String, dynamic>?> unlockAchievement(
      String achievementId) async {
    try {
      final res = await _client
          .post('/achievements/unlock', body: {'achievementId': achievementId});
      return _ensureOk(res);
    } catch (e) {
      debugPrint('unlockAchievement error: $e');
      return null;
    }
  }
}
