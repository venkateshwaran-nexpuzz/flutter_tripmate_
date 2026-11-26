import 'package:flutter_test/flutter_test.dart';
import 'package:tripmate_app/features/admin/ui/id_card_parser.dart';

void main() {
  group('IdCardParser Tests', () {
    test('Scenario 1: 1D Barcode with Roll Number', () {
      final result = IdCardParser.parse(barcodeValue: '21CS101');
      expect(result.rollNumber, '21CS101');
    });

    test('Scenario 2: ID Card OCR with labeled fields', () {
      const sampleOcrText = '''
KONGU ENGINEERING COLLEGE
PERUNDURAI, ERODE - 638060
STUDENT IDENTITY CARD
NAME: RAHUL SHARMA
ROLL NO: 21CS101
DEPT: COMPUTER SCIENCE AND ENGINEERING
BATCH: 2021-2025
PARENT MOBILE: 9876543210
BLOOD GROUP: B+
''';

      final result = IdCardParser.parse(
        barcodeValue: '21CS101',
        ocrText: sampleOcrText,
      );

      expect(result.rollNumber, '21CS101');
      expect(result.name, 'RAHUL SHARMA');
      expect(result.department, 'Computer Science');
      expect(result.parentPhone, '9876543210');
      expect(result.bloodGroup, 'B+');
    });

    test('Scenario 3: ID Card OCR where Name has no "NAME:" label', () {
      const sampleOcrText = '''
VELALAR COLLEGE OF ENGINEERING AND TECHNOLOGY
AUTONOMOUS INSTITUTION
STUDENT ID CARD
ARUN KUMAR M
ROLL NO: 22IT045
INFORMATION TECHNOLOGY
CONTACT: 9842109876
''';

      final result = IdCardParser.parse(ocrText: sampleOcrText);

      expect(result.rollNumber, '22IT045');
      expect(result.name, 'ARUN KUMAR M');
      expect(result.department, 'Information Technology');
      expect(result.phone, '9842109876');
    });

    test('Scenario 4: QR/Barcode with Pipe Delimited Format', () {
      const barcodeValue = '23AD012|PRIYA DHARSHINI|AI & DS';
      final result = IdCardParser.parse(barcodeValue: barcodeValue);

      expect(result.rollNumber, '23AD012');
      expect(result.name, 'PRIYA DHARSHINI');
      expect(result.department, 'AI & DS');
    });

    test('Scenario 5: QR/Barcode with JSON Format', () {
      const barcodeValue = '{"roll": "20ME088", "name": "SURESH K", "dept": "Mechanical"}';
      final result = IdCardParser.parse(barcodeValue: barcodeValue);

      expect(result.rollNumber, '20ME088');
      expect(result.name, 'SURESH K');
      expect(result.department, 'Mechanical');
    });

    test('Scenario 6: Year of Study Inference with Various Prefixes', () {
      // 26 -> 1st Year
      expect(IdCardParser.inferYearOfStudyFromRoll('26CS001'), '1st Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('737626104001'), '1st Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('VCET26CS001'), '1st Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('2026BCSE01'), '1st Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('VCET/26/001'), '1st Year');

      // 25 -> 2nd Year
      expect(IdCardParser.inferYearOfStudyFromRoll('25IT045'), '2nd Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('737625104015'), '2nd Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('VCW25MAT02'), '2nd Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('2025IT012'), '2nd Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('7376-25-104-001'), '2nd Year');

      // 24 -> 3rd Year
      expect(IdCardParser.inferYearOfStudyFromRoll('24CS101'), '3rd Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('737624104001'), '3rd Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('VCET24CS001'), '3rd Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('2024BCSE001'), '3rd Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('24-CS-101'), '3rd Year');

      // 23 -> 4th Year
      expect(IdCardParser.inferYearOfStudyFromRoll('23ME120'), '4th Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('737623104005'), '4th Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('VCET23CS01'), '4th Year');
      expect(IdCardParser.inferYearOfStudyFromRoll('2023MECH01'), '4th Year');

      // Invalid / PIN codes should NOT be inferred as year
      expect(IdCardParser.inferYearOfStudyFromRoll('638012'), isNull);
      expect(IdCardParser.inferYearOfStudyFromRoll('638060'), isNull);
      expect(IdCardParser.inferYearOfStudyFromRoll('9876543210'), isNull);
    });

    test('Scenario 7: Barcode with ]c1, ]C1, AIM symbologies and scanner prefixes', () {
      // 1D Barcode with lowercase ]c1 (GS1-128)
      final r1 = IdCardParser.parse(barcodeValue: ']c121CS101');
      expect(r1.rollNumber, '21CS101');

      // 1D Barcode with uppercase ]C1
      final r2 = IdCardParser.parse(barcodeValue: ']C122IT045');
      expect(r2.rollNumber, '22IT045');

      // 1D Barcode with standard Code 128 prefix ]C0
      final r3 = IdCardParser.parse(barcodeValue: ']C0737624104001');
      expect(r3.rollNumber, '737624104001');

      // Scanner prefix cn1
      final r4 = IdCardParser.parse(barcodeValue: 'cn123ME120');
      expect(r4.rollNumber, '23ME120');

      // Pipe-delimited barcode with ]c1 prefix
      final r5 = IdCardParser.parse(barcodeValue: ']c124CS101|ARUN KUMAR|CSE');
      expect(r5.rollNumber, '24CS101');
      expect(r5.name, 'ARUN KUMAR');

      // JSON barcode with ]Q1 symbology prefix
      final r6 = IdCardParser.parse(barcodeValue: ']Q1{"roll":"25IT001","name":"PRIYA"}');
      expect(r6.rollNumber, '25IT001');
      expect(r6.name, 'PRIYA');

      // sanitizeBarcode direct check
      expect(IdCardParser.sanitizeBarcode(']c121CS101'), '21CS101');
      expect(IdCardParser.sanitizeBarcode(']C121CS101'), '21CS101');
      expect(IdCardParser.sanitizeBarcode(']A0CODE39VAL'), 'CODE39VAL');
      expect(IdCardParser.sanitizeBarcode(']e0DATABAR'), 'DATABAR');
    });
  });
}
