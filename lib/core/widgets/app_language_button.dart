import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/driver/providers/driver_language_provider.dart';
import '../../features/driver/widgets/driver_language_selector_sheet.dart';

/// Clean, compact Google Translate Language Switcher Pill
/// Designed to fit seamlessly in AppBars without horizontal collisions or overlapping.
class AppLanguageButton extends ConsumerWidget {
  final bool compact;
  final Color? backgroundColor;
  final Color? borderColor;

  const AppLanguageButton({
    super.key,
    this.compact = false,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeLang = ref.watch(driverLanguageProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showDriverLanguageSelector(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 30,
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 2),
          decoration: BoxDecoration(
            color: backgroundColor ?? const Color(0xFFEFF6FF),
            border: Border.all(
              color: borderColor ?? const Color(0xFFBFDBFE),
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.translate_rounded,
                color: Color(0xFF1D4ED8),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                activeLang.nativeName,
                style: const TextStyle(
                  color: Color(0xFF1E40AF),
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 1),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF1D4ED8),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
