import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import 'user_avatar.dart';

/// Inviting people to a Trybe that already exists: search, tap Invite.
///
/// Each row reports what actually happened, since the server declines to send
/// a second invite to someone already invited, and there is no point inviting
/// someone who is already a member.
class TrybeInviteSheet extends StatefulWidget {
  const TrybeInviteSheet._({required this.trybeId, required this.trybeName});

  final String trybeId;
  final String trybeName;

  static Future<void> show(
    BuildContext context, {
    required String trybeId,
    required String trybeName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1B1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: TrybeInviteSheet._(trybeId: trybeId, trybeName: trybeName),
      ),
    );
  }

  @override
  State<TrybeInviteSheet> createState() => _TrybeInviteSheetState();
}

class _TrybeInviteSheetState extends State<TrybeInviteSheet> {
  static const Color _accent = Color(0xFFFF5722);

  final _query = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _people = const [];
  bool _loading = true;

  /// userId to 'sending', 'invited', 'alreadyInvited', 'alreadyMember' or
  /// 'failed'.
  final Map<String, String> _status = {};

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String text) async {
    setState(() => _loading = true);
    final people = await ApiService.getTrybeInviteCandidates(
      widget.trybeId,
      search: text.trim(),
    );
    if (!mounted || text != _query.text) return;
    setState(() {
      _people = people;
      // Members never come back from the server. Anyone already invited shows
      // as Invited, unless this sheet has just changed their state itself.
      for (final person in people) {
        if (person['invited'] == true) {
          _status.putIfAbsent('${person['id']}', () => 'alreadyInvited');
        }
      }
      _loading = false;
    });
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  Future<void> _invite(String userId) async {
    HapticFeedback.lightImpact();
    setState(() => _status[userId] = 'sending');
    try {
      final result = await ApiService.sendTrybeInvite(widget.trybeId, userId);
      if (mounted) setState(() => _status[userId] = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status[userId] = 'failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF26262A),
          content: Text(
            e is ApiException ? e.message : 'Could not send that invite. Try again.',
            style: GoogleFonts.hankenGrotesk(color: Colors.white70),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite to ${widget.trybeName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'They get a notification with a Join button.',
                  style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _query,
                  onChanged: _onChanged,
                  style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                    hintText: 'Search athletes by name',
                    hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white30, fontSize: 13.5),
                    filled: true,
                    fillColor: const Color(0xFF26262A),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
                  )
                : _people.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _query.text.trim().isEmpty
                                ? 'Everyone you could invite is already in this Trybe.'
                                : 'Nobody matches "${_query.text.trim()}".',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: _people.length,
                        itemBuilder: (context, index) => _row(_people[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> person) {
    final id = '${person['id'] ?? ''}';
    final name = '${person['firstName'] ?? ''} ${person['lastName'] ?? ''}'.trim();
    final status = _status[id];

    final (String label, bool enabled, bool filled) = switch (status) {
      'sending' => ('', false, true),
      'invited' => ('Invited', false, false),
      'alreadyInvited' => ('Invited', false, false),
      'alreadyMember' => ('Member', false, false),
      'failed' => ('Retry', true, true),
      _ => ('Invite', true, true),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          UserAvatar(
            url: ApiService.media(person['avatarUrl'] as String?),
            fallbackName: name.isEmpty ? 'Athlete' : name,
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Fitrybe Athlete' : name,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if ('${person['location'] ?? ''}'.trim().isNotEmpty)
                  Text(
                    '${person['location']}',
                    style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 11.5),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: enabled && id.isNotEmpty ? () => _invite(id) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: filled ? _accent : Colors.white10,
                disabledBackgroundColor: filled ? _accent.withValues(alpha: 0.5) : Colors.white10,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
              ),
              child: status == 'sending'
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.hankenGrotesk(
                        color: filled ? Colors.white : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
