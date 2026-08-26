import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/recommender_runs_table.dart';

part 'recommender_run_dao.g.dart';

@DriftAccessor(tables: [RecommenderRuns])
class RecommenderRunDao extends DatabaseAccessor<AppDatabase>
    with _$RecommenderRunDaoMixin {
  RecommenderRunDao(super.db);

  Future<void> insert(RecommenderRunsCompanion entry) =>
      into(recommenderRuns).insert(entry);

  Stream<List<RecommenderRunRow>> watchAll(String userId) =>
      (select(recommenderRuns)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.criadoEm)]))
          .watch();

  /// Registros que podem subir: do usuario, com consentimento de sync
  /// (`sincronizavel`) e ainda nao enviados (RN-051).
  Future<List<RecommenderRunRow>> pendentesSync(String userId) =>
      (select(recommenderRuns)..where(
            (t) =>
                t.userId.equals(userId) &
                t.sincronizavel.equals(true) &
                t.sincronizado.equals(false),
          ))
          .get();

  Future<void> marcarSincronizado(String id) =>
      (update(recommenderRuns)..where((t) => t.id.equals(id))).write(
        const RecommenderRunsCompanion(sincronizado: Value(true)),
      );

  /// Marca varios runs como sincronizados numa unica query (batch — evita N+1).
  Future<void> marcarSincronizadoAll(List<String> ids) async {
    if (ids.isEmpty) return;
    await (update(recommenderRuns)..where((t) => t.id.isIn(ids))).write(
      const RecommenderRunsCompanion(sincronizado: Value(true)),
    );
  }
}
