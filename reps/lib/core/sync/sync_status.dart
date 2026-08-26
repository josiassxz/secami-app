import 'package:flutter/foundation.dart';

enum SyncPhase { idle, pushing, pulling, error }

@immutable
class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.lastSuccessAt,
    this.lastError,
    this.pendingPush = 0,
  });

  final SyncPhase phase;
  final DateTime? lastSuccessAt;
  final String? lastError;
  final int pendingPush;

  bool get isRunning =>
      phase == SyncPhase.pushing || phase == SyncPhase.pulling;

  SyncStatus copyWith({
    SyncPhase? phase,
    DateTime? lastSuccessAt,
    String? lastError,
    int? pendingPush,
    bool clearError = false,
  }) {
    return SyncStatus(
      phase: phase ?? this.phase,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      pendingPush: pendingPush ?? this.pendingPush,
    );
  }
}
