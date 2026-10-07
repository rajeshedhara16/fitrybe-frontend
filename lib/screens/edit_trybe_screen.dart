import 'dart:io';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/trybe_activity_options.dart';
import '../services/api_service.dart';
import '../services/units.dart';

/// Editing a Trybe's photo, details, privacy and weekly goal.
///
/// Open to the creator and captains. Only the creator may change who can join,
/// so captains see that setting but cannot change it. Pops with the updated
/// Trybe, or null when nothing was saved.
class EditTrybeScreen extends StatefulWidget {
  const EditTrybeScreen({super.key, required this.trybe});

  final Map<String, dynamic> trybe;

  @override
  State<EditTrybeScreen> createState() => _EditTrybeScreenState();
}

class _EditTrybeScreenState extends State<EditTrybeScreen> {
  static const Color _accent = Color(0xFFFF5722);
  static const Color _bg = Color(0xFF131316);
  static const Color _cardBg = Color(0xFF1E1E22);

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _goal;
  late bool _isPublic;
  late final List<String> _originalInterests;
  late final Set<String> _interests;

  final ImagePicker _picker = ImagePicker();
  File? _newImage;
  bool _removeImage = false;
  bool _showAllActivities = false;
  bool _saving = false;

  Map<String, dynamic> get _t => widget.trybe;
  bool get _isCreator => _t['myRole'] == 'CREATOR';
  double? get _originalGoalKm => (_t['weeklyGoalKm'] as num?)?.toDouble();
  String? get _currentImageUrl =>
      _removeImage ? null : ApiService.media(_t['imageUrl'] as String?);

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: '${_t['name'] ?? ''}');
    _description = TextEditingController(text: '${_t['description'] ?? ''}');
    _location = TextEditingController(text: '${_t['location'] ?? ''}');
    final goal = _originalGoalKm;
    _goal = TextEditingController(text: goal == null ? '' : _plainNumber(Units.fromKm(goal)));
    _isPublic = _t['isPublic'] != false;

    _originalInterests = [
      for (final a in (_t['activityInterests'] as List? ?? const [])) '$a',
    ];
    _interests = {..._originalInterests};
    final category = '${_t['category'] ?? ''}'.trim();
    if (_interests.isEmpty && category.isNotEmpty) _interests.add(category);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _location.dispose();
    _goal.dispose();
    super.dispose();
  }

  static String _plainNumber(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF26262A),
        content: Text(message, style: GoogleFonts.hankenGrotesk(color: Colors.white70)),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() {
        _newImage = File(picked.path);
        _removeImage = false;
      });
    } catch (e) {
      debugPrint('Edit Trybe image pick error: $e');
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      HapticFeedback.vibrate();
      _snack('Give your Trybe a name.');
      return;
    }
    if (_interests.isEmpty) {
      _snack('Pick at least one activity.');
      return;
    }

    final goalText = _goal.text.trim().replaceAll(',', '.');
    double? goalKm;
    if (goalText.isNotEmpty) {
      final entered = double.tryParse(goalText);
      if (entered == null || entered <= 0) {
        _snack('Enter the weekly goal as a number, like 50, or leave it empty.');
        return;
      }
      goalKm = double.parse(Units.toKm(entered).toStringAsFixed(2));
    }
    final originalGoal = _originalGoalKm;
    final goalChanged = goalKm == null
        ? originalGoal != null
        : originalGoal == null || (goalKm - originalGoal).abs() > 0.05;

    // Send only what changed, so a captain saving a new name never trips the
    // creator-only privacy rule by resending the privacy setting as it was.
    final description = _description.text.trim();
    final location = _location.text.trim();
    final interests = _interests.toList();
    final nameChanged = name != '${_t['name'] ?? ''}';
    final descriptionChanged = description != '${_t['description'] ?? ''}'.trim();
    final locationChanged = location != '${_t['location'] ?? ''}'.trim();
    final interestsChanged = !listEquals(interests, _originalInterests);
    final privacyChanged = _isCreator && _isPublic != (_t['isPublic'] != false);
    final imageChanged = _newImage != null || _removeImage;

    if (!nameChanged &&
        !descriptionChanged &&
        !locationChanged &&
        !interestsChanged &&
        !privacyChanged &&
        !goalChanged &&
        !imageChanged) {
      Navigator.pop(context);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    try {
      final updated = await ApiService.updateTrybe(
        '${_t['id']}',
        name: nameChanged ? name : null,
        description: descriptionChanged ? description : null,
        location: locationChanged ? location : null,
        category: interestsChanged ? interests.first : null,
        activityInterests: interestsChanged ? interests : null,
        isPublic: privacyChanged ? _isPublic : null,
        weeklyGoalKm: goalChanged ? goalKm : null,
        clearWeeklyGoal: goalChanged && goalKm == null,
        image: _newImage,
        removeImage: _removeImage,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e is ApiException ? e.message : 'Could not save your changes. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _newImage;
    final imageUrl = _currentImageUrl;
    final hasPhoto = image != null || imageUrl != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Trybe',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                    )
                  : Text(
                      'Save',
                      style: GoogleFonts.hankenGrotesk(
                        color: _accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent.withValues(alpha: 0.5), width: 2),
                    image: image != null
                        ? DecorationImage(image: FileImage(image), fit: BoxFit.cover)
                        : imageUrl != null
                            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                            : null,
                  ),
                  child: hasPhoto
                      ? null
                      : Icon(Icons.groups_rounded, color: _accent.withValues(alpha: 0.7), size: 40),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _pickImage,
                    child: Text(
                      hasPhoto ? 'Change photo' : 'Add photo',
                      style: GoogleFonts.hankenGrotesk(color: _accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (hasPhoto)
                    TextButton(
                      onPressed: () => setState(() {
                        _newImage = null;
                        _removeImage = _t['imageUrl'] != null;
                      }),
                      child: Text(
                        'Remove',
                        style: GoogleFonts.hankenGrotesk(color: Colors.white54, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('TRYBE NAME'),
            _input(_name, hint: 'e.g. Patna Striders', maxLength: 60),
            const SizedBox(height: 18),
            _sectionTitle('DESCRIPTION'),
            _input(_description, hint: 'What this Trybe is about', lines: 3, maxLength: 500),
            const SizedBox(height: 18),
            _sectionTitle('LOCATION'),
            _input(_location, hint: 'City or area (optional)', maxLength: 120),
            const SizedBox(height: 22),
            _sectionTitle('WEEKLY GOAL'),
            Text(
              "Everyone's distance counts toward it, Monday to Sunday. Leave empty for no goal.",
              style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 10),
            _input(
              _goal,
              hint: 'e.g. 100',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              suffix: Units.distanceUnit,
            ),
            const SizedBox(height: 22),
            _sectionTitle('WHO CAN JOIN'),
            if (!_isCreator)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Only the creator can change this.',
                  style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12),
                ),
              ),
            Opacity(
              opacity: _isCreator ? 1 : 0.5,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _typeCard(
                        title: 'Public',
                        desc: 'Anyone can find and join',
                        icon: Icons.public_rounded,
                        selected: _isPublic,
                        onTap: _isCreator ? () => setState(() => _isPublic = true) : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _typeCard(
                        title: 'Private',
                        desc: 'Only people who are invited',
                        icon: Icons.lock_outline_rounded,
                        selected: !_isPublic,
                        onTap: _isCreator ? () => setState(() => _isPublic = false) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('ACTIVITIES'),
                GestureDetector(
                  onTap: () => setState(() => _showAllActivities = !_showAllActivities),
                  child: Text(
                    _showAllActivities ? 'See less' : 'See more',
                    style: GoogleFonts.hankenGrotesk(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                for (final option in _orderedOptions()) _activityChip(option),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<({String name, IconData icon})> _orderedOptions() {
    final selected = trybeActivityOptions.where((o) => _interests.contains(o.name));
    final rest = trybeActivityOptions.where((o) => !_interests.contains(o.name));
    final ordered = [...selected, ...rest];
    if (_showAllActivities) return ordered;
    return ordered.take(selected.length > 8 ? selected.length : 8).toList();
  }

  Widget _activityChip(({String name, IconData icon}) option) {
    final selected = _interests.contains(option.name);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (!selected) {
            _interests.add(option.name);
          } else if (_interests.length > 1) {
            _interests.remove(option.name);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _accent.withValues(alpha: 0.15) : _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _accent : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(option.icon, size: 16, color: selected ? _accent : Colors.white60),
            const SizedBox(width: 6),
            Text(
              option.name,
              style: GoogleFonts.hankenGrotesk(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white60,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _input(
    TextEditingController controller, {
    required String hint,
    int lines = 1,
    int? maxLength,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? suffix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    );
    return TextField(
      controller: controller,
      minLines: lines,
      maxLines: lines,
      maxLength: maxLength,
      keyboardType: keyboard,
      inputFormatters: formatters,
      style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white30),
        counterText: '',
        suffixText: suffix,
        suffixStyle: GoogleFonts.hankenGrotesk(color: Colors.white54, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: _cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accent),
        ),
      ),
    );
  }

  Widget _typeCard({
    required String title,
    required String desc,
    required IconData icon,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _accent.withValues(alpha: 0.1) : _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _accent : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: selected ? _accent : Colors.white54, size: 20),
                if (selected) const Icon(Icons.check_circle_rounded, color: _accent, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(desc, style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
