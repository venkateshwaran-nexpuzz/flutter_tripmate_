import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_language_button.dart';
import '../providers/driver_provider.dart';
import '../providers/driver_language_provider.dart';
import '../widgets/voice_note_player.dart';

/// Screen for recording trip start or end km + mileage photo + VCET Daily Log Sheet fields
/// (Vehicle No, Bus No, Spare Bus, Route, OP KM, CL KM, Average KM, Remarks, Students Count, Voice Note)
class TripLogScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? trip;
  final String mode; // 'start' | 'end'

  const TripLogScreen({
    super.key,
    required this.trip,
    required this.mode,
  });

  @override
  ConsumerState<TripLogScreen> createState() => _TripLogScreenState();
}

class _TripLogScreenState extends ConsumerState<TripLogScreen> {
  final _kmController = TextEditingController();
  final _spareBusController = TextEditingController();
  final _studentCountController = TextEditingController();
  final _remarksController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  File? _selectedPhoto;
  String? _voicePath;
  bool _isSpareBus = false;
  bool _isSubmitting = false;

  final _picker = ImagePicker();
  late final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isAnalyzingOdometer = false;
  String? _detectedOdometer;
  List<String> _alternateCandidates = [];

  bool get _isMorning => (widget.trip?['trip_type'] as String?) == 'morning';
  bool get _isEvening => (widget.trip?['trip_type'] as String?) == 'evening';
  bool get _isSpecial => (widget.trip?['trip_type'] as String?) == 'special';

  // In College Bus Log Sheet:
  // Evening trip = Shift Opening KM (mode == 'start')
  // Morning trip = Shift Closing KM (mode == 'end', or completes the cycle)
  // Special trip = Separate extra duty cycle (mode == 'start' or mode == 'end')
  bool get _isShiftOpening => !_isSpecial && (_isEvening || (widget.mode == 'start' && !_isMorning));
  bool get _isShiftClosing => !_isSpecial && (_isMorning || widget.mode == 'end');
  bool get _isSpecialOpening => _isSpecial && (widget.mode == 'start' || widget.trip?['start_km'] == null);
  bool get _isSpecialClosing => _isSpecial && (widget.mode == 'end' || widget.trip?['start_km'] != null);

  double? get _prevEveningOpKm {
    if (widget.trip?['prev_evening_op_km'] != null) {
      return double.tryParse(widget.trip!['prev_evening_op_km'].toString());
    }
    return null;
  }

  String? get _prevEveningDate {
    final d = widget.trip?['prev_evening_date'] as String?;
    if (d != null && d.isNotEmpty) {
      try {
        final parts = d.split('-');
        if (parts.length == 3) {
          return '${parts[2]}/${parts[1]}';
        }
      } catch (_) {}
      return d;
    }
    return null;
  }

  double? get _startKm {
    if (widget.trip?['start_km'] != null) {
      final v = double.tryParse(widget.trip!['start_km'].toString());
      if (v != null && v > 0) return v;
    }
    if (_isMorning && _prevEveningOpKm != null) {
      return _prevEveningOpKm;
    }
    return null;
  }

  double? get _enteredKm => double.tryParse(_kmController.text.trim());

  double? get _calculatedTotalKm {
    if ((_isShiftClosing || _isSpecialClosing) && _startKm != null && _enteredKm != null) {
      final diff = _enteredKm! - _startKm!;
      return diff >= 0 ? diff : null;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _kmController.addListener(() {
      if (mounted) setState(() {});
    });

    if (widget.trip?['spare_bus'] != null && widget.trip!['spare_bus'].toString().isNotEmpty) {
      _isSpareBus = true;
      _spareBusController.text = widget.trip!['spare_bus'].toString();
    }
    if (widget.trip?['student_count'] != null) {
      _studentCountController.text = widget.trip!['student_count'].toString();
    }
    if (widget.trip?['remarks'] != null) {
      _remarksController.text = widget.trip!['remarks'].toString();
    }
  }

  @override
  void dispose() {
    _kmController.dispose();
    _spareBusController.dispose();
    _studentCountController.dispose();
    _remarksController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked != null) {
      final file = File(picked.path);
      setState(() => _selectedPhoto = file);
      _analyzeOdometerPhoto(file);
    }
  }

  Future<void> _analyzeOdometerPhoto(File imageFile) async {
    setState(() {
      _isAnalyzingOdometer = true;
      _detectedOdometer = null;
      _alternateCandidates = [];
    });

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final candidates = _extractOdometerCandidates(recognizedText);

      if (mounted) {
        if (candidates.isNotEmpty) {
          final bestMatch = candidates.first;
          setState(() {
            _detectedOdometer = bestMatch;
            _alternateCandidates = candidates.skip(1).take(3).toList();
          });

          // Auto-fill into KM field if currently empty
          if (_kmController.text.trim().isEmpty) {
            _kmController.text = bestMatch;
            _showSuccess('மீட்டர் ரீடிங் $bestMatch KM கண்டறியப்பட்டு பூர்த்தி செய்யப்பட்டது!');
          }
        } else {
          setState(() {
            _detectedOdometer = null;
            _alternateCandidates = [];
          });
        }
      }
    } catch (e) {
      debugPrint('[Odometer OCR Error] $e');
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingOdometer = false);
      }
    }
  }

  List<String> _extractOdometerCandidates(RecognizedText recognizedText) {
    final scored = <String, int>{};

    void addCandidate(String numStr, int score) {
      final clean = numStr.trim();
      final val = double.tryParse(clean);
      if (val == null) return;
      // Typical vehicle odometer range
      if (val < 100 || val > 1500000) return;

      // Penalize floating point numbers (odometer is integer)
      if (clean.contains('.')) {
        score -= 25;
      }

      // If shift closing, validate against opening KM
      if (_isShiftClosing && _startKm != null) {
        if (val < _startKm!) {
          // Closing KM cannot be lower than opening KM
          score -= 100;
        } else if (val >= _startKm! && val <= _startKm! + 450) {
          // Normal daily shift distance
          score += 150;
        } else if (val > _startKm! + 450) {
          score -= 30;
        }
      }

      scored[clean] = (scored[clean] ?? 0) + score;
    }

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.toUpperCase();

        final hasOdo = text.contains('ODO') || text.contains('ODOMETER') || text.contains('TOTAL');
        final hasKm = text.contains('KM');
        final hasTrip = text.contains('TRIP');
        final hasSpeed = text.contains('KM/H') || text.contains('MPH') || text.contains('SPEED');
        final hasRange = text.contains('RANGE') || text.contains('AVG');

        // Regex for candidate numbers: 4 to 7 digits
        final matches = RegExp(r'\b\d{4,7}(\.\d)?\b').allMatches(text);
        for (final m in matches) {
          final matchedStr = m.group(0)!;
          int lineScore = 30;
          if (hasOdo) lineScore += 80;
          if (hasKm && !hasSpeed) lineScore += 35;
          if (hasTrip) lineScore -= 45;
          if (hasSpeed) lineScore -= 60;
          if (hasRange) lineScore -= 30;

          // Prefer 5-6 digit numbers without decimal
          if (!matchedStr.contains('.') && matchedStr.length >= 5 && matchedStr.length <= 6) {
            lineScore += 40;
          }

          addCandidate(matchedStr, lineScore);
        }

        // Also check spaced numbers like "1 0 4 5 2 0"
        final spacedMatches = RegExp(r'(\d\s+){4,6}\d').allMatches(text);
        for (final sm in spacedMatches) {
          final joined = sm.group(0)!.replaceAll(RegExp(r'\s+'), '');
          int spaceScore = 40;
          if (hasOdo) spaceScore += 80;
          if (hasKm) spaceScore += 30;
          if (hasTrip) spaceScore -= 40;
          addCandidate(joined, spaceScore);
        }
      }
    }

    final sortedKeys = scored.keys.toList()
      ..sort((a, b) => (scored[b] ?? 0).compareTo(scored[a] ?? 0));

    final positiveKeys = sortedKeys.where((k) => (scored[k] ?? 0) > 0).toList();
    return positiveKeys.isNotEmpty ? positiveKeys : sortedKeys;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPhoto == null) {
      _showError('தயவுசெய்து மீட்டர் படம் எடுக்கவும் (Meter photo is required)');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final km = double.parse(_kmController.text.trim());
      final tripId = widget.trip!['id'] as String;

      final spareBus = _isSpareBus ? _spareBusController.text.trim() : null;
      const String? studentCount = null;
      final remarks = _remarksController.text.trim();

      if (_isSpecial) {
        final logId = widget.trip?['log_id']?.toString() ?? widget.trip?['id']?.toString();
        if (_isSpecialOpening) {
          await api.driverStartTrip(
            tripId: tripId,
            startKm: km,
            tripType: 'special',
            photoPath: _selectedPhoto!.path,
            spareBus: spareBus,
            studentCount: studentCount,
            remarks: remarks.isNotEmpty ? remarks : (widget.trip?['remarks']?.toString() ?? 'சிறப்புப் பயணம்'),
            voicePath: _voicePath,
          );
        } else {
          await api.driverEndTrip(
            tripId: tripId,
            logId: logId,
            tripType: 'special',
            endKm: km,
            startKm: _startKm,
            photoPath: _selectedPhoto!.path,
            spareBus: spareBus,
            studentCount: studentCount,
            remarks: remarks.isNotEmpty ? remarks : (widget.trip?['remarks']?.toString() ?? 'சிறப்புப் பயணம்'),
            voicePath: _voicePath,
          );
        }
      } else if (_isMorning) {
        // Morning trip completes the shift cycle (Closing KM)
        await api.driverEndTrip(
          tripId: tripId,
          endKm: km,
          startKm: _startKm,
          photoPath: _selectedPhoto!.path,
          spareBus: spareBus,
          studentCount: studentCount,
          remarks: remarks,
          voicePath: _voicePath,
        );
      } else if (_isEvening) {
        // Evening trip starts the shift cycle (Opening KM)
        await api.driverStartTrip(
          tripId: tripId,
          startKm: km,
          photoPath: _selectedPhoto!.path,
          spareBus: spareBus,
          studentCount: studentCount,
          remarks: remarks,
          voicePath: _voicePath,
        );
      } else {
        // Fallback for other trips
        if (_isShiftOpening) {
          await api.driverStartTrip(
            tripId: tripId,
            startKm: km,
            photoPath: _selectedPhoto!.path,
            spareBus: spareBus,
            studentCount: studentCount,
            remarks: remarks,
            voicePath: _voicePath,
          );
        } else {
          await api.driverEndTrip(
            tripId: tripId,
            endKm: km,
            startKm: _startKm,
            photoPath: _selectedPhoto!.path,
            spareBus: spareBus,
            studentCount: studentCount,
            remarks: remarks,
            voicePath: _voicePath,
          );
        }
      }

      ref.invalidate(driverTodayTripsProvider);

      if (mounted) {
        final successMsg = _isSpecial
            ? (_isSpecialOpening
                ? 'சிறப்புப் பயணம் ஆரம்ப KM வெற்றிகரமாக பதிவாயிற்று (Special Trip Started)!'
                : 'சிறப்புப் பயணம் முடிவு KM வெற்றிகரமாக பதிவாயிற்று (Special Trip Completed)!')
            : _isEvening
                ? 'மாலை ஆரம்ப ரீடிங் வெற்றிகரமாக பதிவாயிற்று (Opening KM Recorded)!'
                : _isMorning
                    ? 'காலை முடிவு ரீடிங் மற்றும் ஷிப்ட் KM வெற்றிகரமாக பதிவாயிற்று (Closing KM Recorded)!'
                    : 'மீட்டர் பதிவு வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது!';
        _showSuccess(successMsg);
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) context.pop();
      }
    } catch (e) {
      _showError('பதிவு தோல்வியடைந்தது: ${formatApiError(e)}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(driverProfileProvider).valueOrNull;
    final tripType = widget.trip?['trip_type'] as String?;
    final typeLabel = _isSpecial
        ? 'சிறப்பு பயணம்'
        : tripType == 'morning'
            ? 'காலை பயணம்'
            : tripType == 'evening'
                ? 'மாலை பயணம்'
                : 'பயணம்';

    final busNumber = profile?['bus_number'] ?? widget.trip?['bus_number'] ?? 'Bus';
    final vehiclePlate = profile?['vehicle_number'] ?? widget.trip?['vehicle_number'] ?? 'வண்டி எண்';
    final routeName = profile?['route_name'] ?? widget.trip?['route_name'] ?? 'ரூட்';

    String appBarTitle;
    String appBarSubtitle;
    if (_isSpecial) {
      appBarTitle = _isSpecialOpening ? 'சிறப்புப் பயண ஆரம்ப KM' : 'சிறப்புப் பயண முடிவு KM';
      appBarSubtitle = widget.trip?['remarks'] != null && widget.trip!['remarks'].toString().isNotEmpty
          ? widget.trip!['remarks'].toString()
          : 'கூடுதல் / சிறப்புப் பணி மீட்டர் பதிவு';
    } else if (_isEvening) {
      appBarTitle = 'மாலை தொடக்க KM பதிவு';
      appBarSubtitle = 'இந்த ஷிப்டின் ஆரம்ப ரீடிங் (Opening KM)';
    } else if (_isMorning) {
      appBarTitle = 'காலை முடிவு KM பதிவு';
      appBarSubtitle = _prevEveningDate != null
          ? 'நேற்றைய மாலை ($_prevEveningDate) ➔ இன்றைய காலை சுழற்சி'
          : 'நேற்றைய மாலை ➔ இன்றைய காலை சுழற்சி';
    } else {
      appBarTitle = _isShiftOpening ? 'தொடக்க KM பதிவு' : 'முடிவு KM பதிவு';
      appBarSubtitle = typeLabel;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appBarTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              appBarSubtitle,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
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
                // ── 1. BUS LOG SHEET HEADER CARD ──────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Color(0x331E40AF), blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  busNumber,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                vehiclePlate,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _isSpecial
                                  ? const Color(0xFF0284C7)
                                  : _isEvening
                                      ? const Color(0xFF7C3AED)
                                      : _isMorning
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _isSpecial
                                  ? 'சிறப்புப் பயணம்'
                                  : _isEvening
                                      ? 'மாலை பயணம் (OP)'
                                      : _isMorning
                                          ? 'காலை பயணம் (CL)'
                                          : typeLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.alt_route_rounded, color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'ரூட்: $routeName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── SHIFT CYCLE GUIDANCE BANNER ────────────────────────
                if (_isEvening)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.25)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.nightlight_round, color: Color(0xFF7C3AED), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'மாலை தொடக்க ரீடிங் (Opening KM)',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF5B21B6)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'இன்று மாலை காலேஜில் இருந்து கிளம்பும் போது மீட்டரில் உள்ள ரீடிங்கை பதிவு செய்யவும். இது நாளை காலை பயணம் முடியும் வரை இந்த சுழற்சியின் ஆரம்ப KM ஆகும்.',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF6D28D9), height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_isMorning)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD97706).withOpacity(0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.wb_sunny_rounded, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'காலை முடிவு ரீடிங் (Closing KM)',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFB45309)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _startKm != null
                                    ? 'நேற்றைய மாலை (${_prevEveningDate ?? 'Previous Evening'}) ஆரம்ப ரீடிங் முதல் இன்றைய காலை வரை ஓடிய மொத்த KM தானாக கணக்கிடப்படும்.'
                                    : 'இன்றைய காலை காலேஜ் வந்தடைந்ததும் உள்ள முடிவு மீட்டர் ரீடிங்கை உள்ளிடவும்.',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isSpecial)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFF0284C7), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isSpecialOpening
                                    ? 'சிறப்புப் பயணம் - ஆரம்ப KM பதிவு'
                                    : 'சிறப்புப் பயணம் - முடிவு KM பதிவு',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0369A1)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isSpecialOpening
                                    ? 'சிறப்பு அல்லது கூடுதல் பணிக்காக பஸ்ஸை எடுக்கும் போது உள்ள மீட்டரின் ஆரம்ப ரீடிங்கை பதிவு செய்யவும்.'
                                    : (_startKm != null
                                        ? 'பணி முடிந்து திரும்பியதும் முடிவு ரீடிங்கை பதிவு செய்யவும். ஆரம்ப ரீடிங் (${_startKm!.toStringAsFixed(1)} KM) கழித்து இந்த சிறப்புப் பயணத்தின் மொத்த தூரம் கணக்கிடப்படும்.'
                                        : 'பணி முடிந்து திரும்பியதும் உள்ள முடிவு மீட்டர் ரீடிங்கை பதிவு செய்யவும்.'),
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF0369A1), height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isEvening || _isMorning || _isSpecial) const SizedBox(height: 14),

                // ── 2. SPARE BUS SELECTION ─────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _isSpareBus = !_isSpareBus),
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _isSpareBus,
                              activeColor: const Color(0xFF1E40AF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) => setState(() => _isSpareBus = val ?? false),
                            ),
                            const Expanded(
                              child: Text(
                                'மாற்று பஸ் (Spare Bus பயன்படுத்தப்பட்டதா?)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isSpareBus) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _spareBusController,
                          decoration: InputDecoration(
                            hintText: 'மாற்று பஸ் வண்டி எண் (எ.கா: TN56V2097)',
                            prefixIcon: const Icon(Icons.directions_bus_rounded, color: Color(0xFF1E40AF), size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                          validator: (v) {
                            if (_isSpareBus && (v == null || v.trim().isEmpty)) {
                              return 'மாற்று பஸ் எண் உள்ளிடவும்';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 3. KM ENTRY & REAL-TIME CALCULATION ────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isSpecial
                                ? Icons.stars_rounded
                                : _isEvening
                                    ? Icons.nightlight_round
                                    : _isMorning
                                        ? Icons.wb_sunny_rounded
                                        : Icons.speed_rounded,
                            color: _isSpecial
                                ? const Color(0xFF0284C7)
                                : _isEvening
                                    ? const Color(0xFF7C3AED)
                                    : _isMorning
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF1E40AF),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isSpecial
                                  ? (_isSpecialOpening ? 'சிறப்புப் பயண ஆரம்ப KM (Start KM)' : 'சிறப்புப் பயண முடிவு KM (End KM)')
                                  : _isEvening
                                      ? 'மாலை தொடக்க KM (Shift Opening KM)'
                                      : _isMorning
                                          ? 'காலை முடிவு KM (Shift Closing KM)'
                                          : _isShiftOpening
                                              ? 'தொடக்க KM (OP KM)'
                                              : 'முடிவு KM (CL KM)',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // If closing shift (Morning or Special End), show Opening KM
                      if ((_isShiftClosing || _isSpecialClosing) && _startKm != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.history_rounded, color: Color(0xFF16A34A), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isSpecial
                                        ? 'சிறப்புப் பயண ஆரம்ப KM (Start KM):'
                                        : (_prevEveningDate != null
                                            ? 'நேற்றைய மாலை ($_prevEveningDate) ஆரம்ப KM:'
                                            : 'ஆரம்ப KM (Opening KM):'),
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF15803D), fontSize: 12.5),
                                  ),
                                ],
                              ),
                              Text(
                                '${_startKm!.toStringAsFixed(1)} KM',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      Text(
                        _isSpecial
                            ? (_isSpecialOpening
                                ? 'சிறப்புப் பணிக்கு பஸ் எடுக்கும் போது உள்ள ரீடிங்'
                                : 'சிறப்புப் பணி முடிந்து திரும்பியதும் உள்ள முடிவு ரீடிங்')
                            : _isEvening
                                ? 'மாலை புறப்படும் போது மீட்டரில் உள்ள ரீடிங் (Opening KM)'
                                : _isMorning
                                    ? 'காலை காலேஜ் வந்தடைந்ததும் உள்ள முடிவு ரீடிங் (Closing KM)'
                                    : _isShiftOpening
                                        ? 'ஆரம்ப மீட்டர் ரீடிங் உள்ளிடவும்'
                                        : 'முடிவு மீட்டர் ரீடிங் உள்ளிடவும்',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 6),

                      // KM Input Field
                      TextFormField(
                        controller: _kmController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'எ.கா: 104520',
                          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                          prefixIcon: Icon(
                            _isEvening ? Icons.directions_bus_rounded : Icons.edit_road_rounded,
                            color: _isEvening ? const Color(0xFF7C3AED) : const Color(0xFF1E40AF),
                          ),
                          suffixText: 'KM',
                          suffixStyle: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _isEvening ? const Color(0xFF7C3AED) : const Color(0xFF1E40AF),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _isEvening ? const Color(0xFF7C3AED) : const Color(0xFF1E40AF),
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'KM உள்ளிடவும்';
                          final val = double.tryParse(v.trim());
                          if (val == null) return 'சரியான எண் உள்ளிடவும்';
                          if ((_isShiftClosing || _isSpecialClosing) && _startKm != null && val <= _startKm!) {
                            return 'முடிவு KM ($val) ஆரம்ப KM-ஐ ($_startKm) விட அதிகமாக இருக்க வேண்டும்';
                          }
                          return null;
                        },
                      ),

                      // LIVE SHIFT OR SPECIAL TOTAL KM BADGE
                      if ((_isShiftClosing || _isSpecialClosing) && _calculatedTotalKm != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF059669).withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calculate_rounded, color: Color(0xFF059669), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isSpecial ? 'சிறப்புப் பயண மொத்த தூரம்:' : 'மொத்த ஷிப்ட் தூரம் (CL − OP):',
                                    style: const TextStyle(
                                      color: Color(0xFF059669),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${_calculatedTotalKm!.toStringAsFixed(1)} KM',
                                style: const TextStyle(
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

              // ── 5. VOICE NOTE WITH INSTANT PLAYBACK ────────────────
              VoiceNotePlayerWidget(
                initialVoicePath: _voicePath,
                title: 'குரல் குறிப்பு (Voice Note Recording & Playback)',
                onVoiceChanged: (path) => setState(() => _voicePath = path),
              ),
              const SizedBox(height: 16),

              // ── 6. ODOMETER PHOTO PICKER ───────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.camera_alt_rounded, color: Color(0xFF1E40AF), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'மீட்டர் படம் (Odometer Photo)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _showPhotoOptions(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: _selectedPhoto != null ? 200 : 130,
                        decoration: BoxDecoration(
                          color: _selectedPhoto != null ? Colors.transparent : const Color(0xFFF0F4FF),
                          border: Border.all(
                            color: _selectedPhoto != null
                                ? const Color(0xFF1E40AF)
                                : const Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: _selectedPhoto != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  children: [
                                    Image.file(_selectedPhoto!, width: double.infinity, fit: BoxFit.cover),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          _selectedPhoto = null;
                                          _detectedOdometer = null;
                                          _alternateCandidates = [];
                                        }),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                                            SizedBox(width: 4),
                                            Text('மாற்று', style: TextStyle(color: Colors.white, fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_rounded, size: 36, color: Color(0xFF1E40AF)),
                                  SizedBox(height: 8),
                                  Text(
                                    'மீட்டர் படம் எடுக்க தொட்டுத் தொடங்கு',
                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    // ── ATTACHED AI ODOMETER RECOGNITION CARD ──────────
                    if (_isAnalyzingOdometer) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF1D4ED8)),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'மீட்டர் ரீடிங் AI மூலம் ஸ்கேன் செய்யப்படுகிறது...',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_selectedPhoto != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _detectedOdometer != null ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _detectedOdometer != null ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _detectedOdometer != null ? Icons.auto_awesome_rounded : Icons.info_outline_rounded,
                                      size: 16,
                                      color: _detectedOdometer != null ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _detectedOdometer != null
                                          ? 'AI கண்டறிந்த ரீடிங் (Odometer OCR)'
                                          : 'படத்திலிருந்து ரீடிங் (AI Scanner)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _detectedOdometer != null ? const Color(0xFF15803D) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () => _analyzeOdometerPhoto(_selectedPhoto!),
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF2563EB)),
                                        SizedBox(width: 3),
                                        Text('மீண்டும் ஸ்கேன்', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_detectedOdometer != null) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF86EFAC)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.speed_rounded, size: 18, color: Color(0xFF15803D)),
                                          const SizedBox(width: 8),
                                          Text(
                                            '$_detectedOdometer KM',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF15803D),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF15803D),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 1,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _kmController.text = _detectedOdometer!;
                                      });
                                      _showSuccess('KM ரீடிங் பயன்படுத்தப்பட்டது ($_detectedOdometer KM)!');
                                    },
                                    icon: const Icon(Icons.check_rounded, size: 16),
                                    label: const Text('பயன்படுத்து', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                  ),
                                ],
                              ),
                              if (_alternateCandidates.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text('பிற எண்கள்: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                    ..._alternateCandidates.map((cand) => InkWell(
                                      onTap: () {
                                        setState(() {
                                          _detectedOdometer = cand;
                                          _kmController.text = cand;
                                        });
                                        _showSuccess('KM ரீடிங் மாற்றப்பட்டது ($cand KM)!');
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Text(
                                          '$cand KM',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                                        ),
                                      ),
                                    )),
                                  ],
                                ),
                              ],
                            ] else ...[
                              const Text(
                                'படத்திலிருந்து எண் தெளிவாகத் தெரியவில்லை. மேலே உள்ள KM ஃபீல்டில் நேரடியாகத் தட்டச்சு செய்யவும்.',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── 7. SUBMIT BUTTON ───────────────────────────────────
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
                      : Icon(
                          _isSpecial
                              ? (_isSpecialOpening ? Icons.play_arrow_rounded : Icons.flag_rounded)
                              : _isEvening
                                  ? Icons.nightlight_round
                                  : _isMorning
                                      ? Icons.check_circle_rounded
                                      : (_isShiftOpening ? Icons.play_arrow_rounded : Icons.stop_rounded),
                          size: 19,
                        ),
                  label: Text(
                    _isSpecial
                        ? (_isSpecialOpening ? 'சிறப்புப் பயண ஆரம்ப KM பதிவு செய்' : 'சிறப்புப் பயண முடிவு KM பதிவு செய்')
                        : _isEvening
                            ? ref.tr('save_evening_km')
                            : _isMorning
                                ? ref.tr('save_morning_km')
                                : (_isShiftOpening ? ref.tr('save_start_km') : ref.tr('save_end_km')),
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isSpecial
                        ? (_isSpecialOpening ? const Color(0xFF0284C7) : const Color(0xFF059669))
                        : (_isEvening
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF059669)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    ),
  );
}

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Text(
              'மீட்டர் படம் தேர்வு',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF1E40AF)),
              ),
              title: const Text('கேமராவில் படம் எடு', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF059669)),
              ),
              title: const Text('கேலரியில் இருந்து தேர்வு', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
