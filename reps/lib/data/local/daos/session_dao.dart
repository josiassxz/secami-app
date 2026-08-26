import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sessions_table.dart';

part 'session_dao.g.dart';

@DriftAccessor(tables: [WorkoutSessions])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(super.db);

  Stream<List<WorkoutSessionRow>> watchByUser(String userId) {
    return (select(workoutSessions)
          ..where((s) => s.userId.equals(userId) & s.deletedAt.isNull())
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.iniciadoEm, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<WorkoutSessionRow?> findActive(String userId) {
    return (select(workoutSessions)
          ..where(
            (s) =>
                s.userId.equals(userId) &
                s.finalizadoEm.isNull() &
                s.deletedAt.isNull(),
          )
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.iniciadoEm, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<WorkoutSessionRow?> findById(String id) {
    return (select(
      workoutSessions,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(
    WorkoutSessionsCompanion data, {
    bool markDirty = true,
  }) async {
    final c = markDirty
        ? data.copyWith(
            dirty: const Value(true),
            updatedAt: Value(DateTime.now().toUtc()),
          )
        : data;
    await into(workoutSessions).insertOnConflictUpdate(c);
  }

  Future<void> finalize({
    required String id,
    required DateTime finalizadoEm,
    required int duracaoSegundos,
  }) async {
    await (update(workoutSessions)..where((s) => s.id.equals(id))).write(
      WorkoutSessionsCompanion(
        finalizadoEm: Value(finalizadoEm),
        duracaoTotalSegundos: Value(duracaoSegundos),
        updatedAt: Value(DateTime.now().toUtc()),
        dirty: const Value(true),
      ),
    );
  }

  Future<List<WorkoutSessionRow>> dirty() {
    return (select(workoutSessions)..where((s) => s.dirty.equals(true))).get();
  }

  Future<void> markClean(String id) async {
    await (update(workoutSessions)..where((s) => s.id.equals(id))).write(
      const WorkoutSessionsCompanion(dirty: Value(false)),
    );
  }

  /// markClean em lote (push em batch — evita N+1).
  Future<void> markCleanAll(List<String> ids) async {
    if (ids.isEmpty) return;
    await (update(workoutSessions)..where((s) => s.id.isIn(ids))).write(
      const WorkoutSessionsCompanion(dirty: Value(false)),
    );
  }
}
