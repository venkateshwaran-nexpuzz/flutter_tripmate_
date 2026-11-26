// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incharge_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$inchargeAssignmentHash() => r'incharge_assignment_provider_hash';

/// See also [inchargeAssignment].
@ProviderFor(inchargeAssignment)
final inchargeAssignmentProvider =
    AutoDisposeFutureProvider<Map<String, dynamic>>.internal(
  inchargeAssignment,
  name: r'inchargeAssignmentProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$inchargeAssignmentHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef InchargeAssignmentRef =
    AutoDisposeFutureProviderRef<Map<String, dynamic>>;

// ---

String _$sessionAttendanceHash() => r'session_attendance_provider_hash';

/// See also [sessionAttendance].
@ProviderFor(sessionAttendance)
const sessionAttendanceProvider = SessionAttendanceFamily();

class SessionAttendanceFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  const SessionAttendanceFamily();

  SessionAttendanceProvider call(String sessionId) {
    return SessionAttendanceProvider(sessionId);
  }

  @override
  AutoDisposeFutureProvider<List<Map<String, dynamic>>> getProviderOverride(
    covariant SessionAttendanceProvider provider,
  ) {
    return call(provider.sessionId);
  }

  @override
  List<ProviderOrFamily>? get allTransitiveDependencies => null;

  @override
  List<ProviderOrFamily>? get dependencies => null;

  @override
  String? get name => r'sessionAttendanceProvider';
}

class SessionAttendanceProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  SessionAttendanceProvider(this.sessionId)
      : super.internal(
          (ref) => sessionAttendance(ref as SessionAttendanceRef, sessionId),
          from: sessionAttendanceProvider,
          name: r'sessionAttendanceProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$sessionAttendanceHash,
          dependencies: null,
          allTransitiveDependencies: null,
        );

  final String sessionId;

  @override
  bool operator ==(Object other) {
    return other is SessionAttendanceProvider && other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionId.hashCode);
    return _SystemHash.finish(hash);
  }
}

typedef SessionAttendanceRef =
    AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;

// ---

String _$activeTripStateHash() => r'active_trip_state_provider_hash';

/// See also [ActiveTripState].
@ProviderFor(ActiveTripState)
final activeTripStateProvider =
    AutoDisposeNotifierProvider<ActiveTripState, Map<String, dynamic>?>.internal(
  ActiveTripState.new,
  name: r'activeTripStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeTripStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ActiveTripState = AutoDisposeNotifier<Map<String, dynamic>?>;

// ---

String _$activeSessionStateHash() => r'active_session_state_provider_hash';

/// See also [ActiveSessionState].
@ProviderFor(ActiveSessionState)
final activeSessionStateProvider = AutoDisposeNotifierProvider<
    ActiveSessionState, Map<String, dynamic>?>.internal(
  ActiveSessionState.new,
  name: r'activeSessionStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeSessionStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ActiveSessionState = AutoDisposeNotifier<Map<String, dynamic>?>;

// ---

String _$attendanceMarkingStateHash() =>
    r'attendance_marking_state_provider_hash';

/// See also [AttendanceMarkingState].
@ProviderFor(AttendanceMarkingState)
final attendanceMarkingStateProvider = AutoDisposeNotifierProvider<
    AttendanceMarkingState, AsyncValue<Map<String, dynamic>?>>.internal(
  AttendanceMarkingState.new,
  name: r'attendanceMarkingStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$attendanceMarkingStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AttendanceMarkingState
    = AutoDisposeNotifier<AsyncValue<Map<String, dynamic>?>>;

// ---

class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    hash = 0x1fffffff & (hash + value);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}
