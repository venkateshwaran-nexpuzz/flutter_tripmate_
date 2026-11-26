import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../theme/app_theme.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/admin/ui/admin_dashboard_screen.dart';
import '../../features/admin/ui/admin_profile_screen.dart';
import '../../features/admin/ui/bus_student_scanner_screen.dart';
import '../../features/incharge/ui/incharge_dashboard_screen.dart';
import '../../features/incharge/ui/incharge_profile_screen.dart';
import '../../features/incharge/ui/attendance_session_screen.dart';
import '../../features/incharge/ui/qr_scanner_screen.dart';
import '../../features/incharge/ui/manual_entry_screen.dart';
import '../../features/incharge/ui/student_crud_screen.dart';
import '../../features/incharge/ui/incharge_trip_history_screen.dart';
import '../../features/student/ui/student_home_screen.dart';
import '../../features/student/ui/student_profile_screen.dart';
import '../../features/student/ui/student_bus_tracking_screen.dart';
import '../../features/student/ui/student_qr_scan_screen.dart';
import '../../features/student/ui/attendance_history_screen.dart';
import '../../features/student/ui/attendance_stats_screen.dart';
import '../../features/driver/ui/driver_dashboard_screen.dart';
import '../../features/driver/ui/trip_log_screen.dart';
import '../../features/driver/ui/day_report_screen.dart';
import '../../features/driver/ui/driver_history_screen.dart';
import '../../features/supervisor/ui/supervisor_dashboard_screen.dart';
import '../../features/supervisor/ui/create_maintenance_ticket_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoginPage = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) {
        final role = authState.value?.role;
        if (role == 'admin') return '/admin';
        if (role == 'supervisor' || role == 'bus_supervisor') return '/supervisor';
        if (role == 'driver') return '/driver';
        return role == 'incharge' ? '/incharge' : '/student';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Admin routes
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => const AdminProfileScreen(),
          ),
          GoRoute(
            path: 'bus-student-scanner',
            builder: (context, state) {
              final busId = state.uri.queryParameters['busId'] ?? (state.extra as Map<String, dynamic>?)?['busId']?.toString();
              return BusStudentScannerScreen(initialBusId: busId);
            },
          ),
        ],
      ),

      // Incharge routes
      GoRoute(
        path: '/incharge',
        builder: (context, state) => const InchargeDashboardScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => const InchargeProfileScreen(),
          ),
          GoRoute(
            path: 'students',
            builder: (context, state) => const StudentCrudScreen(),
          ),
          GoRoute(
            path: 'trips',
            builder: (context, state) => const InchargeTripHistoryScreen(),
          ),
          GoRoute(
            path: 'session/:sessionId',
            builder: (context, state) => AttendanceSessionScreen(
              sessionId: state.pathParameters['sessionId']!,
              extra: state.extra as Map<String, dynamic>?,
            ),
            routes: [
              GoRoute(
                path: 'qr',
                builder: (context, state) => QRScannerScreen(
                  sessionId: state.pathParameters['sessionId']!,
                  extra: state.extra as Map<String, dynamic>?,
                ),
              ),
              GoRoute(
                path: 'manual',
                builder: (context, state) => ManualEntryScreen(
                  sessionId: state.pathParameters['sessionId']!,
                  extra: state.extra as Map<String, dynamic>?,
                ),
              ),
            ],
          ),
        ],
      ),

      // Student routes
      GoRoute(
        path: '/student',
        builder: (context, state) => const StudentHomeScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => const StudentProfileScreen(),
          ),
          GoRoute(
            path: 'scan',
            builder: (context, state) => const StudentQRScanScreen(),
          ),
          GoRoute(
            path: 'history',
            builder: (context, state) => const AttendanceHistoryScreen(),
          ),
          GoRoute(
            path: 'stats',
            builder: (context, state) => const AttendanceStatsScreen(),
          ),
          GoRoute(
            path: 'track-bus',
            builder: (context, state) => const StudentBusTrackingScreen(),
          ),
        ],
      ),

      // Driver routes
      GoRoute(
        path: '/driver',
        builder: (context, state) => const DriverDashboardScreen(),
        routes: [
          GoRoute(
            path: 'trip-log',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return TripLogScreen(
                trip: extra?['trip'] as Map<String, dynamic>?,
                mode: (extra?['mode'] as String?) ?? 'start',
              );
            },
          ),
          GoRoute(
            path: 'day-report',
            builder: (context, state) => const DayReportScreen(),
          ),
          GoRoute(
            path: 'history',
            builder: (context, state) => const DriverHistoryScreen(),
          ),
        ],
      ),

      // Supervisor routes
      GoRoute(
        path: '/supervisor',
        builder: (context, state) => const SupervisorDashboardScreen(),
        routes: [
          GoRoute(
            path: 'ticket/new',
            builder: (context, state) {
              final bus = (state.extra as Map<String, dynamic>?) ?? {};
              return CreateMaintenanceTicketScreen(bus: bus);
            },
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bus_filled_outlined, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text('Page not found: ${state.matchedLocation}'),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
