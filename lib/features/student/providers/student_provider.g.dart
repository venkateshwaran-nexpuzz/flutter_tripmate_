// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$studentProfileHash() => r'student_profile_provider_hash';

/// See also [studentProfile].
@ProviderFor(studentProfile)
final studentProfileProvider =
    AutoDisposeFutureProvider<Map<String, dynamic>>.internal(
  studentProfile,
  name: r'studentProfileProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$studentProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef StudentProfileRef = AutoDisposeFutureProviderRef<Map<String, dynamic>>;

// ---

String _$studentTodayAttendanceHash() =>
    r'student_today_attendance_provider_hash';

/// See also [studentTodayAttendance].
@ProviderFor(studentTodayAttendance)
final studentTodayAttendanceProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
  studentTodayAttendance,
  name: r'studentTodayAttendanceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$studentTodayAttendanceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef StudentTodayAttendanceRef =
    AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;

// ---

String _$studentAttendanceStatsHash() =>
    r'student_attendance_stats_provider_hash';

/// See also [studentAttendanceStats].
@ProviderFor(studentAttendanceStats)
final studentAttendanceStatsProvider =
    AutoDisposeFutureProvider<Map<String, dynamic>>.internal(
  studentAttendanceStats,
  name: r'studentAttendanceStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$studentAttendanceStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef StudentAttendanceStatsRef =
    AutoDisposeFutureProviderRef<Map<String, dynamic>>;

// ---

String _$studentHistoryStateHash() => r'student_history_state_provider_hash';

/// See also [StudentHistoryState].
@ProviderFor(StudentHistoryState)
const studentHistoryStateProvider = StudentHistoryStateFamily();

class StudentHistoryStateFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  const StudentHistoryStateFamily();

  StudentHistoryStateProvider call({
    String? startDate,
    String? endDate,
    String? status,
    String? attendanceType,
  }) {
    return StudentHistoryStateProvider(
      startDate: startDate,
      endDate: endDate,
      status: status,
      attendanceType: attendanceType,
    );
  }

  @override
  AutoDisposeAsyncNotifierProvider<StudentHistoryState,
      List<Map<String, dynamic>>> getProviderOverride(
    covariant StudentHistoryStateProvider provider,
  ) {
    return call(
      startDate: provider.startDate,
      endDate: provider.endDate,
      status: provider.status,
      attendanceType: provider.attendanceType,
    );
  }

  @override
  List<ProviderOrFamily>? get allTransitiveDependencies => null;

  @override
  List<ProviderOrFamily>? get dependencies => null;

  @override
  String? get name => r'studentHistoryStateProvider';
}

class StudentHistoryStateProvider extends AutoDisposeAsyncNotifierProvider<
    StudentHistoryState, List<Map<String, dynamic>>> {
  StudentHistoryStateProvider({
    this.startDate,
    this.endDate,
    this.status,
    this.attendanceType,
  }) : super.internal(
          () => StudentHistoryState()
            .._startDate = startDate
            .._endDate = endDate
            .._status = status
            .._attendanceType = attendanceType,
          from: studentHistoryStateProvider,
          name: r'studentHistoryStateProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$studentHistoryStateHash,
          dependencies: null,
          allTransitiveDependencies: null,
        );

  final String? startDate;
  final String? endDate;
  final String? status;
  final String? attendanceType;

  @override
  bool operator ==(Object other) {
    return other is StudentHistoryStateProvider &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.status == status &&
        other.attendanceType == attendanceType;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, startDate.hashCode);
    hash = _SystemHash.combine(hash, endDate.hashCode);
    hash = _SystemHash.combine(hash, status.hashCode);
    hash = _SystemHash.combine(hash, attendanceType.hashCode);
    return _SystemHash.finish(hash);
  }
}

typedef _$StudentHistoryState
    = AutoDisposeAsyncNotifier<List<Map<String, dynamic>>>;

// ---

String _$studentNotificationsHash() =>
    r'student_notifications_provider_hash';

/// See also [studentNotifications].
@ProviderFor(studentNotifications)
final studentNotificationsProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
  studentNotifications,
  name: r'studentNotificationsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$studentNotificationsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef StudentNotificationsRef =
    AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;

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
