import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand White & Royal Blue Colors
  static const Color primary = Color(0xFF1E40AF);       // Deep Royal Blue
  static const Color primaryAccent = Color(0xFF2563EB); // Vibrant Royal Blue
  static const Color primaryDark = Color(0xFF172554);   // Midnight Navy
  static const Color primaryLight = Color(0xFFEFF6FF);  // Very Light Ice Blue
  static const Color primarySubtle = Color(0xFFDBEAFE); // Soft Sky Tint
  static const Color secondary = Color(0xFF0284C7);     // Modern Cyan/Sky Blue

  static const Color success = Color(0xFF059669);       // Emerald Green
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFD97706);       // Amber
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFDC2626);        // Coral Red
  static const Color dangerLight = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF0284C7);          // Ocean Blue
  static const Color infoLight = Color(0xFFF0F9FF);

  // Background & Surface
  static const Color bgLight = Color(0xFFF8FAFC);       // Ultra clean off-white
  static const Color surface = Color(0xFFFFFFFF);       // Crisp White Card
  static const Color surface2 = Color(0xFFF1F5F9);      // Light Slate Gray
  static const Color surface3 = Color(0xFFE2E8F0);      // Border & Separator
  static const Color border = Color(0xFFE2E8F0);        // Light Slate Border
  static const Color borderSubtle = Color(0xFFF1F5F9);

  // Typography Colors
  static const Color textPrimary = Color(0xFF0F172A);   // Deep Navy Slate
  static const Color textSecondary = Color(0xFF475569); // Slate Gray
  static const Color textMuted = Color(0xFF64748B);     // Cool Muted Gray

  // Dark fallback
  static const Color bgDark = Color(0xFF0F172A);

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: primaryAccent,
        secondary: secondary,
        surface: surface,
        error: danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: bgLight,
      cardColor: surface,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
        actionsIconTheme: const IconThemeData(color: textPrimary),
      ),

      // Text
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: primaryAccent.withOpacity(0.3),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAccent,
          side: const BorderSide(color: border, width: 1.5),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryAccent,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Card
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: surface2,
        selectedColor: primarySubtle,
        labelStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: border),
      ),

      // NavigationBar (M3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.06),
        indicatorColor: primarySubtle,
        labelTextStyle: MaterialStateProperty.all(
          GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(color: border, thickness: 1),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
    );
  }

  static ThemeData dark() => light(); // Keep unified clean light theme
}

// ============================================================
// Reusable VET Brand Badge Logo Widget
// ============================================================

class VetBrandLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool compact;
  final bool showSubtitle;

  const VetBrandLogo({
    super.key,
    this.size = 54,
    this.showText = true,
    this.compact = false,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // VET Crest Badge
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E40AF), Color(0xFF2563EB), Color(0xFF0284C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E40AF).withOpacity(0.3),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle background bus watermark
              Positioned(
                bottom: 2,
                right: 2,
                child: Icon(
                  Icons.directions_bus_rounded,
                  size: size * 0.45,
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
              // VET Text Crest
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'VET',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: size * 0.38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      height: 1.0,
                    ),
                  ),
                  Container(
                    width: size * 0.5,
                    height: 2,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (showText) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'VET ',
                      style: TextStyle(
                        fontSize: compact ? 15 : 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'TRIPMATE',
                      style: TextStyle(
                        fontSize: compact ? 15 : 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                if (showSubtitle && !compact)
                  Text(
                    'Velalar Bus Transit & Attendance',
                    style: TextStyle(
                      fontSize: compact ? 9 : 12,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// Reusable Visual Feature Icon Badge
// ============================================================

class FeatureIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  const FeatureIconBadge({
    super.key,
    required this.icon,
    this.color = AppTheme.primaryAccent,
    this.size = 44,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
      ),
      child: Center(
        child: Icon(icon, color: color, size: iconSize ?? (size * 0.52)),
      ),
    );
  }
}

// ============================================================
// Reusable Theme & Responsive Extensions
// ============================================================

extension AppColors on BuildContext {
  Color get primaryColor => AppTheme.primary;
  Color get primaryAccentColor => AppTheme.primaryAccent;
  Color get successColor => AppTheme.success;
  Color get dangerColor => AppTheme.danger;
  Color get warningColor => AppTheme.warning;
  Color get surfaceColor => AppTheme.surface;
  Color get surface2Color => AppTheme.surface2;
  Color get textPrimaryColor => AppTheme.textPrimary;
  Color get textSecondaryColor => AppTheme.textSecondary;
  Color get textMutedColor => AppTheme.textMuted;
  Color get borderColor => AppTheme.border;

  bool get isSmallPhone => screenWidth < 360;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;
  bool get isDesktop => screenWidth >= 1024;
  bool get isLandscape => MediaQuery.of(this).orientation == Orientation.landscape;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  double get textScale => MediaQuery.textScalerOf(this).scale(1.0);
  EdgeInsets get responsiveScreenPadding => EdgeInsets.all(isSmallPhone ? 12.0 : 16.0);
}

// ============================================================
// Modern Floating SnackBar Helper
// ============================================================

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class AppSnackBar {
  static ScaffoldMessengerState? _getMessenger(BuildContext? context) {
    if (rootScaffoldMessengerKey.currentState != null) {
      return rootScaffoldMessengerKey.currentState;
    }
    if (context != null) {
      return ScaffoldMessenger.maybeOf(context);
    }
    return null;
  }

  static void showSuccess(BuildContext? context, String message) {
    final messenger = _getMessenger(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showError(BuildContext? context, String message) {
    final messenger = _getMessenger(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void showInfo(BuildContext? context, String message) {
    final messenger = _getMessenger(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showWarning(BuildContext? context, String message) {
    final messenger = _getMessenger(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
