import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/trybe_activity_options.dart';
import '../services/api_service.dart';
import '../services/when_format.dart';

/// Scheduling a Trybe event, or changing one that is already scheduled.
class TrybeEventSheet extends StatefulWidget {
  const TrybeEventSheet._({required this.trybeId, this.event});

  final String trybeId;
  final Map<String, dynamic>? event;

  /// Returns the saved event, or null if the sheet was dismissed.
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String trybeId,
    Map<String, dynamic>? event,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1B1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TrybeEventSheet._(trybeId: trybeId, event: event),
    );
  }

  @override
  State<TrybeEventSheet> createState() => _TrybeEventSheetState();
}

class _TrybeEventSheetState extends State<TrybeEventSheet> {
  static const Color _accent = Color(0xFFFF5722);
  static const Color _fieldBg = Color(0xFF26262A);

  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late DateTime _start;
  Duration? _duration;
  String? _activityType;
  late final List<Duration?> _durations;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _title = TextEditingController(text: '${event?['title'] ?? ''}');
    _description = TextEditingController(text: '${event?['description'] ?? ''}');
    _location = TextEditingController(text: '${event?['location'] ?? ''}');

    final now = DateTime.now();
    final existingStart = DateTime.tryParse('${event?['startsAt'] ?? ''}')?.toLocal();
    // A new event defaults to tomorrow morning, the most common time for a
    // group run.
    _start = existingStart ?? DateTime(now.year, now.month, now.day + 1, 7);

    final existingEnd = DateTime.tryParse('${event?['endsAt'] ?? ''}')?.toLocal();
    _duration = existingEnd?.difference(_start);

    _durations = [
      null,
      const Duration(minutes: 30),
      const Duration(hours: 1),
      const Duration(minutes: 90),
      const Duration(hours: 2),
      const Duration(hours: 3),
    ];
    if (_duration != null && !_durations.contains(_duration)) {
      _durations.add(_duration);
    }

    final type = '${event?['activityType'] ?? ''}';
    _activityType = type.isEmpty ? null : type;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Widget _pickerTheme(BuildContext context, Widget? child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            onPrimary: Colors.white,
            surface: Color(0xFF1E1E22),
          ),
        ),
        child: child!,
      );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _start.isBefore(today) ? today : _start,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      builder: _pickerTheme,
    );
    if (picked == null) return;
    setState(() {
      _start = DateTime(picked.year, picked.month, picked.day, _start.hour, _start.minute);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
      builder: _pickerTheme,
    );
    if (picked == null) return;
    setState(() {
      _start = DateTime(_start.year, _start.month, _start.day, picked.hour, picked.minute);
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the event a name.');
      return;
    }
    // Allow scheduling events starting around now with a 15-minute buffer
    if (_start.isBefore(DateTime.now().subtract(const Duration(minutes: 15)))) {
      setState(() => _error = 'Pick a start time that has not passed yet.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final description = _description.text.trim();
      final location = _location.text.trim();
      final saved = await ApiService.saveTrybeEvent(
        widget.trybeId,
        eventId: widget.event?['id']?.toString(),
        title: title,
        description: description.isEmpty ? null : description,
        location: location.isEmpty ? null : location,
        activityType: _activityType,
        startsAt: _start,
        endsAt: _duration == null ? null : _start.add(_duration!),
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (e is ApiException) {
          if (e.statusCode == 401 ||
              e.message.toLowerCase().contains('authorization') ||
              e.message.toLowerCase().contains('token') ||
              e.message.toLowerCase().contains('jwt')) {
            _error = 'Your session has expired. Please log out and sign in again.';
          } else {
            _error = e.message;
          }
        } else {
          _error = 'Could not save the event. Check your connection and try again.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Drag Handle & Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
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
                      _isEdit ? 'Edit event' : 'New event',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isEdit
                          ? 'Everyone going sees the change.'
                          : 'Members get a notification, and you are marked as going.',
                      style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12.5),
                    ),
                  ],
                ),
              ),

              // 2. Scrollable Form Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('WHAT'),
                      _field(_title, hint: 'e.g. Sunday long run', maxLength: 80),
                      const SizedBox(height: 12),
                      _label('WHEN'),
                      Row(
                        children: [
                          Expanded(
                            child: _pill(
                              icon: Icons.calendar_today_rounded,
                              text: WhenFormat.day(_start),
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _pill(
                              icon: Icons.schedule_rounded,
                              text: WhenFormat.time(_start),
                              onTap: _pickTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final d in _durations)
                            _chip(
                              label: d == null ? 'No end time' : WhenFormat.duration(d),
                              selected: _duration == d,
                              onTap: () => setState(() => _duration = d),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _label('WHERE'),
                      _field(_location, hint: 'Meeting point (optional)', maxLength: 120),
                      const SizedBox(height: 12),
                      _label('ACTIVITY'),
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _chip(
                              label: 'Any',
                              selected: _activityType == null,
                              onTap: () => setState(() => _activityType = null),
                            ),
                            for (final option in trybeActivityOptions) ...[
                              const SizedBox(width: 8),
                              _chip(
                                label: option.name,
                                icon: option.icon,
                                selected: _activityType == option.name,
                                onTap: () => setState(() => _activityType = option.name),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _label('DETAILS'),
                      _field(
                        _description,
                        hint: 'Pace, distance, what to bring (optional)',
                        maxLength: 500,
                        lines: 3,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Pinned Action Button Container
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1E),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.hankenGrotesk(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          disabledBackgroundColor: _accent.withValues(alpha: 0.5),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            : Text(
                                _isEdit ? 'Save changes' : 'Schedule event',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      );

  Widget _field(
    TextEditingController controller, {
    required String hint,
    required int maxLength,
    int lines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      minLines: lines,
      maxLines: lines,
      textCapitalization: TextCapitalization.sentences,
      style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white30, fontSize: 13.5),
        counterText: '',
        filled: true,
        fillColor: _fieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _pill({required IconData icon, required String text, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: _accent, size: 17),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _accent.withValues(alpha: 0.15) : _fieldBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _accent : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? _accent : Colors.white54),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
