import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/clique_live_activity_screen.dart';
import '../services/live_session.dart';
import '../services/units.dart';

/// The bar that says a workout is still running.
///
/// A session keeps going when its screen is closed, so without this there is
/// nothing on screen to say the GPS is still on or to get back to it.
class LiveSessionBanner extends StatefulWidget {
  const LiveSessionBanner({super.key, this.onOpenSolo});

  /// Switches to the recorder tab, which only the home shell can do.
  final VoidCallback? onOpenSolo;

  @override
  State<LiveSessionBanner> createState() => _LiveSessionBannerState();
}

class _LiveSessionBannerState extends State<LiveSessionBanner> {
  static const Color _accent = Color(0xFFFF5722);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LiveSessionState>(
      valueListenable: LiveSession().notifier,
      builder: (context, state, _) {
        // Nothing to say when no workout is running, or when the athlete is
        // already looking at it.
        if (!state.isActive || LiveSession().isViewOpen) {
          return const SizedBox.shrink();
        }

        final minutes = state.elapsed.inMinutes;
        final seconds = state.elapsed.inSeconds % 60;
        final clock =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _open(state),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              decoration: BoxDecoration(
                color: state.isPaused
                    ? const Color(0xFF26262A)
                    : _accent.withValues(alpha: 0.16),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: state.isPaused ? Colors.white54 : _accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.goalReached
                          ? '${state.title} · goal reached · tap to finish'
                          : state.isPaused
                              ? '${state.title} · paused at $clock'
                              : '${state.title} · $clock · ${Units.distanceKm(state.distanceKm, decimals: 2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Return',
                    style: GoogleFonts.hankenGrotesk(
                      color: _accent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: _accent, size: 20),
                  // A way out for a session that should not still be running,
                  // without hunting for the screen it belongs to.
                  GestureDetector(
                    onTap: _confirmStop,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6, right: 2, top: 4, bottom: 4),
                      child: Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Ends a session from the banner. Nothing is saved, so it asks first.
  Future<void> _confirmStop() async {
    HapticFeedback.mediumImpact();
    final stop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Stop this session?',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: Text(
          'The workout is discarded, not saved. To keep it, return to the session and press Finish instead.',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white70,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep going',
                style: GoogleFonts.hankenGrotesk(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Stop and discard',
              style: GoogleFonts.hankenGrotesk(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (stop == true) await LiveSession().discard();
  }

  void _open(LiveSessionState state) {
    HapticFeedback.lightImpact();
    if (state.mode == LiveMode.clique && state.sessionId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CliqueLiveActivityScreen(
            sessionId: state.sessionId,
            activityName: state.title,
            activityType: state.activityType,
          ),
        ),
      );
      return;
    }
    widget.onOpenSolo?.call();
  }
}
