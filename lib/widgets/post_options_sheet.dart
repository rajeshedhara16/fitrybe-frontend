import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import 'report_post_sheet.dart';

enum _PostChoice { hide, report, block }

/// The "..." menu on someone else's post: hide it, report it, or block its
/// author.
///
/// Both are stored on the server, so a hidden or reported post stays gone from
/// every feed on every device rather than reappearing on the next refresh.
class PostOptions {
  const PostOptions._();

  static const Color _cardBg = Color(0xFF1B1B1E);

  /// [onRemove] takes the post out of the caller's list and [onRestore] puts it
  /// back if the request fails or the athlete taps Undo. Both may run after the
  /// caller has gone, so they should check `mounted` before calling setState.
  ///
  /// With [authorId] and [onAuthorBlocked], the menu also offers to block the
  /// author, and [onAuthorBlocked] should drop every post of theirs on screen.
  static Future<void> open(
    BuildContext context, {
    required String postId,
    required String authorName,
    required VoidCallback onRemove,
    required VoidCallback onRestore,
    String? authorId,
    ValueChanged<String>? onAuthorBlocked,
  }) async {
    final canBlock = authorId != null && onAuthorBlocked != null;
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);

    final choice = await showModalBottomSheet<_PostChoice>(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              _tile(
                icon: Icons.visibility_off_outlined,
                color: Colors.white70,
                title: 'Hide this post',
                subtitle: 'Removes it from your feeds. $authorName is not told.',
                onTap: () => Navigator.pop(ctx, _PostChoice.hide),
              ),
              _tile(
                icon: Icons.flag_outlined,
                color: Colors.red.shade400,
                title: 'Report post',
                subtitle: 'Tell us it breaks the rules',
                onTap: () => Navigator.pop(ctx, _PostChoice.report),
              ),
              if (canBlock)
                _tile(
                  icon: Icons.block_rounded,
                  color: Colors.red.shade400,
                  title: 'Block $authorName',
                  subtitle: 'Neither of you sees the other or can get in touch',
                  onTap: () => Navigator.pop(ctx, _PostChoice.block),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case _PostChoice.hide:
        onRemove();
        try {
          await ApiService.setPostHidden(postId, true);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF26262A),
              content: Text(
                'Post hidden.',
                style: GoogleFonts.hankenGrotesk(color: Colors.white70),
              ),
              action: SnackBarAction(
                label: 'Undo',
                textColor: const Color(0xFFFF5722),
                onPressed: () async {
                  try {
                    await ApiService.setPostHidden(postId, false);
                    onRestore();
                  } catch (_) {
                    messenger.showSnackBar(_plain('Could not bring the post back. Try again.'));
                  }
                },
              ),
            ),
          );
        } catch (_) {
          onRestore();
          messenger.showSnackBar(_plain('Could not hide this post. Try again.'));
        }
      case _PostChoice.report:
        final reported = await ReportPostSheet.show(context, postId: postId);
        if (!reported) return;
        onRemove();
        messenger.showSnackBar(
          _plain('Thanks for reporting. The post is hidden for you and we will review it.'),
        );
      case _PostChoice.block:
        final sure = await confirmBlock(context, authorName);
        if (!sure) return;
        try {
          await ApiService.setBlocked(authorId!, true);
          onAuthorBlocked!(authorId);
          messenger.showSnackBar(_plain('$authorName is blocked.'));
        } catch (e) {
          messenger.showSnackBar(
            _plain(e is ApiException ? e.message : 'Could not block $authorName. Try again.'),
          );
        }
    }
  }

  /// Asks before blocking, and says plainly what a block does. Shared with the
  /// profile screen so both explain it the same way.
  static Future<bool> confirmBlock(BuildContext context, String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Block $name?',
          style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          'You will not see each other\'s profile, posts or comments, and neither of you can follow, '
          'message or notify the other. You will stop following each other. $name is not told. '
          'You can unblock them in Settings, Privacy & Sharing.',
          style: GoogleFonts.hankenGrotesk(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.hankenGrotesk(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Block',
              style: GoogleFonts.hankenGrotesk(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  static SnackBar _plain(String message) => SnackBar(
        backgroundColor: const Color(0xFF26262A),
        content: Text(message, style: GoogleFonts.hankenGrotesk(color: Colors.white70)),
      );

  static Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: GoogleFonts.hankenGrotesk(
          color: color == Colors.white70 ? Colors.white : color,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12),
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}
