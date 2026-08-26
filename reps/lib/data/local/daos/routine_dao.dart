import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/routines_table.dart';

part 'routine_dao.g.dart';

@DriftAccessor(tables: [Routines, RoutineExercises])
class RoutineDao extends DatabaseAccessor<AppDatabase> with _$RoutineDaoMixin {
  RoutineDao(super.db);

  Stream<List<RoutineRow>> watchAtivas(String userId) {
    return (select(routines)
          ..where(
            (r) =>
                r.userId.equals(userId) &
                r.deletedAt.isNull() &
                r.ativo.equals(true),
          )
          ..orderBy([(r) => OrderingTerm(expression: r.ordem)]))
        .watch();
  }

  Future<List<RoutineRow>> listAtivas(String userId) {
    return (select(routines)
          ..where(
            (r) =>
                r.userId.equals(userId) &
                r.deletedAt.isNull() &
                r.ativo.equals(true),
          )
          ..orderBy([(r) => OrderingTerm(expression: r.ordem)]))
        .get();
  }

  Future<RoutineRow?> findById(String id) {
    return (select(routines)..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  Stream<RoutineRow?> watchById(String id) {
    return (select(routines)
          ..where((r) => r.id.equals(id) & r.deletedAt.isNull())
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> upsert(RoutinesCompanion data, {bool markDirty = true}) async {
    final companion = markDirty
        ? data.copyWith(
            dirty: const Value(true),
            updatedAt: Value(DateTime.now().toUtc()),
          )
        : data;
    await into(routines).insertOnConflictUpdate(companion);
  }

  Future<void> softDelete(String id) async {
    await (update(routines)..where((r) => r.id.equals(id))).write(
      RoutinesCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
        dirty: const Value(true),
      ),
    );
  }

  // ===== routine_exercises =====
  Future<List<RoutineExerciseRow>> exercisesOf(String routineId) {
    return (select(routineExercises)
          ..where(
            (re) => re.routineId.equals(routineId) & re.deletedAt.isNull(),
          )
          ..orderBy([(re) => OrderingTerm(expression: re.ordem)]))
        .get();
  }

  Stream<List<RoutineExerciseRow>> watchExercisesOf(String routineId) {
    return (select(routineExercises)
          ..where(
            (re) => re.routineId.equals(routineId) & re.deletedAt.isNull(),
          )
          ..orderBy([(re) => OrderingTerm(expression: re.ordem)]))
        .watch();
  }

  Future<void> upsertExercise(
    RoutineExercisesCompanion data, {
    bool markDirty = true,
  }) async {
    final c = markDirty
        ? data.copyWith(
            dirty: const Value(true),
            updatedAt: Value(DateTime.now().toUtc()),
          )
        : data;
    await into(routineExercises).insertOnConflictUpdate(c);
  }

  /// UPDATE parcial de uma routine_exercise existente: grava só os campos
  /// presentes em [data]. Ao contrario de [upsertExercise]
  /// (insertOnConflictUpdate), NAO exige as colunas obrigatorias
  /// (routine_id/exercise_id) — usado para editar series e agrupar
  /// bi-set/circuito sem precisar reescrever a linha inteira.
  Future<void> updateExercise(
    String id,
    RoutineExercisesCompanion data, {
    bool markDirty = true,
  }) async {
    final c = markDirty
        ? data.copyWith(
            dirty: const Value(true),
            updatedAt: Value(DateTime.now().toUtc()),
          )
        : data;
    await (update(routineExercises)..where((re) => re.id.equals(id))).write(c);
  }

  Future<void> softDeleteExercise(String id) async {
    await (update(routineExercises)..where((re) => re.id.equals(id))).write(
      RoutineExercisesCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> reorderExercises(
    String routineId,
    List<String> orderedIds,
  ) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(
          routineExercises,
        )..where((re) => re.id.equals(orderedIds[i]))).write(
          RoutineExercisesCompanion(
            ordem: Value(i),
            updatedAt: Value(DateTime.now().toUtc()),
            dirty: const Value(true),
          ),
        );
      }
    });
  }

  // ===== sync helpers =====
  Future<List<RoutineRow>> dirtyRoutines() {
    return (select(routines)..where((r) => r.dirty.equals(true))).get();
  }

  Future<List<RoutineExerciseRow>> dirtyExercises() {
    return (select(
      routineExercises,
    )..where((re) => re.dirty.equals(true))).get();
  }

  Future<void> markRoutineClean(String id) async {
    await (update(routines)..where((r) => r.id.equals(id))).write(
      const RoutinesCompanion(dirty: Value(false)),
    );
  }

  Future<void> markExerciseClean(String id) async {
    await (update(routineExercises)..where((re) => re.id.equals(id))).write(
      const RoutineExercisesCompanion(dirty: Value(false)),
    );
  }

  /// markClean em lote (push em batch — evita N+1).
  Future<void> markRoutinesClean(List<String> ids) async {
    if (ids.isEmpty) return;
    await (update(routines)..where((r) => r.id.isIn(ids))).write(
      const RoutinesCompanion(dirty: Value(false)),
    );
  }

  Future<void> markExercisesClean(List<String> ids) async {
    if (ids.isEmpty) return;
    await (update(routineExercises)..where((re) => re.id.isIn(ids))).write(
      const RoutineExercisesCompanion(dirty: Value(false)),
    );
  }
}
