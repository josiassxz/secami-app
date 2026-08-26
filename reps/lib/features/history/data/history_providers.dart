import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../data/local/database.dart';
import '../../auth/data/auth_providers.dart';

final sessionsStreamProvider = StreamProvider<List<WorkoutSessionRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final userId = ref.watch(effectiveUserIdProvider);
  return db.sessionDao.watchByUser(userId);
});

final sessionByIdProvider = FutureProvider.autoDispose
    .family<WorkoutSessionRow?, String>((ref, id) {
      return ref.watch(appDatabaseProvider).sessionDao.findById(id);
    });

final setLogsOfSessionProvider = StreamProvider.autoDispose
    .family<List<SetLogRow>, String>((ref, sessionId) {
      return ref.watch(appDatabaseProvider).setLogDao.watchOfSession(sessionId);
    });

final setLogsOfExerciseProvider = FutureProvider.autoDispose
    .family<List<SetLogRow>, String>((ref, exerciseId) {
      return ref.watch(appDatabaseProvider).setLogDao.ofExercise(exerciseId);
    });
