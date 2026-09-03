import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/socket_service.dart';
import '../widgets/state_views.dart';
import '../widgets/user_avatar.dart';

class ChatDetailScreen extends StatefulWidget {
  /// Server conversation id.
  final String chatId;
  final String name;
  final String? avatar;
  final bool isTrybe;
  final bool isOnline;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.name,
    this.avatar,
    this.isTrybe = false,
    this.isOnline = false,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final Color _accent = const Color(0xFFFF5722);
  final Color _bg = const Color(0xFF131316);
  final Color _cardBg = const Color(0xFF1E1E22);

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _error;
  bool _isSending = false;

  /// Picked but not yet sent. The image is uploaded when Send is pressed, so
  /// it can still be removed, captioned, or replied-with first.
  XFile? _pendingAttachment;

  /// The message being replied to, shown above the composer until sent.
  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _joinRealtimeRoom();
  }

  /// Subscribes to this conversation so messages from other participants
  /// arrive without polling.
  void _joinRealtimeRoom() {
    final socket = SocketService();
    socket.connect();
    // joinRoom (rather than a bare emit) so the room is re-entered after a
    // reconnect or a token refresh rebuilds the socket.
    socket.joinRoom('join_conversation', widget.chatId);
    socket.on('chat:message', _onIncomingMessage);
    socket.on('chat:message_deleted', _onMessageDeleted);
  }

  void _onIncomingMessage(dynamic data) {
    if (data is! Map || !mounted) return;
    // The server broadcasts the stored record: { message: { ... } }.
    final raw = data['message'];
    if (raw is! Map) return;
    final payload = Map<String, dynamic>.from(raw);

    final id = '${payload['id'] ?? ''}';
    // Our own sends are appended optimistically already, and a reconnect can
    // replay a message we are holding — match on id so neither duplicates.
    if (id.isNotEmpty && _messages.any((m) => m['id'] == id)) return;
    if ('${payload['senderId']}' == SessionService().userId) return;

    setState(() => _messages.add(_normalize(payload)));
    _scrollToBottom();
  }

  void _onMessageDeleted(dynamic data) {
    if (data is! Map || !mounted) return;
    if ('${data['conversationId']}' != widget.chatId) return;
    final id = '${data['messageId'] ?? ''}';
    if (id.isEmpty) return;
    setState(() => _messages.removeWhere((m) => m['id'] == id));
  }

  Future<void> _loadMessages() async {
    if (mounted) setState(() => _error = null);
    try {
      final fetched = await ApiService.getMessages(widget.chatId);
      if (!mounted) return;
      setState(() {
        _messages = fetched.map(_normalize).toList();
        _isLoading = false;
      });
      _scrollToBottom();
      // Clear the unread badge for this thread.
      ApiService.markConversationRead(widget.chatId);
    } catch (e) {
      debugPrint('ChatDetail load error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'We could not load this conversation.';
      });
    }
  }

  /// Maps an API message onto the shape the bubble widgets expect.
  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    final sender = (raw['sender'] is Map)
        ? Map<String, dynamic>.from(raw['sender'])
        : const <String, dynamic>{};
    final senderId = '${raw['senderId'] ?? sender['id'] ?? ''}';
    final name =
        '${sender['firstName'] ?? ''} ${sender['lastName'] ?? ''}'.trim();
    final mediaUrl = ApiService.media(raw['mediaUrl'] as String?);

    // The quoted message, flattened to what a bubble needs to preview it.
    Map<String, dynamic>? replyTo;
    if (raw['replyTo'] is Map) {
      final r = Map<String, dynamic>.from(raw['replyTo']);
      final rSender = (r['sender'] is Map)
          ? Map<String, dynamic>.from(r['sender'])
          : const <String, dynamic>{};
      final rName =
          '${rSender['firstName'] ?? ''} ${rSender['lastName'] ?? ''}'.trim();
      replyTo = {
        'id': '${r['id'] ?? ''}',
        'senderName': '${r['senderId']}' == SessionService().userId
            ? 'You'
            : (rName.isEmpty ? widget.name : rName),
        'text': '${r['text'] ?? ''}',
        'hasMedia': r['mediaUrl'] != null,
      };
    }

    return {
      'id': '${raw['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      'senderId': senderId,
      'isMe': senderId == SessionService().userId,
      'senderName': name.isEmpty ? widget.name : name,
      'text': '${raw['text'] ?? ''}',
      'type': mediaUrl != null ? 'image' : 'text',
      // Absolute URL served by the backend, not a local file path.
      'mediaUrl': mediaUrl,
      'replyTo': replyTo,
      'time': _formatTime(raw['createdAt']),
    };
  }

  static String _formatTime(dynamic isoString) {
    final parsed = DateTime.tryParse('${isoString ?? ''}')?.toLocal();
    if (parsed == null) return '';
    final hour12 = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour12:$minute ${parsed.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  void dispose() {
    SocketService()
      ..off('chat:message')
      ..off('chat:message_deleted')
      ..leaveRoom('join_conversation', 'leave_conversation', widget.chatId);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Sends whatever is composed: text, a staged attachment, a reply, or any
  /// combination. The attachment uploads here rather than at pick time, so
  /// nothing is stored for a message the user abandons.
  Future<void> _sendMessage({String text = ''}) async {
    final msgText = text.trim();
    final attachment = _pendingAttachment;
    if ((msgText.isEmpty && attachment == null) || _isSending) return;

    HapticFeedback.lightImpact();
    setState(() => _isSending = true);
    final replyToId = _replyingTo?['id'] as String?;
    _textController.clear();

    try {
      String? mediaUrl;
      if (attachment != null) {
        mediaUrl = await ApiService.uploadChatImage(File(attachment.path));
        if (mediaUrl == null) {
          throw ApiException(0, 'That image could not be uploaded.');
        }
      }

      final created = await ApiService.sendMessage(
        widget.chatId,
        msgText,
        mediaUrl: mediaUrl,
        replyToId: replyToId,
      );
      if (!mounted) return;
      if (created == null) throw ApiException(0, 'Message could not be sent.');

      setState(() {
        _messages.add(_normalize(created));
        _pendingAttachment = null;
        _replyingTo = null;
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Send message error: $e');
      if (!mounted) return;
      // Put the text back so a failed send does not lose what was typed.
      _textController.text = msgText;
      setState(() => _isSending = false);
      _toast(
        e is ApiException && e.message.isNotEmpty
            ? e.message
            : 'Message could not be sent. Check your connection.',
      );
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _cardBg,
        content: Text(
          message,
          style: GoogleFonts.hankenGrotesk(color: Colors.white70),
        ),
      ),
    );
  }

  /// Stages an image on the composer. Nothing is uploaded until Send.
  Future<void> _attachImage() async {
    if (_isSending) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (image == null || !mounted) return;
      setState(() => _pendingAttachment = image);
    } catch (e) {
      debugPrint('Error picking image: $e');
      _toast('That image could not be opened.');
    }
  }

  /// Long-press actions on a message.
  void _showMessageActions(Map<String, dynamic> msg) {
    HapticFeedback.mediumImpact();
    final isMe = msg['isMe'] == true;
    final text = '${msg['text'] ?? ''}';

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Colors.white70),
              title: Text('Reply',
                  style: GoogleFonts.hankenGrotesk(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetCtx);
                setState(() => _replyingTo = msg);
              },
            ),
            if (text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Colors.white70),
                title: Text('Copy text',
                    style: GoogleFonts.hankenGrotesk(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Clipboard.setData(ClipboardData(text: text));
                  _toast('Copied to clipboard.');
                },
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent),
                title: Text('Delete',
                    style: GoogleFonts.hankenGrotesk(color: Colors.redAccent)),
                subtitle: Text('Removes it for everyone',
                    style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38, fontSize: 11.5)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _deleteMessage('${msg['id']}');
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    // Drop it immediately, and put it back if the server refuses.
    final index = _messages.indexWhere((m) => m['id'] == messageId);
    if (index == -1) return;
    final removed = _messages[index];
    setState(() => _messages.removeAt(index));

    final ok = await ApiService.deleteMessage(widget.chatId, messageId);
    if (!mounted || ok) return;
    setState(() => _messages.insert(index, removed));
    _toast('That message could not be deleted.');
  }

  @override
  Widget build(BuildContext context) {
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
        title: Row(
          children: [
            UserAvatar(
              url: widget.avatar,
              fallbackName: widget.name,
              radius: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (widget.isTrybe)
                    Text(
                      'Trybe Group Chat',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Message Feed
          Expanded(
            child: _isLoading
                ? const LoadingStateView()
                : _error != null
                    ? ErrorStateView(message: _error!, onRetry: _loadMessages)
                    : _messages.isEmpty
                        ? EmptyStateView(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'No messages yet',
                            message: widget.isTrybe
                                ? 'Start the conversation with your Trybe.'
                                : 'Say hello to ${widget.name}.',
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              return _buildMessageBubble(msg);
                            },
                          ),
          ),

          // Input Dock
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _bg,
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingTo != null) _buildReplyBanner(),
                  if (_pendingAttachment != null) _buildAttachmentPreview(),
                  Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14),
                      onSubmitted: (val) => _sendMessage(text: val),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white30, fontSize: 14),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        prefixIcon: IconButton(
                          icon: const Icon(
                            Symbols.add_photo_alternate_rounded,
                            color: Colors.white54,
                            size: 22,
                            fill: 1.0,
                            weight: 700,
                          ),
                          onPressed: _attachImage,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Colors.white38),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white54),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white54,
                            size: 24,
                          ),
                    onPressed: _isSending
                        ? null
                        : () => _sendMessage(text: _textController.text),
                  ),
                ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows which message the next send will reply to.
  Widget _buildReplyBanner() {
    final reply = _replyingTo!;
    final text = '${reply['text'] ?? ''}';
    final preview = text.isNotEmpty
        ? text
        : (reply['mediaUrl'] != null ? 'Photo' : 'Message');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _cardBg,
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
                  'Replying to ${reply['isMe'] == true ? 'yourself' : reply['senderName'] ?? widget.name}',
                  style: GoogleFonts.hankenGrotesk(
                    color: _accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hankenGrotesk(
                      color: Colors.white54, fontSize: 12.5),
                ),
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

  /// The staged image, removable until Send is pressed.
  Widget _buildAttachmentPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_pendingAttachment!.path),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => Container(
                width: 48,
                height: 48,
                color: Colors.black26,
                child: const Icon(Icons.broken_image_outlined,
                    color: Colors.white38, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Photo ready to send',
              style: GoogleFonts.hankenGrotesk(
                  color: Colors.white70, fontSize: 12.5),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Colors.white38, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _pendingAttachment = null),
          ),
        ],
      ),
    );
  }

  /// The quoted message shown inside a reply's bubble.
  Widget _buildQuotedMessage(Map<String, dynamic> reply, bool isMe) {
    final text = '${reply['text'] ?? ''}';
    final preview =
        text.isNotEmpty ? text : (reply['hasMedia'] == true ? 'Photo' : 'Message');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: isMe ? 0.18 : 0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white70 : _accent,
            width: 2.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${reply['senderName'] ?? ''}',
            style: GoogleFonts.hankenGrotesk(
              color: isMe ? Colors.white : _accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.hankenGrotesk(
                color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final bool isMe = msg['isMe'] == true;
    final String type = msg['type'] ?? 'text';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(msg),
        child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? _accent : _cardBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg['replyTo'] is Map)
              _buildQuotedMessage(
                Map<String, dynamic>.from(msg['replyTo']),
                isMe,
              ),

            if (!isMe && widget.isTrybe) ...[
              Text(
                msg['senderName'] ?? '',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
            ],

            // Attachment, when the message carries one.
            if (type == 'image' && msg['mediaUrl'] != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  msg['mediaUrl'],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) =>
                      progress == null
                          ? child
                          : const SizedBox(
                              height: 160,
                              child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white54),
                              ),
                            ),
                  errorBuilder: (context, _, _) => Container(
                    height: 120,
                    alignment: Alignment.center,
                    color: Colors.black26,
                    child: const Icon(Icons.broken_image_outlined,
                        color: Colors.white38),
                  ),
                ),
              ),
              if (msg['text'] != null && msg['text'].isNotEmpty)
                const SizedBox(height: 8),
            ],

            // Caption or plain text message.
            if (msg['text'] != null && msg['text'].isNotEmpty)
              Text(
                msg['text'],
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),

            // Workout card message
            if (type == 'workout') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe ? Colors.black.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.directions_run_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            msg['workoutTitle'] ?? 'Shared Workout',
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCol('DISTANCE', msg['distance'] ?? '10.0 km'),
                        _buildStatCol('PACE', msg['pace'] ?? '5:00 /km'),
                        _buildStatCol('TIME', msg['timeStr'] ?? '45m 00s'),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  msg['time'] ?? '',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all_rounded, color: Colors.white70, size: 12),
                ],
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildStatCol(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
        Text(
          val,
          style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
