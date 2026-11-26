import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/db/local_database.dart';
import 'core/router/app_router.dart';
import 'core/services/voice_service.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting symbols for intl
  await initializeDateFormatting();

  // Show actual errors in release mode instead of grey screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              const Text('Something went wrong', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Initialize local SQLite database
  await LocalDatabase.instance.init();

  // Initialize Text-To-Speech engine in background
  VoiceService.instance.init();

  runApp(
    const ProviderScope(
      child: TripMateApp(),
    ),
  );
}

class TripMateApp extends ConsumerWidget {
  const TripMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Start sync service listener
    ref.watch(syncServiceProvider);

    return MaterialApp.router(
      title: 'VET TripMate',
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        return GlobalLoadingOverlay(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
