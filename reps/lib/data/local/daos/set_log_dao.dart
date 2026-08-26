import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sessions_table.dart';

part 'set_log_dao.g.dart';

@DriftAccessor(tables: [SetLogs])
class SetLogDao extends DatabaseAccessor<AppDatabase> with _$SetLogDaoMixin {
  SetLogDao(super.db);

  Stream<List<SetLogRow>> watchOfSession(String sessionId) {
    return (select(setLogs)
          ..where((s) => s.sessionId.equals(sessionId) & s.deletedAt.isNull())
          ..orderBy([
            (s) => OrderingTerm(expression: s.ordemNoTreino),
            (s) => OrderingTerm(expression: s.numeroSerie),
          ]))
        .watch();
  }

  Future<List<SetLogRow>> ofSession(String sessionId) {
    return (select(setLogs)
          ..where((s) => s.sessionId.equals(sessionId) & s.deletedAt.isNull())
          ..orderBy([
            (s) => OrderingTerm(expression: s.ordemNoTreino),
            (s) => OrderingTerm(expression: s.numeroSerie),
          ]))
        .get();
  }

  Future<List<SetLogRow>> ofExercise(String exerciseId, {int limit = 200}) {
    return (select(setLogs)
          ..where(
            (s) =>
                s.exerciseId.equals(exerciseId) &
                s.deletedAt.isNull() &
                s.executada.equals(true),
          )
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.criadoEm, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
  }

  Future<void> upsert(SetLogsCompanion data, {bool markDirty = true}) async {
    final c = markDirty
        ? data.copyWith(
            dirty: const Value(true),
            updatedAt: Value(DateTime.now().toUtc()),
          )
        : data;
    await into(setLogs).insertOnConflictUpdate(c);
  }

  Future<void> softDelete(String id) async {
    await (update(setLogs)..where((s) => s.id.equals(id))).write(
      SetLogsCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
        dirty: const Value(true),
      ),
    );
  }

  Future<List<SetLogRow>> dirty() {
    return (select(setLogs)..where((s) => s.dirty.equals(true))).get();
  }

  Future<void> markClean(String id) async {
    await (update(setLogs)..where((s) => s.id.equals(id))).write(
      const SetLogsCompanion(dirty: Value(false)),
    );
  }

  /// Busca todos os set_logs de um conjunto de sessoes numa unica query
  /// (evita N+1: antes era 1 query por sessao — ver records/weekly volume).
  Future<List<SetLogRow>> ofSessions(List<String> sessionIds) {
    if (sessionIds.isEmpty) return Future.value(const []);
    return (select(setLogs)
          ..where((s) => s.sessionId.isIn(sessionIds) & s.deletedAt.isNull())
          ..orderBy([
            (s) => OrderingTerm(expression: s.ordemNoTreino),
            (s) => OrderingTerm(expression: s.numeroSerie),
          ]))
        .get();
  }

  /// markClean em lote (push em batch — evita N+1).
  Future<void> markCleanAll(List<String> ids) async {
    if (ids.isEmpty) return;
    await (update(setLogs)..where((s) => s.id.isIn(ids))).write(
      const SetLogsCompanion(dirty: Value(false)),
    );
  }
}
