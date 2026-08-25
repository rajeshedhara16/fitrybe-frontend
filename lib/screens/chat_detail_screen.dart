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
    socket.emit('join_conversation', widget.chatId);
    socket.on('chat:message', _onIncomingMessage);
  }

  void _onIncomingMessage(dynamic data) {
    if (data is! Map) return;
    final payload = Map<String, dynamic>.from(data);
    if ('${payload['conversationId']}' != widget.chatId) return;
    // Our own sends are appended optimistically already.
    if ('${payload['senderId']}' == SessionService().userId) return;
    if (!mounted) return;
    setState(() => _messages.add(_normalize(payload)));
    _scrollToBottom();
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

    return {
      'id': '${raw['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      'isMe': senderId == SessionService().userId,
      'senderName': name.isEmpty ? widget.name : name,
      'text': '${raw['text'] ?? ''}',
      'type': mediaUrl != null ? 'image' : 'text',
      'mediaPath': mediaUrl,
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
      ..emit('leave_conversation', widget.chatId);
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

  Future<void> _sendMessage({String text = ''}) async {
    final msgText = text.trim();
    if (msgText.isEmpty || _isSending) return;

    HapticFeedback.lightImpact();
    setState(() => _isSending = true);
    _textController.clear();

    final created = await ApiService.sendMessage(widget.chatId, msgText);
    if (!mounted) return;

    if (created == null) {
      // Put the text back so the message is not silently lost.
      _textController.text = msgText;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _cardBg,
          content: Text(
            'Message could not be sent. Check your connection.',
            style: GoogleFonts.hankenGrotesk(color: Colors.white70),
          ),
        ),
      );
      return;
    }

    setState(() {
      _messages.add(_normalize(created));
      _isSending = false;
    });
    // Fan the message out to everyone else in the room.
    SocketService().emit('chat:send', {
      'conversationId': widget.chatId,
      'text': msgText,
    });
    _scrollToBottom();
  }

  Future<void> _attachImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (image == null || _isSending) return;

      setState(() => _isSending = true);
      // Upload first, then send a message that references the stored file.
      final url = await ApiService.uploadChatImage(File(image.path));
      if (url == null) {
        if (mounted) setState(() => _isSending = false);
        return;
      }
      final created = await ApiService.sendMessage(
        widget.chatId,
        _textController.text.trim(),
        mediaUrl: url,
      );
      if (!mounted) return;
      setState(() {
        if (created != null) _messages.add(_normalize(created));
        _isSending = false;
      });
      _textController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error attaching image: $e');
      if (mounted) setState(() => _isSending = false);
    }
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
              child: Row(
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
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.white54,
                      size: 24,
                    ),
                    onPressed: () => _sendMessage(text: _textController.text),
                  ),
                ],
              ),
            ),
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

            // Text message
            if (type == 'text' && msg['text'] != null && msg['text'].isNotEmpty)
              Text(
                msg['text'],
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),

            // Image message
            if (type == 'image' && msg['mediaPath'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(msg['mediaPath']),
                  fit: BoxFit.cover,
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
