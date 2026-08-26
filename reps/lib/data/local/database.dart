import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/cardio_dao.dart';
import 'daos/custom_exercise_dao.dart';
import 'daos/recommender_run_dao.dart';
import 'daos/routine_dao.dart';
import 'daos/session_dao.dart';
import 'daos/set_log_dao.dart';
import 'daos/sync_state_dao.dart';
import 'tables/custom_exercises_table.dart';
import 'tables/recommender_runs_table.dart';
import 'tables/routines_table.dart';
import 'tables/sessions_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Routines,
    RoutineExercises,
    WorkoutSessions,
    SetLogs,
    CardioSessions,
    SyncState,
    CustomExercises,
    RecommenderRuns,
  ],
  daos: [
    RoutineDao,
    SessionDao,
    SetLogDao,
    CardioDao,
    SyncStateDao,
    CustomExerciseDao,
    RecommenderRunDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  /// Total de linhas pendentes de push (dirty) nas tabelas com dono local.
  /// Emite quando o valor muda — o SyncEngine observa este stream (com
  /// debounce) para disparar sync sem que os services conheçam o sync.
  ///
  /// `distinct()` é essencial: sem ele o stream emite a cada escrita nas
  /// tabelas, inclusive os `upsert` que o próprio PULL faz (applyPulled,
  /// markDirty:false — não mudam a contagem). Isso realimentava o auto-sync
  /// (pull → escrita → re-emite → runOnce → pull …) num loop a cada debounce
  /// enquanto sobrasse ≥1 linha dirty que não sobe (ex.: exercício extdb/não
  /// seedado, cujo toJson retorna null). Com distinct, só uma mudança real da
  /// contagem (nova escrita do usuário, ou markClean) redispara.
  Stream<int> watchDirtyCount() {
    return customSelect(
      'SELECT '
      '(SELECT COUNT(*) FROM routines WHERE dirty = 1) + '
      '(SELECT COUNT(*) FROM routine_exercises WHERE dirty = 1) + '
      '(SELECT COUNT(*) FROM workout_sessions WHERE dirty = 1) + '
      '(SELECT COUNT(*) FROM set_logs WHERE dirty = 1) + '
      '(SELECT COUNT(*) FROM cardio_sessions WHERE dirty = 1) AS c',
      readsFrom: {
        routines,
        routineExercises,
        workoutSessions,
        setLogs,
        cardioSessions,
      },
    ).map((row) => row.read<int>('c')).watchSingle().distinct();
  }

  /// Reatribui dados criados no modo convidado para a conta recem-logada.
  ///
  /// No login, [effectiveUserIdProvider] troca o id de convidado pelo id
  /// Supabase. Sem esta migracao, as linhas gravadas como convidado ficam
  /// orfas: somem da UI (queries filtram por user_id) e nunca sobem no sync
  /// (RLS rejeita user_id != auth.uid()). Reatribui o dono nas tabelas que
  /// guardam user_id local e marca `dirty` para re-sync. Os filhos
  /// (routine_exercises, set_logs) seguem o pai e ja estao dirty (convidado
  /// nao sincroniza), entao nao precisam de update.
  ///
  /// Idempotente: no-op quando [guestId] == [newUserId] ou sem linhas.
  /// Retorna o total de linhas reatribuidas.
  Future<int> reassignGuestData({
    required String guestId,
    required String newUserId,
  }) async {
    if (guestId == newUserId || guestId.isEmpty) return 0;
    final agora = DateTime.now().toUtc();
    var total = 0;
    await transaction(() async {
      total += await (update(routines)..where((r) => r.userId.equals(guestId)))
          .write(
            RoutinesCompanion(
              userId: Value(newUserId),
              dirty: const Value(true),
              updatedAt: Value(agora),
            ),
          );
      total +=
          await (update(
            workoutSessions,
          )..where((s) => s.userId.equals(guestId))).write(
            WorkoutSessionsCompanion(
              userId: Value(newUserId),
              dirty: const Value(true),
              updatedAt: Value(agora),
            ),
          );
      total +=
          await (update(
            cardioSessions,
          )..where((c) => c.userId.equals(guestId))).write(
            CardioSessionsCompanion(
              userId: Value(newUserId),
              dirty: const Value(true),
              updatedAt: Value(agora),
            ),
          );
    });
    return total;
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(customExercises);
      }
      if (from < 3) {
        await m.addColumn(routines, routines.origem);
        await m.addColumn(routines, routines.atribuidoPor);
      }
      if (from < 4) {
        await m.createTable(recommenderRuns);
      }
      // `createTable` acima ja cria com o schema atual (inclui sincronizavel).
      // O addColumn so e necessario para quem ja migrou para a v4 sem ela.
      if (from >= 4 && from < 5) {
        await m.addColumn(recommenderRuns, recommenderRuns.sincronizavel);
      }
      // Stage 6: exercicio por tempo (duracao_segundos em set_logs).
      if (from < 6) {
        await m.addColumn(setLogs, setLogs.duracaoSegundos);
      }
      // Stage 6 / Feature A: agrupamento bi-set/circuito em routine_exercises.
      if (from < 7) {
        await m.addColumn(routineExercises, routineExercises.grupoId);
        await m.addColumn(routineExercises, routineExercises.grupoTipo);
        await m.addColumn(routineExercises, routineExercises.rounds);
      }
    },
  );
}

QueryExecutor _openConnection() {
  // driftDatabase auto-detecta plataforma:
  //  - mobile/desktop: SQLite nativo via FFI
  //  - web: WASM via sqlite3.wasm + drift_worker.js (servidos de web/)
  return driftDatabase(
    name: 'reps_sqlite',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
