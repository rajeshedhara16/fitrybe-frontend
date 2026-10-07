import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

/// Reporting a post: pick a reason, optionally add detail, send.
///
/// The report is stored on the server and the post is hidden for the reporter
/// straight away, since nobody who reported something wants to keep seeing it.
class ReportPostSheet extends StatefulWidget {
  const ReportPostSheet._({required this.postId});

  final String postId;

  static const List<(String, String, String)> reasons = [
    ('SPAM', 'Spam or scam', 'Advertising, fake giveaways, repeated junk'),
    ('HARASSMENT', 'Harassment or hate', 'Targeting, bullying or abusing someone'),
    ('INAPPROPRIATE', 'Inappropriate content', 'Nudity, violence or graphic images'),
    ('MISINFORMATION', 'False or dangerous', 'Misleading health or safety claims'),
    ('OTHER', 'Something else', 'Tell us what is wrong below'),
  ];

  /// Returns true once the report has been filed.
  static Future<bool> show(BuildContext context, {required String postId}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1B1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReportPostSheet._(postId: postId),
    );
    return result == true;
  }

  @override
  State<ReportPostSheet> createState() => _ReportPostSheetState();
}

class _ReportPostSheetState extends State<ReportPostSheet> {
  static const Color _accent = Color(0xFFFF5722);

  final _details = TextEditingController();
  String? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final details = _details.text.trim();
      await ApiService.reportPost(
        widget.postId,
        reason: reason,
        details: details.isEmpty ? null : details,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e is ApiException
            ? e.message
            : 'Could not send the report. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                'Report post',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reports are private. The post is hidden for you as soon as you send it.',
                style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              for (final (code, title, subtitle) in ReportPostSheet.reasons)
                _reasonTile(code, title, subtitle),
              const SizedBox(height: 8),
              TextField(
                controller: _details,
                maxLength: 500,
                maxLines: 3,
                minLines: 2,
                style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: _reason == 'OTHER'
                      ? 'What is wrong with this post?'
                      : 'Add details (optional)',
                  hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white30, fontSize: 13),
                  counterStyle: GoogleFonts.hankenGrotesk(color: Colors.white24, fontSize: 10),
                  filled: true,
                  fillColor: const Color(0xFF26262A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: GoogleFonts.hankenGrotesk(color: Colors.redAccent, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _reason == null || _sending ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    disabledBackgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : Text(
                          'Send report',
                          style: GoogleFonts.hankenGrotesk(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            height: 1.15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reasonTile(String code, String title, String subtitle) {
    final selected = _reason == code;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _reason = code);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _accent.withValues(alpha: 0.10) : const Color(0xFF26262A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? _accent : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? _accent : Colors.white30,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
