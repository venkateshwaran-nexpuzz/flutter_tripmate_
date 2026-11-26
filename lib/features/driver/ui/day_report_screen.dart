import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_language_button.dart';
import '../providers/driver_provider.dart';
import '../providers/driver_language_provider.dart';
import '../widgets/voice_note_player.dart';

/// Day-end report form (Tamil UI)
/// Dropdowns for vehicle condition + image uploads + voice recording
class DayReportScreen extends ConsumerStatefulWidget {
  const DayReportScreen({super.key});

  @override
  ConsumerState<DayReportScreen> createState() => _DayReportScreenState();
}

class _DayReportScreenState extends ConsumerState<DayReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _issueController = TextEditingController();
  final _picker = ImagePicker();

  // Form values
  String? _fuelStatus;
  String? _cleanlinessStatus;
  String? _tyreCondition;
  String? _brakeCondition;
  String? _overallCondition;
  String? _engineOilLevel;
  String? _adblueLevel;
  String? _clutchBrakePressure;
  String? _seatsWindowCondition;

  // Files
  final List<File> _issueImages = [];
  String? _voicePath;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _issueController.dispose();
    super.dispose();
  }

  // ── Image Picker ──────────────────────────────────────────
  Future<void> _pickImage() async {
    if (_issueImages.length >= 5) {
      _showError('அதிகபட்சம் 5 படங்கள் மட்டுமே அனுமதிக்கப்படுகிறது');
      return;
    }
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (picked != null) {
      setState(() => _issueImages.add(File(picked.path)));
    }
  }

  // ── Submit ────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(apiClientProvider);

      await api.driverSubmitDayReport(
        fields: {
          if (_fuelStatus != null) 'fuelStatus': _fuelStatus!,
          if (_cleanlinessStatus != null) 'cleanlinessStatus': _cleanlinessStatus!,
          if (_tyreCondition != null) 'tyreCondition': _tyreCondition!,
          if (_brakeCondition != null) 'brakeCondition': _brakeCondition!,
          if (_overallCondition != null) 'overallCondition': _overallCondition!,
          if (_engineOilLevel != null) 'engineOilLevel': _engineOilLevel!,
          if (_adblueLevel != null) 'adblueLevel': _adblueLevel!,
          if (_clutchBrakePressure != null) 'clutchBrakePressure': _clutchBrakePressure!,
          if (_seatsWindowCondition != null) 'seatsWindowCondition': _seatsWindowCondition!,
          if (_issueController.text.isNotEmpty) 'issueDescription': _issueController.text.trim(),
        },
        imagePaths: _issueImages.map((f) => f.path).toList(),
        voicePath: _voicePath,
      );

      ref.invalidate(driverReportsProvider);

      if (mounted) {
        _showSuccess('நாள் அறிக்கை வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது!');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.pop();
      }
    } catch (e) {
      _showError('சமர்ப்பிக்க தோல்வியடைந்தது: ${formatApiError(e)}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.danger, behavior: SnackBarBehavior.floating),
      );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [const Icon(Icons.check_circle_rounded, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(msg))]),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'நாள் அறிக்கை (Day Report)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
            ),
            Text(
              'வாகன நிலை & ஆய்வு அறிக்கை',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: const [
          Center(child: AppLanguageButton(compact: true)),
          SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. General Vehicle Condition Card ────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(
                        icon: Icons.directions_bus_rounded,
                        title: 'பொது வாகன நிலை',
                        subtitle: 'General Vehicle Condition',
                      ),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),

                      _DropdownField(
                        label: 'எரிபொருள் நிலை (Fuel Status)',
                        icon: Icons.local_gas_station_rounded,
                        value: _fuelStatus,
                        items: const {
                          'full': 'நிரம்பியுள்ளது (Full)',
                          'adequate': 'போதுமான அளவு (Adequate)',
                          'low': 'குறைவாக உள்ளது (Low)',
                          'empty': 'காலியாக உள்ளது (Empty)',
                        },
                        onChanged: (v) => setState(() => _fuelStatus = v),
                        required: true,
                      ),
                      const SizedBox(height: 14),

                      _DropdownField(
                        label: 'சுத்தத்தன்மை (Cleanliness)',
                        icon: Icons.cleaning_services_rounded,
                        value: _cleanlinessStatus,
                        items: const {
                          'clean': 'சுத்தமாக உள்ளது (Clean)',
                          'needs_cleaning': 'சுத்தம் செய்ய வேண்டும் (Needs Cleaning)',
                          'dirty': 'அழுக்காக உள்ளது (Dirty)',
                        },
                        onChanged: (v) => setState(() => _cleanlinessStatus = v),
                        required: true,
                      ),
                      const SizedBox(height: 14),

                      _DropdownField(
                        label: 'டயர் நிலை (Tyre Condition)',
                        icon: Icons.tire_repair_rounded,
                        value: _tyreCondition,
                        items: const {
                          'good': 'நல்ல நிலை (Good)',
                          'fair': 'சாதாரண நிலை (Fair)',
                          'poor': 'சேவை தேவை (Needs Service / Poor)',
                        },
                        onChanged: (v) => setState(() => _tyreCondition = v),
                        required: true,
                      ),
                      const SizedBox(height: 14),

                      _DropdownField(
                        label: 'பிரேக் நிலை (Brake Condition)',
                        icon: Icons.stop_circle_outlined,
                        value: _brakeCondition,
                        items: const {
                          'good': 'நல்ல நிலை (Good)',
                          'fair': 'சாதாரண நிலை (Fair)',
                          'needs_service': 'சேவை தேவை (Needs Service)',
                        },
                        onChanged: (v) => setState(() => _brakeCondition = v),
                        required: true,
                      ),
                      const SizedBox(height: 14),

                      _DropdownField(
                        label: 'ஒட்டுமொத்த நிலை (Overall Condition)',
                        icon: Icons.assessment_rounded,
                        value: _overallCondition,
                        items: const {
                          'excellent': 'மிகச் சிறந்தது (Excellent)',
                          'good': 'நல்லது (Good)',
                          'fair': 'சாதாரணம் (Fair)',
                          'poor': 'மோசம் (Poor)',
                        },
                        onChanged: (v) => setState(() => _overallCondition = v),
                        required: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 2. Engine & Cabin Inspection Card ────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(
                        icon: Icons.build_circle_rounded,
                        title: 'எஞ்சின் & கேபின் ஆய்வு',
                        subtitle: 'Engine & Cabin Inspection',
                      ),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),

                      _DropdownField(
                        label: 'எஞ்சின் ஆயில் நிலை (Engine Oil Level)',
                        icon: Icons.oil_barrel_rounded,
                        value: _engineOilLevel,
                        items: const {
                          'adequate': 'போதுமான அளவு (Adequate)',
                          'low': 'குறைவாக உள்ளது (Low)',
                        },
                        onChanged: (v) => setState(() => _engineOilLevel = v),
                      ),
                      const SizedBox(height: 14),

                      _DropdownField(
                        label: 'AdBlue / DEF நிலை (BS6 Buses)',
                        icon: Icons.water_drop_rounded,
                        value: _adblueLevel,
                        items: const {
                          'full': 'நிரம்பியுள்ளது (Full)',
                          'half': 'பாதி அளவு (Half)',
                          'low': 'குறைவு (< 20% Low)',
                          'na': 'பொருந்தாது (Not Applicable / Non-BS6)',
                        },
                        onChanged: (v) => setState(() => _adblueLevel = v),
                      ),
                      const SizedBox(height: 14),

                      _DropdownField(
                        label: 'பிரேக் & கிளட்ச் நிலை (Brake/Clutch Pressure)',
                        icon: Icons.speed_rounded,
                        value: _clutchBrakePressure,
                        items: const {
                          'normal': 'இயல்பு நிலை (Normal)',
                          'hard': 'கடினமாக உள்ளது (Hard)',
                          'low_pressure': 'குறைந்த அழுத்தம் (Low Pressure)',
                        },
                        onChanged: (v) => setState(() => _clutchBrakePressure = v),
                      ),
                      const SizedBox(height: 14),

                      _DropdownField(
                        label: 'இருக்கைகள் & ஜன்னல்கள் (Seats & Windows)',
                        icon: Icons.airline_seat_recline_normal_rounded,
                        value: _seatsWindowCondition,
                        items: const {
                          'all_intact': 'சேதமில்லை (All Intact)',
                          'broken_glass': 'கண்ணாடி உடைந்துள்ளது (Broken Glass)',
                          'seat_tear': 'இருக்கை கிழிந்துள்ளது (Seat Tear)',
                        },
                        onChanged: (v) => setState(() => _seatsWindowCondition = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 3. Issue Reporting Section Card ──────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(
                        icon: Icons.report_problem_rounded,
                        title: 'பிரச்சனை அறிக்கை (விரும்பினால்)',
                        subtitle: 'Optional Issue Reporting',
                      ),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),

                      const Text(
                        'பிரச்சனை விளக்கம் (Issue Description)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _issueController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'ஏதேனும் பிரச்சனை இருந்தால் இங்கே தட்டச்சு செய்யவும்...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Voice recording with instant in-app playback
                VoiceNotePlayerWidget(
                  initialVoicePath: _voicePath,
                  title: 'குரல் குறிப்பு (Voice Note)',
                  onVoiceChanged: (path) => setState(() => _voicePath = path),
                ),
                const SizedBox(height: 16),

                // Issue images card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: _ImageUploadSection(
                    images: _issueImages,
                    onAdd: _pickImage,
                    onRemove: (i) => setState(() => _issueImages.removeAt(i)),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 19),
                    label: Text(
                      ref.tr('save_report'),
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Section Header
// ============================================================
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E40AF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF1E40AF), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
}

// ============================================================
// Dropdown Field
// ============================================================
class _DropdownField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  final bool required;

  const _DropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF1E40AF)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
          decoration: InputDecoration(
            hintText: 'தேர்வு செய்க...',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.5),
            ),
          ),
          items: items.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
          validator: required
              ? (v) => v == null ? '$label தேர்வு செய்யவும்' : null
              : null,
        ),
      ],
    );
  }
}


// ============================================================
// Image Upload Section
// ============================================================
class _ImageUploadSection extends StatelessWidget {
  final List<File> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _ImageUploadSection({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'பிரச்சனை படங்கள்',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(width: 8),
            Text(
              '(${images.length}/5)',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Add button
              if (images.length < 5)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 90,
                    height: 90,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF1E40AF).withOpacity(0.4), width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF1E40AF).withOpacity(0.06),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded, color: Color(0xFF1E40AF), size: 28),
                        SizedBox(height: 4),
                        Text('படம் சேர்', style: TextStyle(color: Color(0xFF1E40AF), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              // Image previews
              ...images.asMap().entries.map(
                (entry) => Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(entry.value, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 14,
                      child: GestureDetector(
                        onTap: () => onRemove(entry.key),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
