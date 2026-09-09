import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/state_views.dart';
import 'user_profile_screen.dart';

/// Full-screen X/Twitter style detail view for a post, featuring the post body,
/// full activity metrics, photo gallery, time stamp, like/share actions, and the
/// comments thread with a sticky bottom reply bar.
class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  static Future<void> navigate(BuildContext context, Map<String, dynamic> post) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(post: post),
      ),
    );
  }

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final Color _accent = const Color(0xFFFF5722);
  final Color _cardBg = const Color(0xFF1C1C1E);
  final Color _bg = const Color(0xFF131316);

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late Map<String, dynamic> _post;
  /// The comment being replied to, or null when writing a new top-level one.
  Map<String, dynamic>? _replyingTo;

  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;
  bool _isSubmittingComment = false;

  late bool _isLiked;
  late int _kudosCount;
  late int _commentCount;

  /// Set the moment the reader touches the heart, so a refresh that lands
  /// afterwards cannot overwrite what they just did with an older count.
  bool _likeTouched = false;

  @override
  void initState() {
    super.initState();
    _post = Map<String, dynamic>.from(widget.post);
    _isLiked = _post['likedByMe'] == true;
    _kudosCount = (_post['likeCount'] as num?)?.toInt() ?? 0;
    _commentCount = (_post['commentCount'] as num?)?.toInt() ?? 0;
    _refreshPost();
    _loadComments();
  }

  /// Re-reads the post so the heart and the count are the server's, not
  /// whatever the card that opened this screen happened to be holding.
  Future<void> _refreshPost() async {
    final postId = '${_post['id'] ?? ''}';
    if (postId.isEmpty) return;

    final fresh = await ApiService.getPost(postId);
    if (fresh == null || !mounted) return;

    setState(() {
      _post = fresh;
      if (_likeTouched) return;
      _isLiked = fresh['likedByMe'] == true;
      _kudosCount = (fresh['likeCount'] as num?)?.toInt() ?? _kudosCount;
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final postId = '${_post['id'] ?? ''}';
    if (postId.isEmpty) {
      if (mounted) setState(() => _isLoadingComments = false);
      return;
    }

    try {
      final fetched = await ApiService.getComments(postId);
      if (!mounted) return;
      setState(() {
        _comments = fetched;
        _commentCount = _countAll(fetched);
        _isLoadingComments = false;
      });
    } catch (e) {
      debugPrint('PostDetailScreen _loadComments error: $e');
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _toggleLike() async {
    final postId = '${_post['id'] ?? ''}';
    if (postId.isEmpty) return;

    HapticFeedback.lightImpact();
    final newStatus = !_isLiked;
    setState(() {
      _likeTouched = true;
      _isLiked = newStatus;
      _kudosCount = newStatus ? _kudosCount + 1 : (_kudosCount - 1).clamp(0, 999999);
    });

    final ok = await ApiService.setLiked(postId, newStatus);
    if (!ok && mounted) {
      // Revert if server failed
      setState(() {
        _isLiked = !newStatus;
        _kudosCount = !newStatus ? _kudosCount + 1 : (_kudosCount - 1).clamp(0, 999999);
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    final postId = '${_post['id'] ?? ''}';
    if (text.isEmpty || postId.isEmpty || _isSubmittingComment) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSubmittingComment = true);

    try {
      final parentId = _replyingTo?['id'] as String?;
      final newComment =
          await ApiService.addComment(postId, text, parentId: parentId);
      _commentController.clear();
      _commentFocusNode.unfocus();

      if (newComment != null && mounted) {
        setState(() {
          if (parentId == null) {
            _comments.insert(0, newComment);
          } else {
            // The server attaches a reply to the top-level comment, so put it
            // under whichever thread actually owns it rather than the tapped
            // comment, which may itself be a reply.
            final owner = '${newComment['parentId'] ?? parentId}';
            final index = _comments.indexWhere((c) => '${c['id']}' == owner);
            if (index == -1) {
              _comments.insert(0, newComment);
            } else {
              final thread = Map<String, dynamic>.from(_comments[index]);
              thread['replies'] = [
                ...(thread['replies'] as List? ?? const []),
                newComment,
              ];
              _comments[index] = thread;
            }
          }
          _replyingTo = null;
          _commentCount = _countAll(_comments);
          _isSubmittingComment = false;
        });
      } else {
        if (mounted) {
          setState(() => _isSubmittingComment = false);
          _loadComments();
        }
      }
    } catch (e) {
      debugPrint('PostDetailScreen _submitComment error: $e');
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  static String _formatPace(dynamic rawPace) {
    if (rawPace == null) return '0:00';
    final str = rawPace.toString().trim();
    if (str.isEmpty) return '0:00';
    if (str.contains(':')) return str;
    final numVal = double.tryParse(str);
    if (numVal == null || numVal <= 0 || numVal.isInfinite || numVal.isNaN) return '0:00';
    final mins = numVal.floor();
    final secs = ((numVal - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  static double _parseDistKm(dynamic distVal) {
    final num? val = (distVal as num?);
    if (val == null) return 0.0;
    final d = val.toDouble();
    return d > 100 ? d / 1000.0 : d;
  }

  static String _formatTimestamp(dynamic rawDate) {
    final date = DateTime.tryParse('${rawDate ?? ''}')?.toLocal();
    if (date == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm · ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String _relativeTime(dynamic rawDate) {
    final parsed = DateTime.tryParse('${rawDate ?? ''}')?.toLocal();
    if (parsed == null) return 'Just now';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> author =
        (_post['author'] is Map) ? Map<String, dynamic>.from(_post['author']) : {};
    final String authorId =
        author['id'] as String? ?? _post['authorId'] as String? ?? '';
    final String authorName =
        '${author['firstName'] ?? 'Fitrybe'} ${author['lastName'] ?? 'User'}'.trim();
    final String? avatarUrl = ApiService.media(author['avatarUrl'] as String?);
    final String caption = '${_post['caption'] ?? ''}';
    final String postType = '${_post['type'] ?? 'Update'}';
    final String locationTag = '${_post['locationTag'] ?? 'Fitrybe Feed'}';
    final List imageUrls = (_post['imageUrls'] is List) ? _post['imageUrls'] : [];
    final Map<String, dynamic>? activity =
        (_post['activity'] is Map) ? Map<String, dynamic>.from(_post['activity']) : null;
    final bool isOwnPost = authorId == SessionService().userId;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Post',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (isOwnPost)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  HapticFeedback.mediumImpact();
                  final ok = await ApiService.deletePost('${_post['id']}');
                  if (ok && context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              color: const Color(0xFF1E1E22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: _accent, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Delete Post',
                        style: GoogleFonts.hankenGrotesk(color: _accent, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Main Content (Post detail + Comments list)
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),

                          // Author Header Row
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => UserProfileScreen.navigate(context, authorId),
                                child: UserAvatar(
                                  url: avatarUrl,
                                  fallbackName: authorName,
                                  radius: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => UserProfileScreen.navigate(context, authorId),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        authorName.isEmpty ? 'Fitrybe Athlete' : authorName,
                                        style: GoogleFonts.hankenGrotesk(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        locationTag,
                                        style: GoogleFonts.hankenGrotesk(
                                          color: Colors.white54,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  postType,
                                  style: GoogleFonts.hankenGrotesk(
                                    color: _accent,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Post Caption
                          if (caption.isNotEmpty)
                            Text(
                              caption,
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1.45,
                              ),
                            ),

                          // Activity Metrics Box (If present)
                          if (activity != null &&
                              (activity['distance'] != null || activity['avgPace'] != null)) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.directions_run_rounded, color: _accent, size: 26),
                                  const SizedBox(width: 14),
                                  if (activity['distance'] != null) ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${activity['title'] ?? activity['type'] ?? 'WORKOUT'}'.toUpperCase(),
                                          style: GoogleFonts.hankenGrotesk(
                                            fontSize: 10,
                                            color: _accent,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          'DISTANCE',
                                          style: GoogleFonts.hankenGrotesk(
                                            fontSize: 8.5,
                                            color: Colors.white54,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Text(
                                          '${_parseDistKm(activity['distance']).toStringAsFixed(1)} km',
                                          style: GoogleFonts.anybody(
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 24),
                                  ],
                                  if (activity['avgPace'] != null) ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'PACE',
                                          style: GoogleFonts.hankenGrotesk(
                                            fontSize: 9,
                                            color: Colors.white54,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Text(
                                          '${_formatPace(activity['avgPace'])} /km',
                                          style: GoogleFonts.anybody(
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],

                          // Post Images / Media Grid
                          if (imageUrls.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                children: imageUrls.map((img) {
                                  final String fullUrl = ApiService.media('$img') ?? '';
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Image.network(
                                      fullUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (_, _, _) => Container(
                                        height: 200,
                                        color: _cardBg,
                                        child: const Center(
                                          child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 40),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Date & Timestamp (Twitter / X format)
                          Text(
                            _formatTimestamp(_post['createdAt']),
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Action Row (Like & Comment next to counts, Share on far right)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: _toggleLike,
                                    child: Row(
                                      children: [
                                        Icon(
                                          _isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                                          color: _isLiked ? _accent : Colors.white60,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$_kudosCount',
                                          style: GoogleFonts.hankenGrotesk(
                                            color: _isLiked ? _accent : Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  GestureDetector(
                                    onTap: () {
                                      FocusScope.of(context).requestFocus(_commentFocusNode);
                                    },
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: Colors.white60,
                                          size: 19,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$_commentCount',
                                          style: GoogleFonts.hankenGrotesk(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.share_outlined,
                                  color: Colors.white60,
                                  size: 20,
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  SharePlus.instance.share(ShareParams(
                                    text: "Check out $authorName's post on FiTrybe! 💪\n\n$caption",
                                  ));
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    // Full-width Divider Line below post action row
                    Container(height: 1, width: double.infinity, color: Colors.white.withValues(alpha: 0.08)),

                    // Replies Thread Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        'Replies',
                        style: GoogleFonts.anybody(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Comments List
                    if (_isLoadingComments)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: LoadingStateView(message: 'Loading replies...'),
                      )
                    else if (_comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded,
                                  color: Colors.white24, size: 40),
                              const SizedBox(height: 10),
                              Text(
                                'No replies yet',
                                style: GoogleFonts.hankenGrotesk(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Be the first to join the conversation.',
                                style: GoogleFonts.hankenGrotesk(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._comments.map(_buildCommentThread),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // Pinned Bottom Reply Bar (Twitter / X style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF19191C),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingTo != null) _buildReplyingBanner(),
                  Row(
                children: [
                  UserAvatar(
                    url: SessionService().avatarUrl,
                    fallbackName: SessionService().displayName,
                    radius: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitComment(),
                        decoration: InputDecoration(
                          hintText: _replyingTo == null
                            ? 'Post your reply...'
                            : 'Reply to ${_replyTargetName()}...',
                          hintStyle: GoogleFonts.hankenGrotesk(
                            color: Colors.white38,
                            fontSize: 13.5,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _submitComment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: _isSubmittingComment
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Reply',
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Who the pending reply is addressed to.
  String _replyTargetName() {
    final author = _replyingTo?['author'];
    if (author is Map) {
      final name =
          '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}'.trim();
      if (name.isNotEmpty) return name;
    }
    return 'this comment';
  }

  /// Sits above the composer while a reply is pending, so it is never a
  /// surprise which comment the text will land under.
  Widget _buildReplyingBanner() {
    final preview = '${_replyingTo?['text'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: _accent, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyTargetName()}',
                  style: GoogleFonts.hankenGrotesk(
                    color: _accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white54,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Colors.white38, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  /// Comments plus their replies — what the post's count should show.
  static int _countAll(List<Map<String, dynamic>> comments) {
    var total = 0;
    for (final c in comments) {
      total += 1 + ((c['replies'] as List?)?.length ?? 0);
    }
    return total;
  }

  /// Likes or unlikes a comment, updating the tile immediately and rolling
  /// back if the server refuses.
  Future<void> _toggleCommentLike(
    Map<String, dynamic> comment,
    String? parentId,
  ) async {
    final postId = '${_post['id'] ?? ''}';
    final commentId = '${comment['id'] ?? ''}';
    if (postId.isEmpty || commentId.isEmpty) return;

    final wasLiked = comment['likedByMe'] == true;
    final wasCount = (comment['likeCount'] as num?)?.toInt() ?? 0;
    HapticFeedback.lightImpact();

    setState(() => _applyCommentLike(
        commentId, parentId, !wasLiked, wasLiked ? wasCount - 1 : wasCount + 1));

    final serverCount =
        await ApiService.setCommentLiked(postId, commentId, !wasLiked);
    if (!mounted) return;

    setState(() => _applyCommentLike(
          commentId,
          parentId,
          serverCount == null ? wasLiked : !wasLiked,
          serverCount ?? wasCount,
        ));
  }

  /// Writes a like state onto the comment in place, whether it is a top-level
  /// comment or a reply inside one.
  void _applyCommentLike(
    String commentId,
    String? parentId,
    bool liked,
    int likeCount,
  ) {
    void write(Map<String, dynamic> target) {
      target['likedByMe'] = liked;
      target['likeCount'] = likeCount < 0 ? 0 : likeCount;
    }

    for (var i = 0; i < _comments.length; i++) {
      final thread = _comments[i];
      if ('${thread['id']}' == commentId) {
        final updated = Map<String, dynamic>.from(thread);
        write(updated);
        _comments[i] = updated;
        return;
      }
      final replies = thread['replies'] as List?;
      if (replies == null) continue;
      for (var j = 0; j < replies.length; j++) {
        if ('${(replies[j] as Map)['id']}' != commentId) continue;
        final updated = Map<String, dynamic>.from(replies[j] as Map);
        write(updated);
        final newReplies = List<dynamic>.from(replies)..[j] = updated;
        final thr = Map<String, dynamic>.from(thread);
        thr['replies'] = newReplies;
        _comments[i] = thr;
        return;
      }
    }
  }

  void _startReply(Map<String, dynamic> comment) {
    HapticFeedback.selectionClick();
    setState(() => _replyingTo = comment);
    _commentFocusNode.requestFocus();
  }

  /// A top-level comment and the replies hanging off it.
  Widget _buildCommentThread(Map<String, dynamic> comment) {
    final replies = (comment['replies'] as List? ?? const [])
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentTile(comment, showBorder: false),
          // Replies are indented under their parent without lines between them.
          for (final reply in replies)
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: _buildCommentTile(
                reply,
                parentId: '${comment['id']}',
                isReply: true,
                showBorder: false,
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildCommentTile(
    Map<String, dynamic> comment, {
    String? parentId,
    bool isReply = false,
    bool showBorder = false,
  }) {
    final Map? authorMap = comment['author'] is Map ? comment['author'] as Map : null;
    final String? commenterId =
        (comment['authorId'] ?? authorMap?['id'] ?? comment['userId'])?.toString();
    final String commenterName = authorMap != null
        ? '${authorMap['firstName'] ?? ''} ${authorMap['lastName'] ?? ''}'.trim()
        : '${comment['author'] ?? 'Athlete'}';
    final String? commenterAvatar = authorMap != null
        ? ApiService.media(authorMap['avatarUrl'] as String?)
        : ApiService.media(comment['avatar'] as String?);
    final String commentText = '${comment['text'] ?? ''}';
    final String commentTime = _relativeTime(comment['createdAt'] ?? comment['time']);
    final bool isLiked = comment['likedByMe'] == true;
    final int likeCount = (comment['likeCount'] as num?)?.toInt() ?? 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isReply ? 12 : 16,
        vertical: isReply ? 8 : 12,
      ),
      decoration: showBorder
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => UserProfileScreen.navigate(context, commenterId),
            child: UserAvatar(
              url: commenterAvatar,
              fallbackName: commenterName,
              radius: isReply ? 13 : 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => UserProfileScreen.navigate(context, commenterId),
                      child: Text(
                        commenterName.isEmpty ? 'Athlete' : commenterName,
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '· $commentTime',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  commentText,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white70,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _startReply(comment),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'Reply',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Like sits on the right of the comment, with its count beneath.
          GestureDetector(
            onTap: () => _toggleCommentLike(comment, parentId),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    color: isLiked ? _accent : Colors.white38,
                    size: 16,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    likeCount == 0 ? '' : '$likeCount',
                    style: GoogleFonts.hankenGrotesk(
                      color: isLiked ? _accent : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
