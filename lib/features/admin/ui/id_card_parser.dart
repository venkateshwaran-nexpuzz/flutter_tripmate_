import 'dart:convert';

/// Data class representing parsed student details from ID card barcode or OCR text
class IdCardParseResult {
  final String rollNumber;
  final String name;
  final String department;
  final String yearOfStudy;
  final String institutionType;
  final String phone;
  final String parentPhone;
  final String bloodGroup;
  final String rawText;

  const IdCardParseResult({
    this.rollNumber = '',
    this.name = '',
    this.department = '',
    this.yearOfStudy = '1st Year',
    this.institutionType = 'Engineering',
    this.phone = '',
    this.parentPhone = '',
    this.bloodGroup = '',
    this.rawText = '',
  });

  IdCardParseResult copyWith({
    String? rollNumber,
    String? name,
    String? department,
    String? yearOfStudy,
    String? institutionType,
    String? phone,
    String? parentPhone,
    String? bloodGroup,
    String? rawText,
  }) {
    return IdCardParseResult(
      rollNumber: rollNumber ?? this.rollNumber,
      name: name ?? this.name,
      department: department ?? this.department,
      yearOfStudy: yearOfStudy ?? this.yearOfStudy,
      institutionType: institutionType ?? this.institutionType,
      phone: phone ?? this.phone,
      parentPhone: parentPhone ?? this.parentPhone,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      rawText: rawText ?? this.rawText,
    );
  }
}

class IdCardParser {
  static const Set<String> _institutionBlacklistWords = {
    'COLLEGE', 'INSTITUTE', 'INSTITUTION', 'UNIVERSITY', 'SCHOOL', 'CAMPUS',
    'AUTONOMOUS', 'AFFILIATED', 'ACCREDITED', 'GOVERNMENT', 'TAMIL NADU', 'INDIA',
    'TRUST', 'ACADEMY', 'EDUCATION', 'EDUCATIONAL', 'POLYTECHNIC', 'ENGINEERING AND TECHNOLOGY',
  };

  static const Set<String> _labelBlacklistWords = {
    'STUDENT', 'IDENTITY', 'CARD', 'ID CARD', 'PASS', 'BUS PASS', 'IDENTITY CARD',
    'SIGNATURE', 'PRINCIPAL', 'DIRECTOR', 'DEAN', 'HOD', 'ISSUING AUTHORITY',
    'VALID UPTO', 'VALID TILL', 'DOB', 'DATE OF BIRTH', 'BLOOD GROUP', 'ADDRESS',
    'EMERGENCY', 'CONTACT', 'TRANSPORT', 'HOLDER', 'STUDENT COPY'
  };

  /// Cleans raw barcode strings by stripping AIM symbology identifiers
  /// (e.g. ]C1, ]c1, ]C0, ]Q1, ]d2, ]A0, ]e0), hardware scanner prefixes (cn1, etc.),
  /// and invisible ASCII control codes (FNC1 \x1D, CR/LF, etc.).
  static String sanitizeBarcode(String? input) {
    if (input == null) return '';
    String clean = input.trim();
    // 1. Strip AIM Symbology identifier (e.g. ]C1, ]c1, ]C0, ]Q1, ]d2, ]A0, ]e0, etc.)
    clean = clean.replaceFirst(RegExp(r'^\][a-zA-Z0-9]{2}'), '');
    // 2. Strip common scanner wedge prefixes like cn1 or ]c1
    clean = clean.replaceFirst(RegExp(r'^(?:cn1|\]c1)', caseSensitive: false), '');
    // 3. Strip control characters like FNC1 separator (\x1D), nulls, tabs, newlines
    clean = clean.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    return clean.trim();
  }

  /// Main parse method that combines scanned barcode and OCR text
  static IdCardParseResult parse({
    String? barcodeValue,
    String? ocrText,
  }) {
    String detectedRoll = '';
    String detectedName = '';
    String detectedDept = '';
    String detectedYear = '1st Year';
    String detectedInst = 'Vellalar college of engineering and technology';
    String detectedPhone = '';
    String detectedParentPhone = '';
    String detectedBlood = '';

    // 1. Process Barcode Value first (if present)
    if (barcodeValue != null && barcodeValue.trim().isNotEmpty) {
      final cleanBarcode = sanitizeBarcode(barcodeValue);

      // Check if barcode is JSON (e.g. {"roll":"21CS101", "name":"Rahul", ...})
      if (cleanBarcode.startsWith('{') && cleanBarcode.endsWith('}')) {
        try {
          final dynamic parsed = jsonDecode(cleanBarcode);
          if (parsed is Map) {
            detectedRoll = (parsed['roll'] ?? parsed['rollNumber'] ?? parsed['roll_number'] ?? parsed['id'] ?? '').toString().trim();
            detectedName = (parsed['name'] ?? parsed['studentName'] ?? parsed['student_name'] ?? '').toString().trim();
            detectedDept = (parsed['dept'] ?? parsed['department'] ?? '').toString().trim();
            detectedPhone = (parsed['phone'] ?? '').toString().trim();
            detectedParentPhone = (parsed['parentPhone'] ?? parsed['parent_phone'] ?? '').toString().trim();
          }
        } catch (_) {}
      } else if (cleanBarcode.contains('|') || cleanBarcode.contains(',')) {
        // Delimited format: ROLL|NAME|DEPT
        final delimiter = cleanBarcode.contains('|') ? '|' : ',';
        final parts = cleanBarcode.split(delimiter).map((e) => e.trim()).toList();
        if (parts.isNotEmpty) detectedRoll = parts[0];
        if (parts.length > 1 && !RegExp(r'^\d+$').hasMatch(parts[1])) detectedName = parts[1];
        if (parts.length > 2) detectedDept = parts[2];
      } else {
        // Standard 1D barcode on ID card: represents the Roll Number
        detectedRoll = cleanBarcode;
      }
    }

    // 2. Process OCR text (if present)
    // 2. Process OCR text (if present)
    final text = ocrText ?? '';
    if (text.isNotEmpty) {
      final lines = text
          .split(RegExp(r'[\r\n]+'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final upperLine = line.toUpperCase();

        // 2a. Roll Number OCR (if barcode was empty or barcode didn't give roll)
        final isPostalOrAddress = _isAddressOrPostalLine(line);

        if (detectedRoll.isEmpty) {
          // Check same line label: e.g. "Roll No: 21CS101"
          final rollMatch = RegExp(
            r'(?:ROLL\s*(?:NO|NUMBER|#)?|REG(?:ISTER|ISTRATION)?\s*(?:NO|NUMBER|#)?|ADM(?:ISSION)?\s*(?:NO|NUMBER|#)?|ID\s*(?:NO|NUMBER|#)|R\.?\s*NO\.?|D\.?\s*NO\.?)\s*[:.\s-]+\s*([A-Z0-9\-/]+)',
            caseSensitive: false,
          ).firstMatch(line);

          if (rollMatch != null && rollMatch.group(1) != null) {
            final candidate = rollMatch.group(1)!.trim();
            if (candidate.length >= 3 && candidate.length <= 25 && !_isIndianPincode(candidate)) {
              detectedRoll = candidate;
            }
          } else if (i + 1 < lines.length &&
              RegExp(r'^(?:ROLL\s*(?:NO|NUMBER|#)?|REG(?:ISTER|ISTRATION)?\s*(?:NO|NUMBER|#)?|ADM(?:ISSION)?\s*(?:NO|NUMBER|#)?|ID\s*(?:NO|NUMBER|#)?|R\.?\s*NO\.?|D\.?\s*NO\.?)[:.\s-]*$', caseSensitive: false).hasMatch(line)) {
            // Label is on current line, value is on next line
            final nextCand = lines[i + 1].trim().toUpperCase();
            if (RegExp(r'^[A-Z0-9\-/]{3,25}$').hasMatch(nextCand) && !_isIndianPincode(nextCand)) {
              detectedRoll = nextCand;
            }
          } else if (!isPostalOrAddress) {
            // Anna University 10 to 12-digit registration number (e.g. 737621104001, 732921104045)
            final auRegMatch = RegExp(r'\b[1-9][0-9]{9,11}\b').firstMatch(line);
            if (auRegMatch != null) {
              detectedRoll = auRegMatch.group(0)!;
            } else {
              // Alphanumeric roll: e.g. 7376211CS101, 21CS045, 21CSR101, 23IT045, VCET2101
              final alphanumericRoll = RegExp(r'\b(?:[0-9]{2,4}[A-Z]{1,5}[0-9]{2,5}|[A-Z]{2,5}[0-9]{2,6})\b', caseSensitive: false).firstMatch(line);
              if (alphanumericRoll != null) {
                detectedRoll = alphanumericRoll.group(0)!;
              } else {
                // Standalone 4-8 digit roll numbers (e.g. 33043, 17092, 33507) avoiding standard calendar years & 6-digit pin codes
                final numericRoll = RegExp(r'\b[1-9][0-9]{3,7}\b').firstMatch(line);
                if (numericRoll != null) {
                  final numVal = numericRoll.group(0)!;
                  if (!['2020', '2021', '2022', '2023', '2024', '2025', '2026', '2027', '2028', '2029', '2030'].contains(numVal) &&
                      !_isIndianPincode(numVal)) {
                    detectedRoll = numVal;
                  }
                }
              }
            }
          }
        }

        // 2b. Name OCR
        if (detectedName.isEmpty) {
          final nameMatch = RegExp(
            r'(?:NAME|STUDENT NAME|CANDIDATE NAME)[:.\s-]*([A-Za-z\s.]+)',
            caseSensitive: false,
          ).firstMatch(line);

          if (nameMatch != null && nameMatch.group(1) != null) {
            final cand = nameMatch.group(1)!.trim();
            if (_isValidPersonName(cand)) {
              detectedName = cand;
            }
          } else if (i + 1 < lines.length &&
              RegExp(r'^(?:NAME|STUDENT NAME|CANDIDATE NAME)[:.\s-]*$', caseSensitive: false).hasMatch(line)) {
            // Label is on current line, student name is on next line
            final nextCand = lines[i + 1].trim();
            if (_isValidPersonName(nextCand)) {
              detectedName = nextCand;
            }
          }
        }

        // 2c. Department / Course OCR
        if (detectedDept.isEmpty) {
          final deptMatch = RegExp(
            r'(?:DEPT|DEPARTMENT|BRANCH|COURSE|STREAM)[:.\s-]*([A-Za-z0-9\s.&-]+)',
            caseSensitive: false,
          ).firstMatch(line);

          if (deptMatch != null && deptMatch.group(1) != null) {
            final rawDept = deptMatch.group(1)!.trim();
            final normalized = _findDeptKeyword(rawDept.toUpperCase());
            detectedDept = normalized ?? rawDept;
          } else if (i + 1 < lines.length &&
              RegExp(r'^(?:DEPT|DEPARTMENT|BRANCH|COURSE|STREAM)[:.\s-]*$', caseSensitive: false).hasMatch(line)) {
            final nextDept = lines[i + 1].trim();
            final normalized = _findDeptKeyword(nextDept.toUpperCase());
            detectedDept = normalized ?? nextDept;
          } else {
            // Check for standard department keywords
            final deptKeyword = _findDeptKeyword(upperLine);
            if (deptKeyword != null) {
              detectedDept = deptKeyword;
            }
          }
        }

        // 2d. Phone Number
        final phoneMatch = RegExp(r'\b[6-9][0-9]{9}\b').firstMatch(line);
        if (phoneMatch != null) {
          final p = phoneMatch.group(0)!;
          if (upperLine.contains('PARENT') || upperLine.contains('FATHER') || upperLine.contains('MOTHER') || upperLine.contains('GUARDIAN')) {
            detectedParentPhone = p;
          } else if (detectedPhone.isEmpty) {
            detectedPhone = p;
          }
        }

        // 2e. Blood Group
        if (detectedBlood.isEmpty) {
          final bloodMatch = RegExp(r'\b(A|B|AB|O)[+-](?:\s*VE)?', caseSensitive: false).firstMatch(line);
          if (bloodMatch != null) {
            detectedBlood = bloodMatch.group(0)!.toUpperCase().replaceAll(' ', '');
          }
        }

        // 2f. Year of Study
        if (upperLine.contains('1ST YEAR') || upperLine.contains('I YEAR') || upperLine.contains('YEAR 1') || upperLine.contains('I-YEAR')) {
          detectedYear = '1st Year';
        } else if (upperLine.contains('2ND YEAR') || upperLine.contains('II YEAR') || upperLine.contains('YEAR 2') || upperLine.contains('II-YEAR')) {
          detectedYear = '2nd Year';
        } else if (upperLine.contains('3RD YEAR') || upperLine.contains('III YEAR') || upperLine.contains('YEAR 3') || upperLine.contains('III-YEAR')) {
          detectedYear = '3rd Year';
        } else if (upperLine.contains('4TH YEAR') || upperLine.contains('IV YEAR') || upperLine.contains('YEAR 4') || upperLine.contains('IV-YEAR')) {
          detectedYear = '4th Year';
        } else if (upperLine.contains('STAFF') || upperLine.contains('FACULTY') || upperLine.contains('TEACHER')) {
          detectedYear = 'Staff';
        }

        // 2g. Institution Detection from OCR
        if (upperLine.contains('WOMEN') || upperLine.contains('VCW')) {
          detectedInst = 'Vellalar college for women';
        } else if (upperLine.contains('EDUCATION') || upperLine.contains('VCE')) {
          detectedInst = 'Vellalar college of education';
        } else if (upperLine.contains('NURSING') || upperLine.contains('VCN')) {
          detectedInst = 'Vellalar college of nursing';
        } else if (upperLine.contains('PHARM') || upperLine.contains('VCP')) {
          detectedInst = 'Vellalar college of pharmacy';
        } else if (upperLine.contains('PHYSIO') || upperLine.contains('VPC')) {
          detectedInst = 'Vellalar physiotherapy college';
        } else if (upperLine.contains('VIDYALAYA') || upperLine.contains('VVSSS') || upperLine.contains('SENIOR SECONDARY')) {
          detectedInst = 'Vellalar vidyalaya senior secondary school';
        } else if (upperLine.contains('VETIAS') || upperLine.contains('ARTS AND SCIENCE') || upperLine.contains('VET INSTITUTE')) {
          detectedInst = 'VET institute of arts and science';
        } else if (upperLine.contains('ENGINEERING') || upperLine.contains('VCET')) {
          detectedInst = 'Vellalar college of engineering and technology';
        }
      }

      // If name was still not found with a "Name:" prefix, search for the most plausible uppercase candidate name
      if (detectedName.isEmpty) {
        for (final line in lines) {
          final upper = line.toUpperCase();
          if (_isHeaderOrBlacklisted(upper)) continue;
          if (upper.contains(':') || upper.contains('=')) continue;
          // Use whole word regex to avoid falsely skipping names like MANOJ, VINOD, etc.
          if (RegExp(r'\b(?:ROLL|REG|NO|REGISTER|NUMBER|ADM)\b').hasMatch(upper)) continue;

          // Check if looks like a name (only letters and dots, 3 to 35 chars, 1 to 4 words)
          final cleanCandidate = line.trim().replaceAll(RegExp(r'[^A-Za-z\s.]'), '');
          if (cleanCandidate.length >= 3 && cleanCandidate.length <= 35) {
            final words = cleanCandidate.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
            if (words.isNotEmpty && words.length <= 4 && _isValidPersonName(cleanCandidate)) {
              detectedName = cleanCandidate;
              break;
            }
          }
        }
      }
    }

    // Default cleanups
    detectedRoll = sanitizeBarcode(detectedRoll);
    detectedRoll = detectedRoll.replaceAll(RegExp(r'[^\w\-/]'), '').toUpperCase();
    if (detectedName.isNotEmpty) {
      detectedName = detectedName.replaceAll(RegExp(r'[:\-_]'), '').trim();
    }

    // Automatically infer year of study from roll number if not explicitly staff
    if (detectedYear != 'Staff') {
      final inferredYear = inferYearOfStudyFromRoll(detectedRoll);
      if (inferredYear != null) {
        detectedYear = inferredYear;
      }
    }

    return IdCardParseResult(
      rollNumber: detectedRoll,
      name: detectedName,
      department: detectedDept.isNotEmpty ? detectedDept : 'General',
      yearOfStudy: detectedYear,
      institutionType: detectedInst,
      phone: detectedPhone,
      parentPhone: detectedParentPhone,
      bloodGroup: detectedBlood,
      rawText: text,
    );
  }

  static const Map<String, String> yearBatchMap = {
    '26': '1st Year',
    '25': '2nd Year',
    '24': '3rd Year',
    '23': '4th Year',
    '22': '4th Year',
  };

  /// Automatically infers student's year of study (1st Year, 2nd Year, 3rd Year, 4th Year)
  /// from roll number / registration number taking various prefixes into account:
  /// - 4-digit Anna Univ / College code: 737624104001, 737625104015, 737626104020, 7376-24-104-001
  /// - Full year: 2024BCSE001, 2025IT012, 2026ECE05, 2023MECH01
  /// - College / Degree prefix: VCET24CS001, VCW25MAT02, BE26EC001, VCET/24/001
  /// - Direct 2-digit batch: 24CS101, 25IT045, 26EC001, 23ME120
  /// - Delimited: 24-CS-001, 24/CS/001
  static String? inferYearOfStudyFromRoll(String? rollNumber) {
    if (rollNumber == null) return null;
    final clean = rollNumber.trim().toUpperCase().replaceAll(' ', '');
    if (clean.isEmpty) return null;

    // Filter out 10-digit mobile numbers and 6-digit Indian PIN codes
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) return null;
    if (_isIndianPincode(clean)) return null;

    // 1. Full 4-digit year pattern (e.g. 2024BCSE001, VCET2025CS01, 2026101, 2023...)
    final fullYearMatch = RegExp(r'20(2[2-6])').firstMatch(clean);
    if (fullYearMatch != null) {
      final batch = fullYearMatch.group(1);
      if (yearBatchMap.containsKey(batch)) {
        return yearBatchMap[batch];
      }
    }

    // 2. Anna University / TN College 4-digit code prefix (e.g. 737624104001, 732925104045, 7376-26-104-001)
    // Must be followed by batch year (22-26) and at least 3 digits/chars of dept & roll to avoid false matches
    final auMatch = RegExp(r'^[1-9]\d{3}[-_/]?(2[2-6])(?=[A-Z0-9]{3,})').firstMatch(clean);
    if (auMatch != null) {
      final batch = auMatch.group(1);
      if (yearBatchMap.containsKey(batch)) {
        return yearBatchMap[batch];
      }
    }

    // 3. Alphabetic / College / Degree prefix (e.g. VCET24CS001, VCW25MAT02, BE26EC01, IT2301, VCET/24/001)
    final alphaPrefixMatch = RegExp(r'^[A-Z]{1,8}[-_/]?(2[2-6])').firstMatch(clean);
    if (alphaPrefixMatch != null) {
      final batch = alphaPrefixMatch.group(1);
      if (yearBatchMap.containsKey(batch)) {
        return yearBatchMap[batch];
      }
    }

    // 4. Direct start with 2-digit batch (e.g. 24CS101, 25IT045, 26EC001, 23ME120, 24-CS-01)
    final directMatch = RegExp(r'^(2[2-6])').firstMatch(clean);
    if (directMatch != null) {
      final batch = directMatch.group(1);
      if (yearBatchMap.containsKey(batch)) {
        return yearBatchMap[batch];
      }
    }

    // 5. Delimited batch year (e.g. VCET/24/001, STU-25-01, 7376/26/01)
    final delimMatch = RegExp(r'[-_/](2[2-6])[-_/]').firstMatch(clean);
    if (delimMatch != null) {
      final batch = delimMatch.group(1);
      if (yearBatchMap.containsKey(batch)) {
        return yearBatchMap[batch];
      }
    }

    // 6. General fallback: look for (22-26) followed by letters (e.g. any prefix then 24CS...)
    final embeddedMatch = RegExp(r'(2[2-6])([A-Z]{1,5})').firstMatch(clean);
    if (embeddedMatch != null) {
      final batch = embeddedMatch.group(1);
      if (yearBatchMap.containsKey(batch)) {
        return yearBatchMap[batch];
      }
    }

    return null;
  }

  static bool _isValidPersonName(String str) {
    final upper = str.toUpperCase().trim();
    if (upper.length < 2 || upper.length > 35) return false;
    if (_isHeaderOrBlacklisted(upper)) return false;
    // Must contain letters
    if (!RegExp(r'[A-Za-z]').hasMatch(upper)) return false;
    // Should not contain digits or email or url symbols
    if (RegExp(r'[\d@/\\]').hasMatch(upper)) return false;
    return true;
  }

  static bool _isHeaderOrBlacklisted(String upper) {
    for (final b in _institutionBlacklistWords) {
      if (upper.contains(b)) return true;
    }
    for (final b in _labelBlacklistWords) {
      if (upper.contains(b)) return true;
    }
    return false;
  }

  static String? _findDeptKeyword(String upper) {
    if (upper.contains('COMPUTER SCIENCE') || upper.contains('CSE') || upper.contains('CS & E') || upper.contains('COMP. SCI')) return 'Computer Science';
    if (upper.contains('INFORMATION TECH') || RegExp(r'\bIT\b').hasMatch(upper)) return 'Information Technology';
    if (upper.contains('ARTIFICIAL INTELLIGENCE') || upper.contains('AI & DS') || upper.contains('AIDS') || upper.contains('AIML') || RegExp(r'\bAI\b').hasMatch(upper)) return 'AI & Data Science';
    if (upper.contains('ELECTRONICS & COMM') || upper.contains('ELECTRONICS AND COMM') || upper.contains('ECE') || upper.contains('E&C')) return 'Electronics & Comm';
    if (upper.contains('ELECTRICAL & ELECT') || upper.contains('ELECTRICAL AND ELECT') || upper.contains('EEE') || upper.contains('E&E')) return 'Electrical & Electronics';
    if (upper.contains('MECHANICAL') || upper.contains('MECH')) return 'Mechanical';
    if (upper.contains('CIVIL')) return 'Civil Engineering';
    if (upper.contains('BIOTECH') || upper.contains('BIO TECH')) return 'Biotechnology';
    if (upper.contains('BIOMEDICAL') || upper.contains('BIO MEDICAL')) return 'Biomedical';
    if (upper.contains('B.SC') || upper.contains('BSC')) return 'B.Sc';
    if (upper.contains('B.COM') || upper.contains('BCOM')) return 'B.Com';
    if (upper.contains('BBA') || upper.contains('MBA')) return 'Management';
    if (upper.contains('MCA')) return 'Computer Applications';
    return null;
  }

  static bool _isIndianPincode(String s) {
    final clean = s.replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^[1-8][0-9]{5}$').hasMatch(clean);
  }

  static bool _isAddressOrPostalLine(String line) {
    final upper = line.toUpperCase();
    if (RegExp(r'\b(?:PIN|PINCODE|PIN\s*CODE|P\.O|P\.B|POST|BOX)\b').hasMatch(upper)) return true;
    if (upper.contains('ERODE') ||
        upper.contains('THINDAL') ||
        upper.contains('PERUNDURAI') ||
        upper.contains('COIMBATORE') ||
        upper.contains('CHENNAI') ||
        upper.contains('SALEM') ||
        upper.contains('NAMAKKAL') ||
        upper.contains('TIRUPPUR') ||
        upper.contains('TIRUPUR') ||
        upper.contains('DHARAPURAM') ||
        upper.contains('TAMIL NADU') ||
        upper.contains('TAMILNADU') ||
        upper.contains('INDIA')) {
      return true;
    }
    if (upper.contains('ROAD') ||
        upper.contains('STREET') ||
        upper.contains('NAGAR') ||
        upper.contains('TALUK') ||
        upper.contains('DIST') ||
        upper.contains('DISTRICT') ||
        upper.contains('CAMPUS') ||
        upper.contains('AFFILIATED') ||
        upper.contains('AUTONOMOUS') ||
        upper.contains('ACCREDITED') ||
        upper.contains('GOVERNMENT') ||
        upper.contains('PH:') ||
        upper.contains('FAX') ||
        upper.contains('WWW.') ||
        upper.contains('HTTP') ||
        upper.contains('.EDU') ||
        upper.contains('.COM') ||
        upper.contains('.AC.IN')) {
      return true;
    }
    return false;
  }
}
