import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/gps/gps_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../providers/incharge_provider.dart';

class ManualEntryScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final Map<String, dynamic>? extra;

  const ManualEntryScreen({super.key, required this.sessionId, this.extra});

  @override
  ConsumerState<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends ConsumerState<ManualEntryScreen> {
  final _rollController = TextEditingController();
  final _searchController = TextEditingController();
  final _imagePicker = ImagePicker();

  Map<String, dynamic>? _selectedStudent;
  XFile? _capturedPhoto;
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  bool _submitting = false;
  String? _error;
  Position? _position;
  GpsLocationDetails? _locationDetails;
  bool _isGpsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGPS();
  }

  @override
  void dispose() {
    _rollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGPS() async {
    setState(() => _isGpsLoading = true);
    try {
      final details = await ref.read(gpsServiceProvider).getAccurateLocationDetails(
        accuracyThreshold: 20.0,
        resolveAddress: true,
      );
      if (mounted) {
        setState(() {
          _locationDetails = details;
          if (details != null) {
            _position = Position(
              latitude: details.latitude,
              longitude: details.longitude,
              timestamp: details.timestamp,
              accuracy: details.accuracy,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            );
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isGpsLoading = false);
  }

  Future<void> _capturePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (photo != null && mounted) {
        setState(() => _capturedPhoto = photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _searchStudents(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);

    try {
      final session = widget.extra ?? {};
      final busId = session['bus_id'] as String?;
      final api = ref.read(apiClientProvider);
      final res = await api.searchStudents(query.trim(), busId: busId);
      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(res.data['data'] ?? []);
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _verifyAndSubmit() async {
    final rollNo = _selectedStudent?['roll_number'] ?? _rollController.text.trim();
    if (rollNo.isEmpty) {
      setState(() => _error = 'Please enter or select a student roll number');
      return;
    }
    if (_submitting || ref.read(globalLoadingProvider).isLoading) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final session = widget.extra ?? {};
      final attendanceType = session['trip_type'] == 'evening' ? 'exit' : 'boarding';

      await globalAction(() async {
        await ref.read(attendanceMarkingStateProvider.notifier).markByPhotoVerification(
          sessionId: widget.sessionId,
          rollNumber: rollNo,
          latitude: _position?.latitude,
          longitude: _position?.longitude,
          notes: _capturedPhoto != null ? 'Photo Verified via Incharge Camera' : 'Manual Entry Verified',
          attendanceType: attendanceType,
        );
      },
      message: 'Verifying & recording attendance for $rollNo...',
      successMessage: 'Attendance marked & verified for $rollNo!',
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final errText = e.toString().contains('already')
            ? 'Attendance already recorded for this student today'
            : 'Failed to record attendance: ${e.toString().replaceAll('Exception:', '')}';
        setState(() {
          _submitting = false;
          _error = errText;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text('Manual & Photo Verification', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.textPrimary)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error banner
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Live Native GPS & Reverse Geocoded Address Card
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Color(0xFF16A34A), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'GPS LOCATION',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF15803D),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (_position != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: (_position!.accuracy <= 20) ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Accuracy: ±${_position!.accuracy.round()}m',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: (_position!.accuracy <= 20) ? const Color(0xFF166534) : const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _locationDetails?.displayName ?? (_position != null ? 'GPS (${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)})' : 'Acquiring GPS location...'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            if (_position != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Lat: ${_position!.latitude.toStringAsFixed(6)}, Lon: ${_position!.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isGpsLoading ? null : _loadGPS,
                        icon: _isGpsLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)))
                            : const Icon(Icons.refresh_rounded, color: Color(0xFF16A34A), size: 20),
                        tooltip: 'Refresh GPS',
                      ),
                    ],
                  ),
                ),

                // Step 1: Student Lookup Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          FeatureIconBadge(icon: Icons.person_search_rounded, color: AppTheme.primaryAccent, size: 36),
                          SizedBox(width: 10),
                          Text('Step 1: Identify Student', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => _searchStudents(v),
                        decoration: InputDecoration(
                          labelText: 'Search Roll Number or Name',
                          hintText: 'e.g. 21CS101 or Rahul',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryAccent),
                          suffixIcon: _searching ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),

                      // Search Suggestions dropdown
                      if (_searchResults.isNotEmpty && _selectedStudent == null) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final st = _searchResults[i];
                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFEFF6FF),
                                  child: Icon(Icons.person, color: AppTheme.primaryAccent, size: 18),
                                ),
                                title: Text(st['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                subtitle: Text('${st['roll_number']} • ${st['department'] ?? 'Student'}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                onTap: () {
                                  setState(() {
                                    _selectedStudent = st;
                                    _rollController.text = st['roll_number'] ?? '';
                                    _searchResults = [];
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],

                      // Selected Student Preview
                      if (_selectedStudent != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppTheme.primaryAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_selectedStudent!['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary)),
                                    Text('Roll: ${_selectedStudent!['roll_number']} • ${_selectedStudent!['department'] ?? ''}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                                onPressed: () => setState(() => _selectedStudent = null),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Step 2: Camera Photo Capture Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          FeatureIconBadge(icon: Icons.camera_alt_rounded, color: AppTheme.secondary, size: 36),
                          SizedBox(width: 10),
                          Text('Step 2: Student Photo Verification', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (_capturedPhoto != null) ...[
                        Center(
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  File(_capturedPhoto!.path),
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: InkWell(
                                  onTap: () => setState(() => _capturedPhoto = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 6,
                                left: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('PHOTO VERIFIED', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _capturePhoto,
                          icon: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryAccent),
                          label: Text(_capturedPhoto == null ? 'Take Student Photo' : 'Retake Photo',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryAccent)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Step 3: GPS Confirmation & Submit Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const FeatureIconBadge(icon: Icons.my_location_rounded, color: AppTheme.success, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('GPS Location Tag', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary)),
                                Text(
                                  _position != null
                                      ? '${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)} (Acc: ±${_position!.accuracy.round()}m)'
                                      : 'Fetching GPS coordinates...',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _verifyAndSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _submitting
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.verified_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text('Confirm Verification & Mark Present', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                  ],
                                ),
                        ),
                      ),
                    ],
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
