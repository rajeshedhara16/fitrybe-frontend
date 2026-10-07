import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../widgets/state_views.dart';
import '../widgets/user_avatar.dart';

/// Everyone the athlete has blocked, with a way to unblock each.
class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  static const Color _bg = Color(0xFF131316);
  static const Color _cardBg = Color(0xFF1F1F22);

  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final users = await ApiService.getBlockedUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'We could not load your blocked accounts.';
      });
    }
  }

  Future<void> _unblock(Map<String, dynamic> user) async {
    final id = '${user['id']}';
    if (_busy.contains(id)) return;
    HapticFeedback.lightImpact();
    setState(() => _busy.add(id));
    final name = _nameOf(user);
    try {
      await ApiService.setBlocked(id, false);
      if (!mounted) return;
      setState(() {
        _users.remove(user);
        _busy.remove(id);
      });
      _snack('$name is unblocked.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(id));
      _snack(e is ApiException ? e.message : 'Could not unblock $name. Try again.');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _cardBg,
      content: Text(message, style: GoogleFonts.hankenGrotesk(color: Colors.white70)),
    ));
  }

  static String _nameOf(Map<String, dynamic> user) {
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    return name.isEmpty ? 'Fitrybe Athlete' : name;
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_loading) {
      body = const LoadingStateView();
    } else if (_error != null) {
      body = ErrorStateView(message: _error!, onRetry: _load);
    } else if (_users.isEmpty) {
      body = EmptyStateView(
        icon: Icons.block_rounded,
        title: 'Nobody blocked',
        message: 'Block someone from their profile or from the menu on one of their posts.',
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: _users.length,
        separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
        itemBuilder: (_, index) {
          final user = _users[index];
          final name = _nameOf(user);
          final busy = _busy.contains('${user['id']}');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                UserAvatar(
                  url: ApiService.media(user['avatarUrl'] as String?),
                  fallbackName: name,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => _unblock(user),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Unblock', style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Blocked accounts',
          style: GoogleFonts.anybody(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(child: body),
    );
  }
}
