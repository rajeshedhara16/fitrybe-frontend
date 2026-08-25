import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_detail_screen.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';
import '../widgets/user_avatar.dart';

class MessagingScreen extends StatefulWidget {
  static const routeName = '/MessagingScreen';

  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> with SingleTickerProviderStateMixin {
  final Color _accent = const Color(0xFFFF5722);
  final Color _bg = const Color(0xFF131316);
  final Color _cardBg = const Color(0xFF1E1E22);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: All, 1: Direct, 2: Trybes



  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (mounted) setState(() => _error = null);
    try {
      final fetched = await ApiService.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = fetched.map(_normalizeConversation).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Messaging load error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'We could not load your messages.';
      });
    }
  }

  /// Flattens an API conversation into the row shape this list renders.
  Map<String, dynamic> _normalizeConversation(Map<String, dynamic> raw) {
    final last = (raw['lastMessage'] is Map)
        ? Map<String, dynamic>.from(raw['lastMessage'])
        : const <String, dynamic>{};
    final isTrybe = '${raw['type']}'.toUpperCase() != 'DIRECT';
    final senderName = '${last['senderName'] ?? ''}'.trim();
    final text = '${last['text'] ?? ''}';

    return {
      'id': '${raw['id']}',
      'type': isTrybe ? 'trybe' : 'direct',
      'name': '${raw['title'] ?? (isTrybe ? 'Trybe chat' : 'Conversation')}',
      'sub': isTrybe ? '${raw['membersCount'] ?? 0} members' : 'Direct message',
      'avatar': ApiService.media(raw['avatarUrl'] as String?),
      // Group threads prefix the sender so you can tell who spoke.
      'lastMessage': text.isEmpty
          ? 'No messages yet'
          : (isTrybe && senderName.isNotEmpty ? '$senderName: $text' : text),
      'time': _relativeTime(last['createdAt'] ?? raw['updatedAt']),
      'unread': (raw['unreadCount'] as num?)?.toInt() ?? 0,
      'isOnline': false,
    };
  }

  static String _relativeTime(dynamic isoString) {
    final parsed = DateTime.tryParse('${isoString ?? ''}');
    if (parsed == null) return '';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openChat(Map<String, dynamic> chatData) async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          chatId: chatData['id'],
          name: chatData['name'],
          avatar: chatData['avatar'] as String?,
          isTrybe: chatData['type'] == 'trybe',
          isOnline: chatData['isOnline'] ?? false,
        ),
      ),
    );
    // Refresh so read state and the last message line stay accurate.
    _loadConversations();
  }

  void _showNewChatDialog() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'New Message',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _accent.withValues(alpha: 0.15),
                  child: Icon(Icons.person_add_rounded, color: _accent),
                ),
                title: Text(
                  'New Direct Message',
                  style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Chat 1-on-1 with a friend or athlete',
                  style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showPeoplePicker();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _accent.withValues(alpha: 0.15),
                  child: Icon(Icons.groups_rounded, color: _accent),
                ),
                title: Text(
                  'New Trybe Group Chat',
                  style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Start a conversation with Trybe members',
                  style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showTrybePicker();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  /// Pick an athlete to start (or reopen) a direct conversation with.
  void _showPeoplePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        List<Map<String, dynamic>> people = [];
        bool loading = true;
        Timer? debounce;

        return StatefulBuilder(builder: (ctx, setSheetState) {
          if (loading) {
            ApiService.searchUsers('', limit: 30).then((users) {
              people = users;
              loading = false;
              setSheetState(() {});
            }).catchError((_) {
              loading = false;
              setSheetState(() {});
            });
          }

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (val) {
                      debounce?.cancel();
                      debounce =
                          Timer(const Duration(milliseconds: 350), () async {
                        people = await ApiService.searchUsers(val.trim(), limit: 30);
                        setSheetState(() {});
                      });
                    },
                    style: GoogleFonts.hankenGrotesk(
                        color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Colors.white38, size: 20),
                      hintText: 'Search athletes...',
                      hintStyle: GoogleFonts.hankenGrotesk(
                          color: Colors.white30, fontSize: 13.5),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: loading
                        ? const LoadingStateView()
                        : people.isEmpty
                            ? EmptyStateView(
                                icon: Icons.person_search_rounded,
                                title: 'No athletes found',
                                message:
                                    'Try a different name, or invite friends to Fitrybe.',
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: people.length,
                                itemBuilder: (ctx, idx) {
                                  final user = people[idx];
                                  final name =
                                      '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                                          .trim();
                                  final display = name.isEmpty
                                      ? 'Fitrybe Athlete'
                                      : name;
                                  final avatar = ApiService.media(
                                      user['avatarUrl'] as String?);

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: UserAvatar(
                                        url: avatar,
                                        fallbackName: display,
                                        radius: 20),
                                    title: Text(display,
                                        style: GoogleFonts.hankenGrotesk(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                      '${user['location'] ?? 'Fitrybe community'}',
                                      style: GoogleFonts.hankenGrotesk(
                                          color: Colors.white38, fontSize: 12),
                                    ),
                                    onTap: () async {
                                      final id = await ApiService
                                          .createConversation(
                                              userId: user['id'] as String?);
                                      if (!mounted || id == null) return;
                                      Navigator.pop(sheetCtx);
                                      _openChat({
                                        'id': id,
                                        'name': display,
                                        'avatar': avatar,
                                        'type': 'direct',
                                      });
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  /// Pick one of the user's Trybes to open its group conversation.
  void _showTrybePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        List<Map<String, dynamic>> trybes = [];
        bool loading = true;

        return StatefulBuilder(builder: (ctx, setSheetState) {
          if (loading) {
            ApiService.getTrybes(mine: true).then((result) {
              trybes = result;
              loading = false;
              setSheetState(() {});
            }).catchError((_) {
              loading = false;
              setSheetState(() {});
            });
          }

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: loading
                        ? const LoadingStateView()
                        : trybes.isEmpty
                            ? EmptyStateView(
                                icon: Icons.groups_rounded,
                                title: 'No Trybes yet',
                                message:
                                    'Join a Trybe from the Trybes tab to start a group chat.',
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: trybes.length,
                                itemBuilder: (ctx, idx) {
                                  final trybe = trybes[idx];
                                  final name = '${trybe['name'] ?? 'Trybe'}';
                                  final avatar = ApiService.media(
                                      trybe['imageUrl'] as String?);

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: UserAvatar(
                                        url: avatar,
                                        fallbackName: name,
                                        radius: 20),
                                    title: Text(name,
                                        style: GoogleFonts.hankenGrotesk(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                      '${trybe['memberCount'] ?? 0} members',
                                      style: GoogleFonts.hankenGrotesk(
                                          color: Colors.white38, fontSize: 12),
                                    ),
                                    onTap: () async {
                                      final id =
                                          await ApiService.createConversation(
                                              trybeId: trybe['id'] as String?);
                                      if (!mounted || id == null) return;
                                      Navigator.pop(sheetCtx);
                                      _openChat({
                                        'id': id,
                                        'name': name,
                                        'avatar': avatar,
                                        'type': 'trybe',
                                      });
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredConversations = _conversations.where((c) {
      if (_selectedFilterIndex == 1 && c['type'] != 'direct') return false;
      if (_selectedFilterIndex == 2 && c['type'] != 'trybe') return false;
      if (_searchQuery.isNotEmpty) {
        final name = c['name'].toString().toLowerCase();
        final msg = c['lastMessage'].toString().toLowerCase();
        return name.contains(_searchQuery) || msg.contains(_searchQuery);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Messages',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _showNewChatDialog,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: SvgPicture.string(
                '''<svg xmlns="http://www.w3.org/2000/svg" width="120" height="100" viewBox="0 0 120 100">
                  <defs>
                    <mask id="cutout">
                      <rect width="120" height="100" fill="white" />
                      <rect x="36" y="24" width="48" height="12" rx="6" fill="black" />
                      <rect x="36" y="42" width="32" height="12" rx="6" fill="black" />
                      <circle cx="96" cy="76" r="21" fill="black" />
                    </mask>
                  </defs>
                  <g fill="currentColor" mask="url(#cutout)">
                    <ellipse cx="60" cy="40" rx="42" ry="33"/>
                    <path d="M24 56 L17 68 Q14 73 20 73 L60 73 Z"/>
                  </g>
                  <g fill="currentColor">
                    <rect x="79" y="70.5" width="34" height="11" rx="5.5"/>
                    <rect x="90.5" y="59" width="11" height="34" rx="5.5"/>
                  </g>
                </svg>''',
                height: 25,
                colorFilter: const ColorFilter.mode(
                  Colors.white70,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                hintText: 'Search messages or friends...',
                hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white30, fontSize: 13.5),
                filled: true,
                fillColor: _cardBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),



          // Filter Segmented Pills (All / Direct / Trybes)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                _buildFilterChip('All', 0),
                const SizedBox(width: 8),
                _buildFilterChip('Direct Messages', 1),
                const SizedBox(width: 8),
                _buildFilterChip('Trybes', 2),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Conversations List
          Expanded(
            child: _isLoading
                ? const LoadingStateView()
                : _error != null
                    ? ErrorStateView(
                        message: _error!, onRetry: _loadConversations)
                    : filteredConversations.isEmpty
                ? EmptyStateView(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: _conversations.isEmpty
                        ? 'No conversations yet'
                        : 'No conversations found',
                    message: _conversations.isEmpty
                        ? 'Start a chat with an athlete or one of your Trybes.'
                        : 'Nothing matches your search or filter.',
                    actionLabel:
                        _conversations.isEmpty ? 'New message' : null,
                    onAction:
                        _conversations.isEmpty ? _showNewChatDialog : null,
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: filteredConversations.length,
                    separatorBuilder: (context, index) => Divider(
                      color: Colors.white.withValues(alpha: 0.08),
                      height: 1,
                      indent: 62,
                    ),
                    itemBuilder: (context, index) {
                      final item = filteredConversations[index];
                      final isUnread = (item['unread'] ?? 0) > 0;

                      return GestureDetector(
                        onTap: () => _openChat(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            children: [
                              UserAvatar(
                                url: item['avatar'] as String?,
                                fallbackName: item['name'] as String?,
                                radius: 24,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: GoogleFonts.hankenGrotesk(
                                            color: Colors.white,
                                            fontWeight:
                                                isUnread ? FontWeight.bold : FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          item['time'],
                                          style: GoogleFonts.hankenGrotesk(
                                            color: isUnread ? _accent : Colors.white38,
                                            fontSize: 11,
                                            fontWeight:
                                                isUnread ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['lastMessage'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.hankenGrotesk(
                                              color: isUnread ? Colors.white : Colors.white54,
                                              fontWeight: isUnread
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (isUnread) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _accent,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${item['unread']}',
                                              style: GoogleFonts.hankenGrotesk(
                                                color: Colors.white,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _accent.withValues(alpha: 0.15) : _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _accent : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
