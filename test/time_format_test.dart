import 'package:flutter_test/flutter_test.dart';
import 'package:tripmate_app/core/services/pdf_report_service.dart';

void main() {
  group('PdfReportService.formatTo12Hour Tests', () {
    test('Scenario 1: Already 12-hour formatted string', () {
      expect(PdfReportService.formatTo12Hour('08:30 AM'), '08:30 AM');
      expect(PdfReportService.formatTo12Hour('04:15 PM'), '04:15 PM');
    });

    test('Scenario 2: Raw 24-hour time string', () {
      expect(PdfReportService.formatTo12Hour('08:30:00'), '08:30 AM');
      expect(PdfReportService.formatTo12Hour('14:45:00'), '02:45 PM');
      expect(PdfReportService.formatTo12Hour('17:05'), '05:05 PM');
      expect(PdfReportService.formatTo12Hour('00:15:00'), '12:15 AM');
      expect(PdfReportService.formatTo12Hour('12:00:00'), '12:00 PM');
    });

    test('Scenario 3: Null or empty inputs', () {
      expect(PdfReportService.formatTo12Hour(null), '—');
      expect(PdfReportService.formatTo12Hour(''), '—');
    });

    test('Scenario 4: Valid ISO DateTime string', () {
      // Local date time
      final now = DateTime(2026, 10, 1, 8, 30);
      expect(PdfReportService.formatTo12Hour(now.toIso8601String()), '08:30 AM');

      final evening = DateTime(2026, 10, 1, 16, 45);
      expect(PdfReportService.formatTo12Hour(evening.toIso8601String()), '04:45 PM');
    });
  });
}
