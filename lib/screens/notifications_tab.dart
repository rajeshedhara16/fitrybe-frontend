import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';

enum _NotifType {
  kudos,
  comment,
  followRequest,
  trybeInvite,
  achievement,
  liveActivity,
  badge,
  follow,
}

class _NotificationItem {
  _NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
    this.avatarUrl,
    this.isRead = false,
    this.actionable = false,
  });

  final String id;
  final _NotifType type;
  final String title;
  final String subtitle;
  final String time;
  final String? avatarUrl;
  bool isRead;
  final bool actionable;
  String? actionResolution; // null, 'accepted', 'declined', 'joined', 'ignored'
}

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  final Color _accent = const Color(0xFFFF5722);

  List<_NotificationItem> _today = [];
  List<_NotificationItem> _yesterday = [];
  List<_NotificationItem> _earlier = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
    try {
      final payload = await ApiService.getNotifications();
      final raw = (payload['notifications'] as List?) ?? const [];

      final today = <_NotificationItem>[];
      final yesterday = <_NotificationItem>[];
      final earlier = <_NotificationItem>[];
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

      for (final entry in raw.whereType<Map>()) {
        final item = _toItem(Map<String, dynamic>.from(entry));
        final created =
            DateTime.tryParse('${entry['createdAt'] ?? ''}')?.toLocal();
        if (created == null || created.isAfter(startOfToday)) {
          today.add(item);
        } else if (created.isAfter(startOfYesterday)) {
          yesterday.add(item);
        } else {
          earlier.add(item);
        }
      }

      if (!mounted) return;
      setState(() {
        _today = today;
        _yesterday = yesterday;
        _earlier = earlier;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Notifications load error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'We could not load your notifications.';
      });
    }
  }

  /// Maps an API notification onto the card model this screen renders.
  _NotificationItem _toItem(Map<String, dynamic> raw) {
    final actor = (raw['actor'] is Map)
        ? Map<String, dynamic>.from(raw['actor'])
        : const <String, dynamic>{};
    final actorName =
        '${actor['firstName'] ?? ''} ${actor['lastName'] ?? ''}'.trim();
    final type = _typeFrom('${raw['type'] ?? ''}');

    // The server stores the predicate ("liked your post."), so prefix the actor.
    final body = '${raw['body'] ?? ''}';
    final title = actorName.isEmpty
        ? '${raw['title'] ?? 'Notification'}'
        : '$actorName $body'.trim();

    return _NotificationItem(
      id: '${raw['id']}',
      type: type,
      title: title,
      subtitle: actorName.isEmpty ? body : '${raw['title'] ?? ''}',
      time: _relativeTime(raw['createdAt']),
      avatarUrl: ApiService.media(actor['avatarUrl'] as String?),
      isRead: raw['isRead'] == true,
      actionable: type == _NotifType.trybeInvite,
    );
  }

  static _NotifType _typeFrom(String apiType) => switch (apiType.toUpperCase()) {
        'LIKE' => _NotifType.kudos,
        'COMMENT' => _NotifType.comment,
        'FOLLOW' => _NotifType.follow,
        'TRYBE_INVITE' => _NotifType.trybeInvite,
        'ACHIEVEMENT' => _NotifType.achievement,
        'CLIQUE_INVITE' || 'CLIQUE_START' => _NotifType.liveActivity,
        'BADGE' => _NotifType.badge,
        _ => _NotifType.kudos,
      };

  static String _relativeTime(dynamic isoString) {
    final parsed = DateTime.tryParse('${isoString ?? ''}');
    if (parsed == null) return '';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool get _hasUnread => [
        ..._today,
        ..._yesterday,
        ..._earlier,
      ].any((n) => !n.isRead);

  Future<void> _markAllRead() async {
    HapticFeedback.lightImpact();
    setState(() {
      for (final n in [..._today, ..._yesterday, ..._earlier]) {
        n.isRead = true;
      }
    });
    await ApiService.markAllNotificationsRead();
  }

  Future<void> _markRead(_NotificationItem item) async {
    if (item.isRead) return;
    setState(() => item.isRead = true);
    await ApiService.markNotificationRead(item.id);
  }

  void _resolveAction(_NotificationItem item, String resolution, String message) {
    HapticFeedback.mediumImpact();
    setState(() {
      item.actionResolution = resolution;
      item.isRead = true;
    });
    ApiService.markNotificationRead(item.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _accent,
        content: Text(
          message,
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingStateView();
    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _load);
    }

    final bool isEmpty = _today.isEmpty && _yesterday.isEmpty && _earlier.isEmpty;

    if (isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      backgroundColor: const Color(0xFF1F1F22),
      child: SingleChildScrollView(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 20),
            if (_today.isNotEmpty) ...[
              _buildSectionHeader('TODAY'),
              const SizedBox(height: 12),
              ..._today.map(_buildNotificationCard),
              const SizedBox(height: 20),
            ],
            if (_yesterday.isNotEmpty) ...[
              _buildSectionHeader('YESTERDAY'),
              const SizedBox(height: 12),
              ..._yesterday.map(_buildNotificationCard),
              const SizedBox(height: 20),
            ],
            if (_earlier.isNotEmpty) ...[
              _buildSectionHeader('EARLIER'),
              const SizedBox(height: 12),
              ..._earlier.map(_buildNotificationCard),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Stay on top of your Trybe activity.',
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white38,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: _hasUnread ? _markAllRead : null,
          child: Opacity(
            opacity: _hasUnread ? 1.0 : 0.35,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2D),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.done_all_rounded, color: Colors.white70, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    'Mark all read',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String label) {
    return Text(
      label,
      style: GoogleFonts.hankenGrotesk(
        color: Colors.white38,
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  ({IconData icon, Color color}) _iconFor(_NotifType type) {
    switch (type) {
      case _NotifType.kudos:
        return (icon: Icons.favorite_rounded, color: const Color(0xFFFF5722));
      case _NotifType.comment:
        return (icon: Icons.chat_bubble_rounded, color: const Color(0xFF448AFF));
      case _NotifType.followRequest:
      case _NotifType.follow:
        return (icon: Icons.person_add_alt_1_rounded, color: const Color(0xFF81C784));
      case _NotifType.trybeInvite:
        return (icon: Icons.group_add_rounded, color: const Color(0xFFFFB300));
      case _NotifType.achievement:
        return (icon: Icons.emoji_events_rounded, color: const Color(0xFFFF5722));
      case _NotifType.liveActivity:
        return (icon: Icons.directions_run_rounded, color: const Color(0xFFE57373));
      case _NotifType.badge:
        return (icon: Icons.military_tech_rounded, color: const Color(0xFFFFB300));
    }
  }

  Widget _buildLeading(_NotificationItem item) {
    final iconSpec = _iconFor(item.type);
    if (item.avatarUrl != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: NetworkImage(item.avatarUrl!),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: iconSpec.color,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF131316), width: 2),
              ),
              child: Icon(iconSpec.icon, color: Colors.white, size: 11),
            ),
          ),
        ],
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: iconSpec.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(iconSpec.icon, color: iconSpec.color, size: 22),
    );
  }

  Widget _buildNotificationCard(_NotificationItem item) {
    final bool unread = !item.isRead;
    return GestureDetector(
      onTap: () => _markRead(item),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLeading(item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.hankenGrotesk(
                            color: unread ? Colors.white : Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white54,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.time,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white24,
                      fontSize: 10.5,
                    ),
                  ),
                  if (item.actionable) ...[
                    const SizedBox(height: 12),
                    _buildActionRow(item),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(_NotificationItem item) {
    if (item.actionResolution != null) {
      final resolved = item.actionResolution!;
      final bool positive = resolved == 'accepted' || resolved == 'joined';
      return Row(
        children: [
          Icon(
            positive ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: positive ? const Color(0xFF81C784) : Colors.white38,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            resolved == 'accepted'
                ? 'Accepted'
                : resolved == 'declined'
                    ? 'Declined'
                    : resolved == 'joined'
                        ? 'Joined'
                        : 'Ignored',
            style: GoogleFonts.hankenGrotesk(
              color: positive ? const Color(0xFF81C784) : Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    final bool isInvite = item.type == _NotifType.trybeInvite;
    final String positiveLabel = isInvite ? 'Join' : 'Accept';
    final String negativeLabel = isInvite ? 'Ignore' : 'Decline';

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _resolveAction(
              item,
              isInvite ? 'joined' : 'accepted',
              isInvite ? 'Joined the Trybe!' : 'Follow request accepted',
            ),
            child: Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                positiveLabel,
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => _resolveAction(
              item,
              isInvite ? 'ignored' : 'declined',
              isInvite ? 'Invite ignored' : 'Follow request declined',
            ),
            child: Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E2E32)),
              ),
              child: Text(
                negativeLabel,
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_rounded, color: _accent.withValues(alpha: 0.3), size: 80),
            const SizedBox(height: 16),
            Text(
              'All caught up',
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no notifications right now.',
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white54,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
