import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sessions_table.dart';

part 'sync_state_dao.g.dart';

@DriftAccessor(tables: [SyncState])
class SyncStateDao extends DatabaseAccessor<AppDatabase>
    with _$SyncStateDaoMixin {
  SyncStateDao(super.db);

  Future<DateTime?> lastPullAt(String table) async {
    final row = await (select(
      syncState,
    )..where((s) => s.tabela.equals(table))).getSingleOrNull();
    return row?.lastPullAt;
  }

  Future<void> setLastPullAt(String table, DateTime when) async {
    await into(syncState).insertOnConflictUpdate(
      SyncStateCompanion(tabela: Value(table), lastPullAt: Value(when)),
    );
  }

  Future<void> setLastPushAt(String table, DateTime when) async {
    await into(syncState).insertOnConflictUpdate(
      SyncStateCompanion(tabela: Value(table), lastPushAt: Value(when)),
    );
  }
}
