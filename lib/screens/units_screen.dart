import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/units.dart';

/// Chooses kilometres or miles, and everything that follows from that choice.
///
/// Display only. Every workout stays stored in metres and kilograms whichever
/// is picked, so this can be flipped as often as anyone likes without touching
/// a single recorded number.
class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  static const Color _bg = Color(0xFF0B0B0D);
  static const Color _cardBg = Color(0xFF1C1C1E);
  static const Color _accent = Color(0xFFFF5722);

  bool _isSaving = false;

  Future<void> _select(UnitSystem choice) async {
    if (choice == Units.system || _isSaving) return;

    HapticFeedback.selectionClick();
    final previous = Units.system;

    // Applied straight away so the preview below changes under the finger. The
    // server is the record, but nothing about this is worth a spinner.
    setState(() {
      Units.notifier.value = choice;
      _isSaving = true;
    });

    final value = choice == UnitSystem.imperial ? 'IMPERIAL' : 'METRIC';
    final updated = await ApiService.updateProfile({'unitSystem': value});
    if (!mounted) return;

    // Checked on the echoed value, not on getting a response. A server that
    // does not know this field drops it and still answers 200.
    if (updated == null || updated['unitSystem'] != value) {
      // Put it back rather than leave the app showing a preference the account
      // does not actually hold.
      setState(() {
        Units.notifier.value = previous;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _cardBg,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Could not save that. Check your connection and try again.',
            style: GoogleFonts.hankenGrotesk(color: Colors.white70),
          ),
        ),
      );
      return;
    }

    SessionService().update(updated);
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          'Units of Measure',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<UnitSystem>(
          valueListenable: Units.notifier,
          builder: (context, system, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _card(
                    child: Column(
                      children: [
                        _option(
                          system: UnitSystem.metric,
                          current: system,
                          title: 'Metric',
                          subtitle: 'Kilometres, kilograms, centimetres',
                        ),
                        Divider(
                          height: 1,
                          indent: 20,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                        _option(
                          system: UnitSystem.imperial,
                          current: system,
                          title: 'Imperial',
                          subtitle: 'Miles, pounds, feet and inches',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'PREVIEW',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 6),
                      child: Column(
                        children: [
                          // One real workout, so the change is legible rather
                          // than abstract: a half marathon in 1h 45m.
                          _previewRow('Distance', Units.distance(21097, decimals: 1)),
                          _previewRow('Pace', Units.pace(4.98)),
                          _previewRow('Speed', Units.speed(12.05)),
                          _previewRow('Elevation gain', Units.elevation(240)),
                          _previewRow('Weight', Units.weight(70)),
                          _previewRow('Height', Units.height(178), last: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This changes how numbers are shown, nothing else. Your '
                    'recorded workouts and goals are stored the same way either '
                    'way, so you can switch back at any time.',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white38,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _option({
    required UnitSystem system,
    required UnitSystem current,
    required String title,
    required String subtitle,
  }) {
    final selected = system == current;

    return ListTile(
      onTap: _isSaving ? null : () => _select(system),
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? _accent : Colors.white24,
        size: 22,
      ),
      title: Text(
        title,
        style: GoogleFonts.hankenGrotesk(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.hankenGrotesk(
          color: Colors.white38,
          fontSize: 12.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  static Widget _previewRow(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white54,
              fontSize: 13.5,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }
}
