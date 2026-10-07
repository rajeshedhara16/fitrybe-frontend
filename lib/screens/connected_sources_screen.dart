import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wearable_brands.dart';
import '../services/brand_logos.dart';
import '../services/health_import.dart';
import '../widgets/brand_mark.dart';

/// Watches and health apps connected to Fitrybe.
///
/// There is one connection per phone, to Apple Health or Health Connect, and
/// every watch brand reaches Fitrybe through it. That is why there is no list
/// of brands to pick from: Garmin, Fitbit, Whoop and the rest write into the
/// same store through their own apps.
class ConnectedSourcesScreen extends StatefulWidget {
  const ConnectedSourcesScreen({super.key});

  @override
  State<ConnectedSourcesScreen> createState() => _ConnectedSourcesScreenState();
}

class _ConnectedSourcesScreenState extends State<ConnectedSourcesScreen> {
  static const Color _bg = Color(0xFF131316);
  static const Color _cardBg = Color(0xFF1F1F22);
  static const Color _accent = Color(0xFFFF5722);

  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    HealthImport().load();
    // Logos are optional files; redraw once we know which ones shipped.
    BrandLogos.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// What this phone calls its health store.
  String get _storeName {
    if (kIsWeb) return 'your health app';
    if (Platform.isIOS) return 'Apple Health';
    if (Platform.isAndroid) return 'Health Connect';
    return 'your health app';
  }

  Future<void> _toggle(bool value) async {
    HapticFeedback.selectionClick();
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await HealthImport().setEnabled(value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result == null) {
        _message = value ? null : 'Importing is off. Nothing already imported was removed.';
        _messageIsError = false;
      } else {
        _messageIsError = result.failed;
        _message = result.failed ? result.error : _describe(result);
      }
    });
  }

  Future<void> _syncNow() async {
    HapticFeedback.lightImpact();
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await HealthImport().syncNow();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _messageIsError = result.failed;
      _message = result.failed ? result.error : _describe(result);
    });
  }

  String _describe(HealthImportResult result) {
    if (result.imported == 0 && result.duplicates == 0) {
      return 'No new workouts in $_storeName.';
    }
    final parts = <String>[];
    if (result.imported > 0) {
      parts.add('${result.imported} workout${result.imported == 1 ? '' : 's'} added');
    }
    if (result.duplicates > 0) {
      parts.add('${result.duplicates} already here');
    }
    return '${parts.join(', ')}.';
  }

  String _lastSyncLabel(DateTime? at) {
    if (at == null) return 'Not synced yet';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Synced just now';
    if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'Synced ${diff.inHours}h ago';
    return 'Synced ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Apps & Devices',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeader('WORKOUT SOURCE'),
              const SizedBox(height: 10),
              _sourceCard(),
              const SizedBox(height: 14),
              if (_message != null) _messageBox(),
              const SizedBox(height: 14),
              _sectionHeader('YOUR WATCH'),
              const SizedBox(height: 6),
              Text(
                'Fitrybe does not sign in to any watch brand. Each brand shares with '
                '$_storeName through its own app, and Fitrybe reads the workouts there. '
                'Tap a brand to see what to switch on.',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white38,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _brandList(),
              const SizedBox(height: 24),
              _sectionHeader('WHAT COMES IN'),
              const SizedBox(height: 10),
              _bullet(Icons.directions_run_rounded, 'Workouts, not steps',
                  'Each session arrives with its activity, time, distance and calories. Everyday step counts stay out of your history.'),
              _bullet(Icons.content_copy_rounded, 'No double counting',
                  'A run you recorded in Fitrybe is not added again when your watch writes the same session to $_storeName.'),
              _bullet(Icons.event_available_rounded, 'Filed on the day it happened',
                  'A Saturday session synced on Monday still counts for Saturday in your calendar, streak and Trybe goal.'),
              _bullet(Icons.emoji_events_rounded, 'Counts like any workout',
                  'Imported sessions go toward goals, badges and Trybe leaderboards.'),
              const SizedBox(height: 22),
              _note(
                'The first sync brings in the last 30 days. Fitrybe reads $_storeName only while the app is open, '
                'and you can take access away at any time in $_storeName itself.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder<bool>(
        valueListenable: HealthImport().enabledNotifier,
        builder: (context, enabled, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.favorite_rounded, color: _accent, size: 21),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _storeName,
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ValueListenableBuilder<DateTime?>(
                          valueListenable: HealthImport().lastSyncNotifier,
                          builder: (context, last, _) => Text(
                            enabled ? _lastSyncLabel(last) : 'Not connected',
                            style: GoogleFonts.hankenGrotesk(
                              color: enabled ? Colors.white54 : Colors.white38,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: _busy ? null : _toggle,
                    activeThumbColor: Colors.white,
                    activeTrackColor: _accent,
                    inactiveThumbColor: Colors.white70,
                    inactiveTrackColor: Colors.white12,
                  ),
                ],
              ),
              if (enabled) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _syncNow,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                      shape: const StadiumBorder(),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                          )
                        : Text(
                            'Sync now',
                            style: GoogleFonts.hankenGrotesk(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  /// Every brand worth listing on this phone, each saying how its workouts
  /// get here rather than offering a sign-in Fitrybe cannot honour.
  Widget _brandList() {
    final brands = brandsFor(isIOS: _isIOS);
    return ValueListenableBuilder<bool>(
      valueListenable: HealthImport().enabledNotifier,
      builder: (context, connected, _) => Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            for (var i = 0; i < brands.length; i++)
              _brandRow(brands[i], connected, last: i == brands.length - 1),
          ],
        ),
      ),
    );
  }

  Widget _brandRow(WearableBrand brand, bool connected, {required bool last}) {
    final link = brand.linkFor(isIOS: _isIOS);
    final status = brandStatus(
      brand,
      isIOS: _isIOS,
      storeConnected: connected,
      storeName: _storeName,
    );
    final statusColour = link == WearableLink.bridgeNeeded
        ? const Color(0xFFFFB74D)
        : connected
            ? Colors.white54
            : Colors.white38;

    return InkWell(
      onTap: () => _showBrandSheet(brand, connected),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
        ),
        child: Row(
          children: [
            BrandMark(brand: brand),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand.name,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    status,
                    style: GoogleFonts.hankenGrotesk(color: statusColour, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  /// The sheet behind a brand row.
  ///
  /// Syncing happens here and reports here: the result used to appear in the
  /// card at the top of the page, which is out of sight once the athlete has
  /// scrolled down to the brand they tapped.
  void _showBrandSheet(WearableBrand brand, bool connected) {
    HapticFeedback.selectionClick();

    var isConnected = connected;
    var busy = false;
    String? message;
    var isError = false;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B1B1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> run() async {
            if (busy) return;
            HapticFeedback.lightImpact();
            setSheetState(() {
              busy = true;
              message = null;
            });

            final result = isConnected
                ? await HealthImport().syncNow()
                : await HealthImport().setEnabled(true);

            final failed = result?.failed ?? false;
            final text = result == null
                ? null
                : failed
                    ? result.error
                    : _describe(result);

            // Keep the card at the top of the page in step with this.
            if (mounted) {
              setState(() {
                _message = text;
                _messageIsError = failed;
              });
            }
            if (!ctx.mounted) return;
            setSheetState(() {
              busy = false;
              isConnected = HealthImport().isEnabled;
              message = text;
              isError = failed;
            });
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
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
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      BrandMark(brand: brand, size: 40, radius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              brand.name,
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              brandStatus(
                                brand,
                                isIOS: _isIOS,
                                storeConnected: isConnected,
                                storeName: _storeName,
                              ),
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white38,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    brandSteps(brand, isIOS: _isIOS, storeName: _storeName),
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  if (brand.note != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Colors.white38, size: 17),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              brand.note!,
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white54,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (message != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: isError
                            ? Colors.redAccent.withValues(alpha: 0.10)
                            : _accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isError
                                ? Icons.error_outline_rounded
                                : Icons.check_circle_outline_rounded,
                            color: isError ? Colors.redAccent : _accent,
                            size: 17,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              message!,
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: busy ? null : run,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        disabledBackgroundColor: _accent.withValues(alpha: 0.5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isConnected ? 'Sync now' : 'Connect $_storeName',
                              style: GoogleFonts.hankenGrotesk(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: busy ? null : () => Navigator.pop(ctx),
                      child: Text(
                        'Done',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white54,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _messageBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _messageIsError
            ? Colors.redAccent.withValues(alpha: 0.10)
            : _accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _messageIsError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: _messageIsError ? Colors.redAccent : _accent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _message!,
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white70,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _accent, size: 19),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionHeader(String title) => Text(
        title,
        style: GoogleFonts.hankenGrotesk(
          color: Colors.white38,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );

  static Widget _note(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 18),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white54,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
}
