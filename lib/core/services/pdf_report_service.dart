import 'dart:ui' show ImageByteFormat, Color;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PdfReportService {
  /// Helper to format any date input into DD/MM/YYYY
  static String formatToDDMMYYYY(dynamic dateInput) {
    if (dateInput == null) return DateFormat('dd/MM/yyyy').format(DateTime.now());
    final str = dateInput.toString().split('T').first.trim();
    if (str.contains('-')) {
      final parts = str.split('-');
      if (parts.length == 3 && parts[0].length == 4) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    }
    final parsed = DateTime.tryParse(dateInput.toString());
    if (parsed != null) {
      return DateFormat('dd/MM/yyyy').format(parsed);
    }
    return str;
  }

  /// Helper to format any time input into 12-hour hh:mm a in local device time
  static String formatTo12Hour(dynamic timeInput) {
    if (timeInput == null || timeInput.toString().trim().isEmpty) return '—';
    final str = timeInput.toString().trim();

    // 1. Check if already in 12-hour format e.g. "08:30 AM" or "8:30 am"
    if (RegExp(r'^\d{1,2}:\d{2}\s*(?:AM|PM)$', caseSensitive: false).hasMatch(str)) {
      return str.toUpperCase();
    }

    // 2. Check if it is a raw 24-hr time string e.g. "14:30:00" or "08:30"
    final timeMatch = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(str);
    if (timeMatch != null) {
      final hour = int.parse(timeMatch.group(1)!);
      final minute = int.parse(timeMatch.group(2)!);
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, hour, minute);
      return DateFormat('hh:mm a').format(dt);
    }

    // 3. Parse full DateTime ISO string and ALWAYS convert to device local timezone
    final parsed = DateTime.tryParse(str);
    if (parsed != null) {
      final local = parsed.isUtc ? parsed.toLocal() : (str.endsWith('Z') ? parsed.toLocal() : parsed);
      return DateFormat('hh:mm a').format(local);
    }
    return str;
  }

  /// Generate and preview/print an official Trip Attendance PDF Report
  static Future<void> printTripReport({
    required Map<String, dynamic> trip,
    required List<Map<String, dynamic>> attendanceRecords,
  }) async {
    final pdf = pw.Document();

    final rawTripDate = trip['trip_date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final tripDateFormatted = formatToDDMMYYYY(rawTripDate);
    final tripType = (trip['trip_type'] ?? 'morning').toString().toUpperCase();
    final direction = (trip['trip_direction'] ?? 'boarding').toString().toUpperCase();
    final busNo = trip['bus_number'] ?? trip['busNumber'] ?? 'BUS-001';
    final routeName = trip['route_name'] ?? trip['routeName'] ?? 'Campus Route';
    final inchargeName = trip['incharge_name'] ?? trip['inchargeName'] ?? 'Faculty Incharge';

    final ownStudents = attendanceRecords.where((a) {
      final isGuest = a['is_guest'] == true || a['cross_bus_status'] == 'GUEST';
      final isQuickAdd = a['method'] == 'quick_add' || a['cross_bus_status'] == 'QUICK-ADD';
      final isCross = a['cross_bus_status'] == 'CROSS-BUS';
      return !isGuest && !isQuickAdd && !isCross;
    }).toList();

    final ownPresent = ownStudents.where((a) => (a['status'] ?? '').toString().toLowerCase().trim() == 'present').length;
    final ownAbsent = ownStudents.where((a) => (a['status'] ?? '').toString().toLowerCase().trim() == 'absent').length;
    final ownTotal = ownStudents.length;

    final crossBusStudents = attendanceRecords.where((a) => a['cross_bus_status'] == 'CROSS-BUS').toList();
    final guestStudents = attendanceRecords.where((a) => a['is_guest'] == true || a['cross_bus_status'] == 'GUEST').toList();
    final quickAddStudents = attendanceRecords.where((a) => a['method'] == 'quick_add' || a['cross_bus_status'] == 'QUICK-ADD').toList();

    final ownRate = ownTotal > 0 ? ((ownPresent / ownTotal) * 100).toStringAsFixed(1) : '0.0';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) => _buildPdfHeader(
          tripDate: tripDateFormatted,
          tripType: tripType,
          direction: direction,
          busNo: busNo,
          routeName: routeName,
          inchargeName: inchargeName,
        ),
        footer: (pw.Context context) => _buildPdfFooter(context),
        build: (pw.Context context) => [
          pw.SizedBox(height: 8),

          // Categorized KPI Summary Cards matching Web Dashboard
          pw.Row(
            children: [
              _buildMetricBox('Allocated Roster', '$ownTotal Students', PdfColors.blue900),
              pw.SizedBox(width: 6),
              _buildMetricBox('Own Boarded', '$ownPresent ($ownRate%)', PdfColors.green800),
              pw.SizedBox(width: 6),
              _buildMetricBox('Absent', '$ownAbsent Missing', PdfColors.red800),
              pw.SizedBox(width: 6),
              _buildMetricBox('Cross-Bus', '${crossBusStudents.length} Boarded', PdfColors.amber800),
              if (guestStudents.isNotEmpty || quickAddStudents.isNotEmpty) ...[
                pw.SizedBox(width: 6),
                _buildMetricBox('Guest / Quick', '${guestStudents.length + quickAddStudents.length} Riders', PdfColors.purple800),
              ],
            ],
          ),

          pw.SizedBox(height: 12),
          pw.Text(
            'STUDENT TRANSIT ATTENDANCE & BOARDING GEOFENCE AUDIT ROSTER',
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
          ),
          pw.SizedBox(height: 6),

          // Comprehensive Student Roster Table matching Web Dashboard
          pw.TableHelper.fromTextArray(
            headers: [
              '#',
              'Roll No',
              'Student Name',
              'Institution & Dept',
              'Bus Allocation',
              'Assigned Stop',
              'Boarded Stop',
              'Stop Offset & Direction',
              'Status',
              'Scan Time',
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E40AF)),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            columnWidths: {
              0: const pw.FixedColumnWidth(18),   // #
              1: const pw.FixedColumnWidth(55),   // Roll No
              2: const pw.FlexColumnWidth(2.0),   // Student Name
              3: const pw.FlexColumnWidth(2.0),   // Institution & Dept
              4: const pw.FlexColumnWidth(1.8),   // Bus Allocation
              5: const pw.FlexColumnWidth(1.8),   // Assigned Stop
              6: const pw.FlexColumnWidth(1.8),   // Boarded Stop
              7: const pw.FlexColumnWidth(2.4),   // Stop Offset & Direction
              8: const pw.FixedColumnWidth(48),   // Status
              9: const pw.FixedColumnWidth(55),   // Scan Time
            },
            data: attendanceRecords.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final a = entry.value;
              final isGuest = a['is_guest'] == true || a['cross_bus_status'] == 'GUEST';
              final isQuickAdd = a['method'] == 'quick_add' || a['cross_bus_status'] == 'QUICK-ADD';

              final roll = isGuest
                  ? (a['guest_roll_number'] ?? a['roll_number'] ?? 'GUEST').toString()
                  : (a['roll_number'] ?? a['rollNumber'] ?? 'N/A').toString();

              final rawName = (a['student_name'] ?? a['guest_name'] ?? a['name'] ?? (isGuest ? 'Guest Rider' : 'Student')).toString();
              final name = isGuest
                  ? '$rawName [GUEST SNAP]'
                  : (isQuickAdd ? '$rawName [QUICK-ADD]' : rawName);

              final dept = (a['department'] ?? (isGuest ? 'Guest Rider' : 'General')).toString();
              final inst = (a['institution_type'] ?? 'Campus').toString();
              final year = (a['class_name'] ?? a['year_of_study'] ?? '').toString();
              final instDept = year.isNotEmpty ? '$inst • $dept ($year)' : '$inst • $dept';

              // Bus Assignment & Cross-Bus Boarding Check
              final boardedBus = (a['boarded_bus_number'] ?? a['bus_number'] ?? busNo).toString();
              final assignedBus = (a['assigned_bus_number'] ?? 'None').toString();
              final isCrossBus = a['cross_bus_status'] == 'CROSS-BUS' || (assignedBus != 'None' && assignedBus != boardedBus && (a['status'] ?? '').toString().toLowerCase() != 'absent');
              final busDisplay = isGuest
                  ? '$boardedBus (Guest)'
                  : (isCrossBus ? '$assignedBus -> $boardedBus (Cross)' : boardedBus);

              // Stops
              final assignedStop = (a['assigned_stage_name'] ?? a['assignedStage'] ?? (isGuest ? '—' : 'None')).toString();
              final isAbsent = (a['status'] ?? '').toString().toLowerCase() == 'absent';
              final rawBoardedStop = isAbsent ? '—' : (a['boarded_stage_name'] ?? a['stage_name'] ?? '—').toString();
              final isMismatch = !isAbsent && !isGuest && (
                a['stage_match_status'] == 'MISMATCH' ||
                (assignedStop != 'None' && assignedStop != '—' && rawBoardedStop != '—' && rawBoardedStop != 'None' && assignedStop.trim().toLowerCase() != rawBoardedStop.trim().toLowerCase())
              );
              final boardedStop = isMismatch ? '$rawBoardedStop (Mismatch)' : rawBoardedStop;

              // Stop Offset & Direction (Before Stop / After Stop / On-Stop)
              final devDesc = isGuest
                  ? 'Guest Check-in'
                  : (a['deviation_label'] ?? a['geo_desc'] ?? (a['scan_latitude'] != null ? '${double.tryParse(a['scan_latitude'].toString())?.toStringAsFixed(3) ?? ''}, ${double.tryParse(a['scan_longitude'].toString())?.toStringAsFixed(3) ?? ''}' : 'No GPS')).toString();

              final status = (a['status'] ?? 'present').toString().toUpperCase();

              final time = isAbsent
                  ? '—'
                  : (a['marked_at'] != null
                      ? formatTo12Hour(a['marked_at'])
                      : (a['time'] != null ? formatTo12Hour(a['time']) : '—'));

              return [
                '$idx',
                roll,
                name,
                instDept,
                busDisplay,
                assignedStop,
                boardedStop,
                devDesc,
                status,
                time,
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 24),

          // Signatures Section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 160, height: 1, color: PdfColors.grey500),
                  pw.SizedBox(height: 4),
                  pw.Text('Incharge Signature', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text('($inchargeName)', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 160, height: 1, color: PdfColors.grey500),
                  pw.SizedBox(height: 4),
                  pw.Text('Transport Head / Admin', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text('(VET Fleet Control)', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'VET_Attendance_${busNo}_$tripDateFormatted.pdf',
    );
  }

  static pw.Widget _buildPdfHeader({
    required String tripDate,
    required String tripType,
    required String direction,
    required String busNo,
    required String routeName,
    required String inchargeName,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'VELALAR EDUCATIONAL TRUST (VET)',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E40AF)),
                ),
                pw.Text(
                  'Campus Bus Transport & Student Attendance System',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFEFF6FF),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFF1E40AF)),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text(
                'OFFICIAL REPORT',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E40AF)),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1, color: const PdfColor.fromInt(0xFF1E40AF)),
        pw.SizedBox(height: 6),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Date: $tripDate', style: const pw.TextStyle(fontSize: 8.5)),
            pw.Text('Trip: $tripType ($direction)', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            pw.Text('Bus: $busNo', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            pw.Text('Route: $routeName', style: const pw.TextStyle(fontSize: 8.5)),
            pw.Text('Incharge: $inchargeName', style: const pw.TextStyle(fontSize: 8.5)),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated by TripMate Fleet Control Platform', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 0.8),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: PdfColors.grey100,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  /// Generate a high-resolution printable ID Card / Bus Pass PDF for a student
  static Future<Uint8List> generateStudentQrPassPdfBytes({
    required Map<String, dynamic> student,
  }) async {
    final pdf = pw.Document();

    final name = (student['name'] ?? 'Student').toString();
    final roll = (student['roll_number'] ?? student['rollNumber'] ?? 'N/A').toString();
    final dept = (student['department'] ?? student['class_name'] ?? 'General').toString();
    final qrData = (student['qr_code'] ?? student['qrCode'] ?? 'QR-$roll').toString();
    final bus = (student['bus_number'] ?? student['busNumber'] ?? 'Assigned Bus').toString();
    final route = (student['route_name'] ?? student['routeName'] ?? 'Assigned Route').toString();
    final stop = (student['stage_name'] ?? student['stageName'] ?? 'Assigned Stop').toString();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(100 * PdfPageFormat.mm, 150 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: const PdfColor.fromInt(0xFF1E40AF), width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              color: PdfColors.white,
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF1E40AF),
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'VELALAR EDUCATIONAL TRUST',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'STUDENT DIGITAL BUS PASS',
                        style: pw.TextStyle(
                          color: PdfColors.yellow,
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // QR Code
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFDBEAFE), width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    color: PdfColors.white,
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    width: 100,
                    height: 100,
                  ),
                ),
                pw.SizedBox(height: 8),

                // Student Info
                pw.Text(
                  name.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF1E3A8A),
                  ),
                  textAlign: pw.TextAlign.center,
                  maxLines: 1,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Roll No: $roll',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.Text(
                  'Dept: $dept',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.8, color: const PdfColor.fromInt(0xFFDBEAFE)),
                pw.SizedBox(height: 4),

                // Transport Details
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Bus:', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                    pw.Text(bus, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E40AF))),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Route:', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                    pw.Text(route, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Stop:', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                    pw.Text(stop, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  ],
                ),
                pw.Spacer(),

                // Footer
                pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                pw.Text(
                  'Show this QR upon boarding • TripMate Fleet System',
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print or Save Student QR Pass PDF (Opens Android Print/Save-as-PDF dialog)
  static Future<void> printStudentQrPass({
    required Map<String, dynamic> student,
  }) async {
    final roll = student['roll_number'] ?? student['rollNumber'] ?? 'student';
    final name = (student['name'] ?? 'student').toString().replaceAll(' ', '_');
    final bytes = await generateStudentQrPassPdfBytes(student: student);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'QR_Pass_${roll}_$name.pdf',
    );
  }

  /// Share Student QR Pass as PDF
  static Future<void> shareStudentQrPassPdf({
    required Map<String, dynamic> student,
  }) async {
    final roll = student['roll_number'] ?? student['rollNumber'] ?? 'student';
    final bytes = await generateStudentQrPassPdfBytes(student: student);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'QR_Pass_$roll.pdf',
    );
  }

  /// Share or Save Student QR Pass as high-res PNG image
  static Future<void> shareStudentQrPassImage({
    required Map<String, dynamic> student,
  }) async {
    final roll = student['roll_number'] ?? student['rollNumber'] ?? 'student';
    final bytes = await generateStudentQrPassPdfBytes(student: student);
    await for (final page in Printing.raster(bytes, pages: [0], dpi: 300)) {
      final pngBytes = await page.toPng();
      await Printing.sharePdf(
        bytes: pngBytes,
        filename: 'QR_Pass_$roll.png',
      );
      break;
    }
  }

  /// Generate standalone exact QR Code PDF (Sticker / Pure QR format)
  static Future<Uint8List> generateExactQrOnlyPdfBytes({
    required Map<String, dynamic> student,
  }) async {
    final pdf = pw.Document();
    final name = (student['name'] ?? 'Student').toString();
    final roll = (student['roll_number'] ?? student['rollNumber'] ?? 'N/A').toString();
    final qrData = (student['qr_code'] ?? student['qrCode'] ?? 'QR-$roll').toString();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, 80 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(8),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData,
                  width: 140,
                  height: 140,
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '$name ($roll)',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                  maxLines: 1,
                ),
              ],
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  /// Print or Save Exact Standalone QR Code (Sticker / Clean Print)
  static Future<void> printExactQrOnly({
    required Map<String, dynamic> student,
  }) async {
    final roll = student['roll_number'] ?? student['rollNumber'] ?? 'student';
    final bytes = await generateExactQrOnlyPdfBytes(student: student);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'QR_Code_$roll.pdf',
    );
  }

  /// Share or Save pure QR PNG image (Exact QR Code only)
  static Future<void> shareExactQrImage({
    required Map<String, dynamic> student,
  }) async {
    final roll = student['roll_number'] ?? student['rollNumber'] ?? 'student';
    final qrData = (student['qr_code'] ?? student['qrCode'] ?? 'QR-$roll').toString();
    final painter = QrPainter(
      data: qrData,
      version: QrVersions.auto,
      gapless: true,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
    );
    final picData = await painter.toImageData(600, format: ImageByteFormat.png);
    final pngBytes = picData!.buffer.asUint8List();

    await Printing.sharePdf(
      bytes: pngBytes,
      filename: 'QR_Code_$roll.png',
    );
  }
}
