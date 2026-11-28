import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/admin_provider.dart';
import 'id_card_parser.dart';

class BusStudentScannerScreen extends ConsumerStatefulWidget {
  final String? initialBusId;

  const BusStudentScannerScreen({super.key, this.initialBusId});

  @override
  ConsumerState<BusStudentScannerScreen> createState() => _BusStudentScannerScreenState();
}

class _BusStudentScannerScreenState extends ConsumerState<BusStudentScannerScreen> with WidgetsBindingObserver {
  // Scanner controller supporting all 1D barcode & QR formats on physical ID cards
  late final MobileScannerController _scannerController = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    returnImage: true,
    detectionSpeed: DetectionSpeed.unrestricted,
    detectionTimeoutMs: 300,
    formats: const [BarcodeFormat.all],
  );

  final ImagePicker _imagePicker = ImagePicker();
  TextRecognizer? _textRecognizer;

  String? _selectedBusId;
  Map<String, dynamic>? _selectedBus;
  Map<String, dynamic>? _selectedRoute;

  bool _isProcessing = false;
  bool _isOcrRunning = false;
  String? _lastScannedCode;
  DateTime? _lastScannedTime;

  int _sessionAddedCount = 0;
  final TextEditingController _busSearchController = TextEditingController();
  String _busSearchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _selectedBusId = widget.initialBusId;
    _busSearchController.addListener(() {
      setState(() => _busSearchQuery = _busSearchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    _textRecognizer?.close();
    _busSearchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_selectedBusId != null) {
          try {
            _scannerController.start();
          } catch (_) {}
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        try {
          _scannerController.stop();
        } catch (_) {}
        break;
    }
  }

  // -------------------------------------------------------------
  // Bus Selection Handlers
  // -------------------------------------------------------------
  void _onSelectBus(Map<String, dynamic> bus, List<Map<String, dynamic>> routes) {
    final busId = bus['id']?.toString() ?? '';
    final busRouteId = bus['route_id']?.toString();
    final busRouteName = (bus['route_name'] ?? '').toString().trim().toLowerCase();

    setState(() {
      _selectedBusId = busId;
      _selectedBus = bus;

      // Find route matching this bus without falsely picking routes.first
      _selectedRoute = routes.firstWhere(
        (r) => (busRouteId != null && busRouteId.isNotEmpty && r['id']?.toString() == busRouteId) ||
               (busRouteName.isNotEmpty && (r['route_name'] ?? '').toString().trim().toLowerCase() == busRouteName),
        orElse: () => <String, dynamic>{},
      );
    });

    try {
      _scannerController.start();
    } catch (_) {}
  }

  void _clearSelectedBus() {
    setState(() {
      _selectedBusId = null;
      _selectedBus = null;
      _selectedRoute = null;
    });
  }

  // -------------------------------------------------------------
  // Barcode Detection Stream Handler (with Live Frame OCR)
  // -------------------------------------------------------------
  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing || _selectedBusId == null) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;

      // Prevent immediate double triggers of exact same code within 2.5s
      if (_lastScannedCode == raw && _lastScannedTime != null) {
        if (DateTime.now().difference(_lastScannedTime!).inMilliseconds < 2500) {
          continue;
        }
      }

      _lastScannedCode = raw;
      _lastScannedTime = DateTime.now();

      HapticFeedback.mediumImpact();

      // Automatically run OCR on the live camera frame to extract Name & Dept
      String? ocrText;
      final imageBytes = capture.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        try {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/live_frame_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tempFile.writeAsBytes(imageBytes, flush: true);
          _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
          final recognizedText = await _textRecognizer!.processImage(InputImage.fromFilePath(tempFile.path));
          ocrText = recognizedText.text;
          debugPrint('[LiveScanOCR] Live camera frame OCR text: $ocrText');
          tempFile.delete().ignore();
        } catch (e) {
          debugPrint('[LiveScanOCR] Live OCR note: $e');
        }
      }

      await _processScannedIdData(barcodeValue: raw, ocrText: ocrText);
      break;
    }
  }

  // -------------------------------------------------------------
  // Photo OCR Handler (Camera Snap or Gallery)
  // -------------------------------------------------------------
  Future<void> _captureAndOcrIdCard({required ImageSource source}) async {
    if (_isOcrRunning || _selectedBusId == null) return;
    setState(() => _isOcrRunning = true);

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 98,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo == null) {
        setState(() => _isOcrRunning = false);
        return;
      }

      // 1. Scan for Barcode / QR Code directly from the snapped card photo
      String? barcodeFromPhoto;
      StreamSubscription<BarcodeCapture>? barcodeSub;
      try {
        final completer = Completer<String?>();
        barcodeSub = _scannerController.barcodes.listen((capture) {
          for (final b in capture.barcodes) {
            final raw = b.rawValue?.trim();
            if (raw != null && raw.isNotEmpty && !completer.isCompleted) {
              completer.complete(raw);
              break;
            }
          }
        });

       final capture = await _scannerController.analyzeImage(photo.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
         barcodeFromPhoto = capture.barcodes
          .map((barcode) => barcode.rawValue?.trim())
          .firstWhere(
            (value) => value != null && value.isNotEmpty,
            orElse: () => null,
            );
  }
      } catch (e) {
        debugPrint('[IdCardOCR] Photo barcode scan note: $e');
      } finally {
        await barcodeSub?.cancel();
      }

      debugPrint('[IdCardOCR] Barcode read from card photo: $barcodeFromPhoto');

      // 2. Perform OCR text recognition for Student Name, Dept, etc.
      final inputImage = InputImage.fromFilePath(photo.path);
      _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await _textRecognizer!.processImage(inputImage);

      final fullOcrText = recognizedText.text;
      debugPrint('[IdCardOCR] Raw Recognized Text: $fullOcrText');

      if ((barcodeFromPhoto == null || barcodeFromPhoto.isEmpty) && fullOcrText.trim().isEmpty) {
        if (mounted) {
          AppSnackBar.showWarning(context, 'No barcode or text detected on the card. Please hold closer with good lighting.');
        }
        return;
      }

      HapticFeedback.selectionClick();
      await _processScannedIdData(
        barcodeValue: barcodeFromPhoto,
        ocrText: fullOcrText,
      );
    } catch (e) {
      debugPrint('[IdCardOCR] Error during card scan: $e');
      if (mounted) {
        AppSnackBar.showError(context, 'Card scan failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isOcrRunning = false);
    }
  }

  // -------------------------------------------------------------
  // Core: Parse data, check DB for existing student, show verify sheet
  // -------------------------------------------------------------
  Future<void> _processScannedIdData({String? barcodeValue, String? ocrText}) async {
    setState(() => _isProcessing = true);
    _scannerController.stop();

    try {
      // 1. Parse Barcode & OCR text directly from physical card
      final parseResult = IdCardParser.parse(
        barcodeValue: barcodeValue,
        ocrText: ocrText,
      );

      if (!mounted) return;

      final allBuses = ref.read(adminBusesProvider).value ?? [];
      final allRoutes = ref.read(adminRoutesProvider).value ?? [];

      final activeBus = allBuses.firstWhere(
        (b) => b['id']?.toString() == _selectedBusId,
        orElse: () => _selectedBus ?? (allBuses.isNotEmpty ? allBuses.first : <String, dynamic>{}),
      );

      final busRouteId = activeBus['route_id']?.toString();
      final busRouteName = (activeBus['route_name'] ?? '').toString().trim().toLowerCase();

      final activeRoute = allRoutes.firstWhere(
        (r) => (busRouteId != null && busRouteId.isNotEmpty && r['id']?.toString() == busRouteId) ||
               (busRouteName.isNotEmpty && (r['route_name'] ?? '').toString().trim().toLowerCase() == busRouteName),
        orElse: () => _selectedRoute ?? <String, dynamic>{},
      );

      // 2. Open Verification & Confirmation Dialog Sheet directly
      final added = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _VerifyStudentEnrollSheet(
          bus: activeBus,
          route: activeRoute,
          buses: allBuses,
          routes: allRoutes,
          parseResult: parseResult,
        ),
      );

      if (added == true) {
        setState(() => _sessionAddedCount++);
        ref.invalidate(adminStudentsProvider);
        ref.invalidate(adminBusesProvider);
        ref.invalidate(adminDashboardProvider);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Error processing student ID: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        if (_selectedBusId != null) {
          try {
            _scannerController.start();
          } catch (_) {}
        }
      }
    }
  }

  // -------------------------------------------------------------
  // UI Builder
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final busesAsync = ref.watch(adminBusesProvider);
    final routesAsync = ref.watch(adminRoutesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Bus Student ID Scanner',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.textPrimary),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_sessionAddedCount > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$_sessionAddedCount Enrolled',
                      style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: busesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.danger),
                const SizedBox(height: 12),
                Text('Failed to load bus fleet: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(adminBusesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (buses) {
          final routes = routesAsync.value ?? [];

          // If a bus is selected, show Scanner View
          if (_selectedBusId != null) {
            // Find updated bus object
            final activeBus = buses.firstWhere(
              (b) => b['id']?.toString() == _selectedBusId,
              orElse: () => _selectedBus ?? {},
            );
            return _buildScannerView(activeBus, routes);
          }

          // Otherwise, show Bus Selector List
          return _buildBusSelectionView(buses, routes);
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // VIEW 1: Bus Selection Fleet List
  // -------------------------------------------------------------
  Widget _buildBusSelectionView(List<Map<String, dynamic>> buses, List<Map<String, dynamic>> routes) {
    final filteredBuses = buses.where((b) {
      if (_busSearchQuery.isEmpty) return true;
      final num = (b['bus_number'] ?? '').toString().toLowerCase();
      final reg = (b['registration_no'] ?? '').toString().toLowerCase();
      final route = (b['route_name'] ?? '').toString().toLowerCase();
      return num.contains(_busSearchQuery) || reg.contains(_busSearchQuery) || route.contains(_busSearchQuery);
    }).toList();

    return Column(
      children: [
        // Informational Header Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A).withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step 1: Choose Bus to Onboard',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select any bus to scan student ID cards & add to directory',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Supports Barcode (Code 128/39/QR) + Live Text OCR from physical ID card',
                        style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Search Bus Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _busSearchController,
            decoration: InputDecoration(
              hintText: 'Search bus number or route...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
              suffixIcon: _busSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _busSearchController.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Bus Fleet List
        Expanded(
          child: filteredBuses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_bus_outlined, size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        _busSearchQuery.isEmpty ? 'No buses available in system' : 'No bus matches "$_busSearchQuery"',
                        style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filteredBuses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final bus = filteredBuses[index];
                    final busNumber = bus['bus_number'] ?? 'Bus';
                    final regNo = bus['registration_no'] ?? '';
                    final routeName = bus['route_name'] ?? 'Route unassigned';
                    final capacity = int.tryParse(bus['capacity']?.toString() ?? '50') ?? 50;
                    final studentCount = int.tryParse(bus['student_count']?.toString() ?? '0') ?? 0;
                    final occupancyPercent = capacity > 0 ? ((studentCount / capacity) * 100).clamp(0, 100).toInt() : 0;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () => _onSelectBus(bus, routes),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF1E40AF), size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          busNumber,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary),
                                        ),
                                        if (regNo.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              regNo,
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      routeName,
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.people_outline_rounded, size: 14, color: Colors.blue.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$studentCount / $capacity Students ($occupancyPercent%)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: occupancyPercent >= 90 ? AppTheme.danger : const Color(0xFF0369A1),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _onSelectBus(bus, routes),
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                                label: const Text('Scan & Add'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E40AF),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // VIEW 2: ID Scanner View (Live Barcode & OCR for Selected Bus)
  // -------------------------------------------------------------
  Widget _buildScannerView(Map<String, dynamic> bus, List<Map<String, dynamic>> routes) {
    final busNumber = bus['bus_number'] ?? 'Bus';
    final routeName = bus['route_name'] ?? _selectedRoute?['route_name'] ?? 'Route unassigned';
    final enrolled = int.tryParse(bus['student_count']?.toString() ?? '0') ?? 0;

    return Stack(
      children: [
        // Camera Scanner Stream
        MobileScanner(
          controller: _scannerController,
          onDetect: _onBarcodeDetected,
          errorBuilder: (ctx, err) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.no_photography_outlined, size: 48, color: Colors.white70),
                    const SizedBox(height: 12),
                    Text(
                      'Camera error: ${err.errorCode.name}\nPlease ensure camera permissions are granted.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _scannerController.start(),
                      child: const Text('Restart Scanner'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Scanning Target Frame Overlay
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 290,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF60A5FA), width: 2.8),
                  color: Colors.black.withOpacity(0.08),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Corner accents
                    Positioned(top: 8, left: 8, child: _buildCornerAccent()),
                    Positioned(top: 8, right: 8, child: Transform.rotate(angle: 1.5708, child: _buildCornerAccent())),
                    Positioned(bottom: 8, left: 8, child: Transform.rotate(angle: -1.5708, child: _buildCornerAccent())),
                    Positioned(bottom: 8, right: 8, child: Transform.rotate(angle: 3.14159, child: _buildCornerAccent())),
                    const Center(
                      child: Text(
                        'Align Student ID Barcode or QR Here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '⚡ Auto-scanning Barcode + Live Name OCR',
                  style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),

        // Top Floating Selected Bus Info Pill & Change Button
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E40AF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            busNumber,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF047857),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$enrolled Enrolled',
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        routeName,
                        style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearSelectedBus,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF93C5FD)),
                  label: const Text('Change Bus', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ),
        ),

        // Camera Controls (Torch, Camera Flip) Top Right
        Positioned(
          top: 76,
          right: 14,
          child: Column(
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.flash_on_rounded, size: 20),
                onPressed: () => _scannerController.toggleTorch(),
                tooltip: 'Toggle Flashlight',
              ),
              const SizedBox(height: 6),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.cameraswitch_rounded, size: 20),
                onPressed: () => _scannerController.switchCamera(),
                tooltip: 'Switch Camera',
              ),
            ],
          ),
        ),

        // Bottom OCR & Text Scan Action Bar
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.document_scanner_rounded, color: Color(0xFF1E40AF), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ID Card Text & Name Recognition (OCR)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                    ),
                    if (_isOcrRunning)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E40AF)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Name not in barcode? Snap photo of student ID to auto-read Name, Roll No & Department via OCR text scan.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: _isOcrRunning ? null : () => _captureAndOcrIdCard(source: ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: Text(_isOcrRunning ? 'Reading Card...' : 'Snap ID Card (OCR)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: _isOcrRunning ? null : () => _captureAndOcrIdCard(source: ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded, size: 16, color: Color(0xFF1E40AF)),
                        label: const Text('Pick Image', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E40AF))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1E40AF)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Global Processing HUD Overlay
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF1E40AF)),
                    SizedBox(height: 14),
                    Text(
                      'Reading Student ID Card...',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCornerAccent() {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white, width: 3),
          left: BorderSide(color: Colors.white, width: 3),
        ),
      ),
    );
  }
}

// ============================================================
// VERIFY & ENROLL STUDENT MODAL SHEET
// ============================================================
class _VerifyStudentEnrollSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> bus;
  final Map<String, dynamic> route;
  final IdCardParseResult parseResult;
  final List<Map<String, dynamic>> buses;
  final List<Map<String, dynamic>> routes;

  const _VerifyStudentEnrollSheet({
    required this.bus,
    required this.route,
    required this.parseResult,
    required this.buses,
    required this.routes,
  });

  @override
  ConsumerState<_VerifyStudentEnrollSheet> createState() => _VerifyStudentEnrollSheetState();
}

class _VerifyStudentEnrollSheetState extends ConsumerState<_VerifyStudentEnrollSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _rollCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _deptCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _parentPhoneCtrl;

  late String _institution;
  late String _yearOfStudy;
  late String? _assignedBusId;
  late String? _assignedRouteId;
  String? _selectedStageId;
  bool _isSaving = false;

  static const List<Map<String, String>> _institutionMaster = [
    {'name': 'Vellalar college for women', 'code': 'VCW'},
    {'name': 'Vellalar college of education', 'code': 'VCE'},
    {'name': 'Vellalar college of engineering and technology', 'code': 'VCET'},
    {'name': 'Vellalar college of nursing', 'code': 'VCN'},
    {'name': 'Vellalar college of pharmacy', 'code': 'VCP'},
    {'name': 'Vellalar physiotherapy college', 'code': 'VPC'},
    {'name': 'Vellalar vidyalaya senior secondary school', 'code': 'VVSSS'},
    {'name': 'VET institute of arts and science', 'code': 'VETIAS'},
  ];

  late final List<String> _institutionOptions = [
    ..._institutionMaster.map((e) => e['name']!),
  ];

  final List<String> _yearOptions = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    'Class 10',
    'Class 12',
    'High School',
    'Staff',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.parseResult;

    final initialRoll = p.rollNumber.trim();
    final initialName = p.name.trim();
    final initialDept = p.department.isNotEmpty ? p.department.trim() : 'Computer Science';
    final initialPhone = p.phone.trim();
    final initialParentPhone = p.parentPhone.trim();

    _rollCtrl = TextEditingController(text: initialRoll);
    _nameCtrl = TextEditingController(text: initialName);
    _deptCtrl = TextEditingController(text: initialDept);
    _phoneCtrl = TextEditingController(text: initialPhone);
    _parentPhoneCtrl = TextEditingController(text: initialParentPhone);

    _institution = p.institutionType.toString();
    if (!_institutionOptions.contains(_institution)) {
      String? matched;
      for (final m in _institutionMaster) {
        if (m['code']!.toLowerCase() == _institution.toLowerCase() ||
            m['name']!.toLowerCase() == _institution.toLowerCase()) {
          matched = m['name'];
          break;
        }
      }
      _institution = matched ?? _institutionOptions.first;
    }

    _yearOfStudy = p.yearOfStudy.toString();
    final inferredYear = IdCardParser.inferYearOfStudyFromRoll(initialRoll);
    if (inferredYear != null) {
      _yearOfStudy = inferredYear;
    } else if (!_yearOptions.contains(_yearOfStudy)) {
      _yearOfStudy = '1st Year';
    }

    _rollCtrl.addListener(_onRollNumberChanged);

    // Initialize Verified Assigned Bus & Route
    final initialBusId = widget.bus['id']?.toString();
    _assignedBusId = (initialBusId != null && initialBusId.isNotEmpty)
        ? initialBusId
        : (widget.buses.isNotEmpty ? widget.buses.first['id']?.toString() : null);

    _syncRouteAndStagesForBus(_assignedBusId, preserveStage: false);
  }

  void _syncRouteAndStagesForBus(String? busId, {bool preserveStage = false}) {
    if (busId == null || busId.isEmpty) {
      _assignedRouteId = widget.route['id']?.toString();
      if (!preserveStage) _selectedStageId = null;
      return;
    }

    final matchedBus = widget.buses.firstWhere(
      (b) => b['id']?.toString() == busId,
      orElse: () => widget.bus,
    );

    final routeId = matchedBus['route_id']?.toString();
    final routeName = (matchedBus['route_name'] ?? '').toString().trim().toLowerCase();

    Map<String, dynamic>? matchedRoute;
    if (routeId != null && routeId.isNotEmpty) {
      for (final r in widget.routes) {
        if (r['id']?.toString() == routeId) {
          matchedRoute = r;
          break;
        }
      }
    }
    if (matchedRoute == null && routeName.isNotEmpty) {
      for (final r in widget.routes) {
        if ((r['route_name'] ?? '').toString().trim().toLowerCase() == routeName) {
          matchedRoute = r;
          break;
        }
      }
    }

    _assignedRouteId = matchedRoute?['id']?.toString() ?? routeId;
    if (!preserveStage) {
      _selectedStageId = null;
    }
  }

  void _onRollNumberChanged() {
    final text = _rollCtrl.text.trim();
    final inferred = IdCardParser.inferYearOfStudyFromRoll(text);
    if (inferred != null && inferred != _yearOfStudy && _yearOptions.contains(inferred)) {
      setState(() {
        _yearOfStudy = inferred;
      });
    }
  }

  @override
  void dispose() {
    _rollCtrl.removeListener(_onRollNumberChanged);
    _rollCtrl.dispose();
    _nameCtrl.dispose();
    _deptCtrl.dispose();
    _phoneCtrl.dispose();
    _parentPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEnrollment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_assignedBusId == null || _assignedBusId!.trim().isEmpty) {
      AppSnackBar.showError(context, 'Please verify and select the assigned bus.');
      return;
    }

    setState(() => _isSaving = true);

    final rollNumber = _rollCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();

    try {
      final api = ref.read(apiClientProvider);
      final payload = {
        'name': name,
        'rollNumber': rollNumber,
        'department': _deptCtrl.text.trim(),
        'className': _yearOfStudy,
        'institutionType': _institution,
        'yearOfStudy': _yearOfStudy,
        'phone': _phoneCtrl.text.trim(),
        'parentPhone': _parentPhoneCtrl.text.trim(),
        'assignedBusId': _assignedBusId,
        'assignedRouteId': _assignedRouteId,
        'assignedStageId': _selectedStageId,
      };

      // Check if student with this roll number already exists in DB so we can update or create cleanly
      final res = await api.getAdminStudents(query: {'search': rollNumber, 'limit': 10});
      List<Map<String, dynamic>> items = [];
      dynamic current = res.data;
      if (current is Map && current.containsKey('data')) current = current['data'];
      if (current is Map && current.containsKey('data')) current = current['data'];
      if (current is List) {
        items = current.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }

      Map<String, dynamic>? match;
      for (final it in items) {
        final r = (it['roll_number'] ?? it['rollNumber'] ?? '').toString().trim().toUpperCase();
        if (r == rollNumber) {
          match = it;
          break;
        }
      }

      final chosenBus = widget.buses.firstWhere(
        (b) => b['id']?.toString() == _assignedBusId,
        orElse: () => widget.bus,
      );
      final busDisplay = chosenBus['bus_number'] ?? widget.bus['bus_number'] ?? 'Bus';

      if (match != null) {
        final existingId = match['id'].toString();
        await api.updateAdminStudent(existingId, payload);
        if (mounted) {
          AppSnackBar.showSuccess(
            context,
            '✓ $name ($rollNumber) assigned to $busDisplay!',
          );
        }
      } else {
        await api.createAdminStudent(payload);
        if (mounted) {
          AppSnackBar.showSuccess(
            context,
            '✓ $name ($rollNumber) added to Student Directory on $busDisplay!',
          );
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to save student: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current verified bus object
    final currentBus = widget.buses.firstWhere(
      (b) => b['id']?.toString() == _assignedBusId,
      orElse: () => widget.bus,
    );
    final busNumber = currentBus['bus_number'] ?? widget.bus['bus_number'] ?? 'Bus';
    final regNo = (currentBus['registration_no'] ?? widget.bus['registration_no'] ?? '').toString();

    // Current verified route object
    Map<String, dynamic>? currentRoute;
    if (_assignedRouteId != null && _assignedRouteId!.isNotEmpty) {
      for (final r in widget.routes) {
        if (r['id']?.toString() == _assignedRouteId) {
          currentRoute = r;
          break;
        }
      }
    }
    final routeName = currentRoute?['route_name'] ?? currentBus['route_name'] ?? widget.route['route_name'] ?? 'Route unassigned';

    // Populate route stops
    final stages = currentRoute?['stages'] is List
        ? (currentRoute!['stages'] as List)
        : (widget.route['stages'] is List ? (widget.route['stages'] as List) : []);
    final stageMap = <String, String>{};
    for (final st in stages) {
      if (st is! Map) continue;
      final id = st['id']?.toString() ?? '';
      final sName = st['stage_name']?.toString() ?? 'Stop';
      if (id.isNotEmpty) stageMap[id] = sName;
    }
    final validStageId = stageMap.containsKey(_selectedStageId) ? _selectedStageId : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Title & Bus Assignment Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.how_to_reg_rounded, color: Color(0xFF1E40AF), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Verify & Add to Bus Directory',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Enrolling into $busNumber${regNo.isNotEmpty ? ' ($regNo)' : ''} • $routeName',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Clean Informative Status Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF86EFAC),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF15803D),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Student details scanned from ID card. Verify bus and confirm to enroll.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // --------------------------------------------------
              // ASSIGNED BUS VERIFICATION & SELECTION CARD
              // --------------------------------------------------
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF1E40AF), size: 18),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'ASSIGNED BUS VERIFICATION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF15803D)),
                              SizedBox(width: 3),
                              Text(
                                'CONFIRMED',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Dropdown to verify and switch Assigned Bus
                    DropdownButtonFormField<String>(
                      value: widget.buses.any((b) => b['id']?.toString() == _assignedBusId)
                          ? _assignedBusId
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Assigned Bus *',
                        prefixIcon: const Icon(Icons.directions_bus_outlined, size: 20, color: Color(0xFF1E40AF)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      items: widget.buses.map((b) {
                        final bId = b['id']?.toString() ?? '';
                        final bNum = b['bus_number'] ?? 'Bus';
                        final bPlate = (b['registration_no'] != null && b['registration_no'].toString().isNotEmpty)
                            ? ' • ${b['registration_no']}'
                            : '';
                        final bRoute = (b['route_name'] != null && b['route_name'].toString().isNotEmpty)
                            ? ' (${b['route_name']})'
                            : '';
                        return DropdownMenuItem<String>(
                          value: bId,
                          child: Text(
                            '$bNum$bPlate$bRoute',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (newBusId) {
                        if (newBusId == null) return;
                        setState(() {
                          _assignedBusId = newBusId;
                          _syncRouteAndStagesForBus(newBusId, preserveStage: false);
                        });
                      },
                      validator: (val) => (val == null || val.isEmpty) ? 'Please choose assigned bus' : null,
                    ),

                    const SizedBox(height: 8),

                    // Route details
                    Row(
                      children: [
                        const Icon(Icons.alt_route_rounded, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Route: $routeName',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    if (stageMap.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: validStageId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Boarding Stage / Stop (Optional)',
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF0369A1)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'Default / Campus (No specific stop)',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ),
                          ...stageMap.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) => setState(() => _selectedStageId = val),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Roll Number (Scanned from Barcode or OCR)
              TextFormField(
                controller: _rollCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Roll Number / Student Code *',
                  hintText: 'e.g. 21CS101',
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: const Text(
                      'SCANNED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Roll number is required' : null,
              ),
              const SizedBox(height: 12),

              // Student Name (Scanned from OCR text)
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Student Name *',
                  hintText: 'e.g. Rahul S',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: _nameCtrl.text.isNotEmpty
                      ? const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 18)
                      : null,
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Student name is required' : null,
              ),
              const SizedBox(height: 12),

              // Department / Stream
              TextFormField(
                controller: _deptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Department / Section',
                  hintText: 'e.g. Computer Science, Section A',
                  prefixIcon: Icon(Icons.business_outlined, size: 20),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Institution & Year of Study
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _institution,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Institution',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      items: _institutionOptions.map((inst) {
                        final code = _institutionMaster.firstWhere(
                          (m) => m['name'] == inst,
                          orElse: () => {'code': '', 'name': inst},
                        )['code']!;
                        final label = code.isNotEmpty ? '$inst ($code)' : inst;
                        return DropdownMenuItem(
                          value: inst,
                          child: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _institution = val ?? _institutionOptions.first),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _yearOfStudy,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Class / Year',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      items: _yearOptions
                          .map((yr) => DropdownMenuItem(value: yr, child: Text(yr, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (val) => setState(() => _yearOfStudy = val ?? '1st Year'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Parent Phone (For boarding SMS notifications)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _parentPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Parent Phone (SMS Alerts)',
                        hintText: '10-digit mobile',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Student Phone (Opt)',
                        hintText: 'Mobile number',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit / Confirm Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submitEnrollment,
                  icon: _isSaving
                      ? const SizedBox.shrink()
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Verify & Add to $busNumber',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
