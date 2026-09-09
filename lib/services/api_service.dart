import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
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

  /// Content type for an upload, derived from its extension.
  ///
  /// `MultipartFile.fromPath` does not sniff — it labels every file
  /// `application/octet-stream`, which the server has no reason to treat as an
  /// image. Sending the real type is what lets an upload be recognised.
  static MediaType _mediaTypeFor(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'gif':
        return MediaType('image', 'gif');
      case 'heic':
      case 'heif':
        return MediaType('image', 'heic');
      case 'jpg':
      case 'jpeg':
      default:
        return MediaType('image', 'jpeg');
    }
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
        contentType: _mediaTypeFor(f.path),
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

  /// Exchanges a provider ID token for a Fitrybe session.
  ///
  /// The server verifies the token against the provider before it issues
  /// anything, so this call carries no email or name of its own — whatever the
  /// app claimed would be unsigned, and the token already says it.
  ///
  /// [firstName] and [lastName] exist only for Apple, which puts no name in its
  /// token and volunteers one exactly once. The server uses them to fill a
  /// blank on a new account and nothing else.
  static Future<Map<String, dynamic>> socialLogin(
    String provider,
    String idToken, {
    String? firstName,
    String? lastName,
  }) async {
    final res = await _client.post('/auth/social', body: {
      'provider': provider,
      'idToken': idToken,
      'firstName': ?firstName,
      'lastName': ?lastName,
    });
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
    final data = _ensureOk(res);
    // The change signs every other device out, so the server issues this one a
    // freshly versioned pair. Storing them keeps the current session alive.
    if (data['accessToken'] != null) {
      await _client.saveTokens(data['accessToken'], data['refreshToken'] ?? '');
    }
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
      'activityId': ?activityId,
    };
    final res = await _client.multipartPost(
      '/posts',
      fields: fields,
      files: images.isEmpty ? null : await _filesFrom('images', images),
    );
    return _ensureOk(res)['post'] as Map<String, dynamic>?;
  }

  /// One post, with its live counts and the caller's own like state.
  ///
  /// A card hands the detail screen whatever it was holding, which may be a
  /// few minutes old or, from a surface that lists posts differently, missing
  /// the counts altogether. Returns null if the post is gone or hidden.
  static Future<Map<String, dynamic>?> getPost(String postId) async {
    final res = await _client.get('/posts/$postId');
    if (res.statusCode >= 300) return null;
    return _decodeMap(res)['post'] as Map<String, dynamic>?;
  }

  static Future<bool> setLiked(String postId, bool liked) async {
    final res = liked
        ? await _client.post('/posts/$postId/like')
        : await _client.delete('/posts/$postId/like');
    return res.statusCode < 300;
  }

  /// Edits a post's text. Only the author may do this.
  static Future<Map<String, dynamic>?> updatePost(
    String postId, {
    String? caption,
    String? locationTag,
  }) async {
    final res = await _client.patch('/posts/$postId', body: {
      'caption': ?caption,
      'locationTag': ?locationTag,
    });
    return _ensureOk(res)['post'] as Map<String, dynamic>?;
  }

  static Future<bool> deletePost(String postId) async {
    final res = await _client.delete('/posts/$postId');
    return res.statusCode < 300;
  }

  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final res = await _client.get('/posts/$postId/comments');
    return _listOf(res, 'comments');
  }

  /// Adds a comment, or a reply when [parentId] is given.
  static Future<Map<String, dynamic>?> addComment(
    String postId,
    String text, {
    String? parentId,
  }) async {
    final res = await _client.post('/posts/$postId/comments', body: {
      'text': text,
      'parentId': ?parentId,
    });
    return _ensureOk(res)['comment'] as Map<String, dynamic>?;
  }

  /// Likes or unlikes a comment, returning its new like count.
  static Future<int?> setCommentLiked(
    String postId,
    String commentId,
    bool liked,
  ) async {
    final path = '/posts/$postId/comments/$commentId/like';
    final res = liked ? await _client.post(path) : await _client.delete(path);
    if (res.statusCode >= 300) return null;
    return (_decodeMap(res)['likeCount'] as num?)?.toInt();
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

  /// Removes the goal for one period, leaving the others in place.
  /// [period] is DAILY, WEEKLY or MONTHLY.
  static Future<bool> deleteGoal(String period) async {
    final res = await _client.delete('/goals/${period.toUpperCase()}');
    return res.statusCode < 300;
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

  static Future<bool> inviteToTrybe(String trybeId, String userId) async {
    final res = await _client
        .post('/trybes/$trybeId/invite', body: {'userId': userId});
    return res.statusCode < 300;
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

  /// Accepts an invite and enters the lobby. Throws [ApiException] with the
  /// server's reason when the session is invite-only or already finished.
  static Future<void> joinClique(String sessionId) async {
    final res = await _client.post('/cliques/$sessionId/join');
    _ensureOk(res);
  }

  static Future<bool> leaveClique(String sessionId) async {
    final res = await _client.post('/cliques/$sessionId/leave');
    return res.statusCode < 300;
  }

  static Future<bool> inviteToClique(String sessionId, String userId) async {
    final res = await _client
        .post('/cliques/$sessionId/invite', body: {'userId': userId});
    return res.statusCode < 300;
  }

  /// Sets the caller's lobby readiness for a clique session.
  static Future<bool> setCliqueReady(String sessionId, bool isReady) async {
    final res = await _client
        .patch('/cliques/$sessionId/ready', body: {'isReady': isReady});
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
      'recipientId': ?userId,
      'trybeId': ?trybeId,
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
    String? replyToId,
  }) async {
    final res = await _client.post(
      '/chat/conversations/$conversationId/messages',
      body: {
        'text': text,
        'mediaUrl': ?mediaUrl,
        'replyToId': ?replyToId,
      },
    );
    return _ensureOk(res)['message'] as Map<String, dynamic>?;
  }

  /// Removes one of your own messages for everyone in the thread.
  static Future<bool> deleteMessage(
    String conversationId,
    String messageId,
  ) async {
    final res = await _client
        .delete('/chat/conversations/$conversationId/messages/$messageId');
    return res.statusCode < 300;
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
