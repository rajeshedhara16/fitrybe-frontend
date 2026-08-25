import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'socket_service.dart';

/// Holds the signed-in user for the lifetime of the app session.
///
/// Screens listen to [userNotifier] so profile edits (name, avatar, banner)
/// propagate without every tab refetching `/auth/me`.
class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  final ValueNotifier<Map<String, dynamic>?> userNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  Map<String, dynamic>? get user => userNotifier.value;
  String? get userId => user?['id'] as String?;

  bool get isLoggedIn => ApiClient().isAuthenticated;

  bool get onboardingCompleted => user?['onboardingCompleted'] == true;

  String get displayName {
    final first = (user?['firstName'] as String?)?.trim() ?? '';
    final last = (user?['lastName'] as String?)?.trim() ?? '';
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    final email = user?['email'] as String?;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Athlete';
  }

  String? get avatarUrl => ApiClient().resolveMediaUrl(user?['avatarUrl'] as String?);
  String? get bannerUrl => ApiClient().resolveMediaUrl(user?['bannerUrl'] as String?);

  /// Loads the current user from the API. Returns null when unauthenticated.
  Future<Map<String, dynamic>?> load() async {
    if (!ApiClient().isAuthenticated) {
      userNotifier.value = null;
      return null;
    }
    final fetched = await AuthService().getCurrentUser();
    userNotifier.value = fetched;
    if (fetched != null) {
      SocketService().connect();
    }
    return fetched;
  }

  /// Merges freshly returned user fields into the cached session user.
  void update(Map<String, dynamic>? updated) {
    if (updated == null) return;
    userNotifier.value = {...?userNotifier.value, ...updated};
  }

  Future<void> logout() async {
    SocketService().disconnect();
    await AuthService().logout();
    userNotifier.value = null;
  }
}
