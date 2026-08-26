import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/custom_exercises_table.dart';

part 'custom_exercise_dao.g.dart';

@DriftAccessor(tables: [CustomExercises])
class CustomExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$CustomExerciseDaoMixin {
  CustomExerciseDao(super.db);

  Stream<List<CustomExerciseRow>> watchAll() =>
      (select(customExercises)
            ..where((t) => t.arquivado.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.criadoEm)]))
          .watch();

  Future<void> upsert(CustomExercisesCompanion entry) =>
      into(customExercises).insertOnConflictUpdate(entry);

  Future<void> archive(String id) =>
      (update(customExercises)..where((t) => t.id.equals(id))).write(
        const CustomExercisesCompanion(arquivado: Value(true)),
      );
}
