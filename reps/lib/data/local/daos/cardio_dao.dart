import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sessions_table.dart';

part 'cardio_dao.g.dart';

@DriftAccessor(tables: [CardioSessions])
class CardioDao extends DatabaseAccessor<AppDatabase> with _$CardioDaoMixin {
  CardioDao(super.db);

  Stream<List<CardioSessionRow>> watchByUser(String userId) {
    return (select(cardioSessions)
          ..where((c) => c.userId.equals(userId) & c.deletedAt.isNull())
          ..orderBy([
            (c) => OrderingTerm(
              expression: c.executadoEm,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Future<void> upsert(
    CardioSessionsCompanion data, {
    bool markDirty = true,
  }) async {
    final c = markDirty
        ? data.copyWith(
            dirty: const Value(true),
            updatedAt: Value(DateTime.now().toUtc()),
          )
        : data;
    await into(cardioSessions).insertOnConflictUpdate(c);
  }

  Future<void> softDelete(String id) async {
    await (update(cardioSessions)..where((c) => c.id.equals(id))).write(
      CardioSessionsCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
        dirty: const Value(true),
      ),
    );
  }

  Future<List<CardioSessionRow>> dirty() {
    return (select(cardioSessions)..where((c) => c.dirty.equals(true))).get();
  }

  Future<void> markClean(String id) async {
    await (update(cardioSessions)..where((c) => c.id.equals(id))).write(
      const CardioSessionsCompanion(dirty: Value(false)),
    );
  }

  /// markClean em lote (push em batch — evita N+1).
  Future<void> markCleanAll(List<String> ids) async {
    if (ids.isEmpty) return;
    await (update(cardioSessions)..where((c) => c.id.isIn(ids))).write(
      const CardioSessionsCompanion(dirty: Value(false)),
    );
  }
}
