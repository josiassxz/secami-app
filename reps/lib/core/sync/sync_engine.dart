import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/local/database.dart';
import '../../domain/entities/exercise_id.dart';
import '../config/env.dart';
import '../config/supabase_client.dart';
import '../logging/observability.dart';
import '../network/api_client.dart';
import '../network/erro_amigavel.dart';
import 'rest_sync_transport.dart';
import 'sync_mappers.dart';
import 'sync_status.dart';
import 'syncable_table.dart';

/// Motor de sincronizacao local-first.
///
/// Para cada tabela:
///   1) push: envia para Supabase tudo com dirty=true
///   2) pull: baixa tudo com updated_at > last_pull_at
///
/// Resolucao de conflito: **last-write-wins por linha** baseado em updated_at.
/// Soft delete via deleted_at.
///
/// **Off-mode**: quando Supabase nao esta configurado (sem URL ou anon key),
/// o engine vira no-op silencioso. App continua 100% local.
class SyncEngine {
  SyncEngine(this._db, {ApiClient? apiClient}) : _apiClient = apiClient;

  final AppDatabase _db;

  /// Só usado pela produção (`runOnce`) quando `Env.hasRestApi`, para montar
  /// o [RestSyncTransport]. Nulo em testes (que chamam `debugRunOnce` com um
  /// client próprio) é seguro — nunca é lido nesse caminho.
  final ApiClient? _apiClient;

  static const _tableRoutines = 'routines';
  static const _tableRoutineExercises = 'routine_exercises';
  static const _tableSessions = 'workout_sessions';
  static const _tableSetLogs = 'set_logs';
  static const _tableCardio = 'cardio_sessions';
  static const _tableExercises = 'exercises';
  static const _tableRecommenderRuns = 'recommender_runs';

  // Tradutor seed<->uuid da biblioteca global. Local usa 'seed:<slug>';
  // o banco usa uuid. Preenchido a cada sync por _loadExerciseMap.
  Map<String, String> _slugToUuid = {};
  Map<String, String> _uuidToSlug = {};

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = const SyncStatus();

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get status => _status;

  bool _running = false;
  Future<void>? _inFlight;
  Timer? _periodic;
  Timer? _retry;
  Timer? _debounce;
  StreamSubscription<int>? _dirtySub;
  int _retryDelaySeconds = 2;
  static const _retryMax = 30;
  static const _debounceDelay = Duration(seconds: 3);

  void dispose() {
    _periodic?.cancel();
    _retry?.cancel();
    _debounce?.cancel();
    // ignore: discarded_futures
    _dirtySub?.cancel();
    // ignore: discarded_futures
    _statusController.close();
  }

  /// Auto-sync: observa a contagem de linhas dirty do Drift e dispara um
  /// [runOnce] com debounce ([_debounceDelay]). Os services apenas escrevem no
  /// banco (marcam dirty); não conhecem o sync. Substitui as chamadas
  /// `runOnce()` espalhadas (Stage-07 3.2). Debounce evita 1 sync por série
  /// confirmada num treino.
  void startAutoSync(Stream<int> dirtyCount) {
    // ignore: discarded_futures
    _dirtySub?.cancel();
    _dirtySub = dirtyCount.listen((count) {
      if (count <= 0) return;
      _debounce?.cancel();
      _debounce = Timer(_debounceDelay, () {
        // ignore: discarded_futures
        runOnce();
      });
    });
  }

  /// Inicia sync periodico (5 min) enquanto app esta em foreground.
  void startPeriodic() {
    _periodic?.cancel();
    _periodic = Timer.periodic(const Duration(minutes: 5), (_) {
      // ignore: discarded_futures
      runOnce();
    });
  }

  /// Transporte ativo: `RestSyncTransport` (backend SECAMI) quando
  /// `Env.hasRestApi`, senão o `SupabaseClient` legado. Ambos expõem a mesma
  /// fatia de API (`.auth.currentUser`, `.from().select()/.eq()/.gt()/
  /// .upsert()`) por isso `_runOnce` e os métodos internos são tipados
  /// `dynamic` — despacho em tempo de execução, sem duplicar a lógica de
  /// push/pull/last-write-wins para os dois transportes.
  Future<void> runOnce() => _runOnce(
    Env.hasRestApi
        ? RestSyncTransport(_apiClient ?? ApiClient())
        : SupabaseConfig.clientOrNull,
  );

  /// So para testes: injeta um [SupabaseClient] (com stub http + sessao fake)
  /// para exercitar o ciclo real de push/pull/status sem o singleton global do
  /// Supabase nem rede. Mesma abordagem dos outros debug* deste engine — o
  /// client vem por parametro, a producao nao muda.
  @visibleForTesting
  Future<void> debugRunOnce(SupabaseClient? client) => _runOnce(client);

  // dynamic: aceita tanto SupabaseClient (legado/testes) quanto
  // RestSyncTransport (SECAMI) — ver comentário de runOnce() acima.
  Future<void> _runOnce(dynamic client) async {
    if (_running) {
      // Já tem sync rodando: espera ele terminar em vez de virar no-op. Sem
      // isso, um toque manual ("Sincronizar agora") coincidindo com o tick
      // periódico/debounce retornava na hora e a UI lia status velho — dava
      // "Tudo sincronizado" sem ter esperado o resultado real.
      await _inFlight;
      return;
    }
    if (client == null || client.auth.currentUser == null) {
      // Sem auth Supabase nao da pra sync (RLS bloqueia). Tudo bem - local-first.
      await _refreshPendingCount();
      return;
    }
    _running = true;
    final completer = Completer<void>();
    _inFlight = completer.future;
    try {
      await _loadExerciseMap(client);
      await _emit(_status.copyWith(phase: SyncPhase.pushing, clearError: true));
      final falhasPush = await _pushAll(client);
      await _emit(_status.copyWith(phase: SyncPhase.pulling));
      await _pullAll(client);
      _retryDelaySeconds = 2;
      // Status honesto no fim do ciclo: recontar dirty real (linhas que o push
      // por linha rejeitou continuam pendentes) em vez de cravar 0. Se houve
      // falha por linha, sinaliza no lastError; senao limpa o erro.
      final pendentes = await _countPending();
      await _emit(
        _status.copyWith(
          phase: SyncPhase.idle,
          lastSuccessAt: DateTime.now().toUtc(),
          pendingPush: pendentes,
          lastError: falhasPush > 0
              ? '$falhasPush registro(s) nao subiram; ficam pendentes'
              : null,
          clearError: falhasPush == 0,
        ),
      );
    } catch (e, st) {
      await Observability.captureError(e, st, hint: 'sync');
      await _emit(
        _status.copyWith(phase: SyncPhase.error, lastError: _shortError(e)),
      );
      // Retry exponencial. Guardado em campo para dispose() poder cancelar
      // (senao podia disparar runOnce com o DB ja fechado).
      _retry?.cancel();
      _retry = Timer(Duration(seconds: _retryDelaySeconds), () {
        _retryDelaySeconds = (_retryDelaySeconds * 2).clamp(2, _retryMax);
        // ignore: discarded_futures
        runOnce();
      });
    } finally {
      _running = false;
      _inFlight = null;
      completer.complete();
    }
  }

  Future<void> _refreshPendingCount() async {
    await _emit(_status.copyWith(pendingPush: await _countPending()));
  }

  /// Soma as linhas dirty das 5 tabelas com dono (o que ainda falta subir).
  Future<int> _countPending() async {
    var pending = 0;
    pending += (await _db.routineDao.dirtyRoutines()).length;
    pending += (await _db.routineDao.dirtyExercises()).length;
    pending += (await _db.sessionDao.dirty()).length;
    pending += (await _db.setLogDao.dirty()).length;
    pending += (await _db.cardioDao.dirty()).length;
    return pending;
  }

  Future<void> _emit(SyncStatus next) async {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  /// Texto que o usuário vê ao tocar no aviso de sync com falha: nunca o
  /// toString técnico da exceção (o detalhe completo já vai pra telemetria em
  /// `Observability.captureError`, no catch de quem chama).
  String _shortError(Object e) => mensagemDeErro(
    e,
    fallback:
        'Não foi possível sincronizar agora. Vamos tentar de novo em instantes.',
  );

  /// Tabelas sincronizáveis (push + pull genéricos). Adicionar uma tabela ao
  /// sync = registrar um [SyncableTable] aqui — sem editar push/pull/mappers
  /// espalhados (Stage-07 3.1). Ordem importa no pull (FK: pais antes dos
  /// filhos). O recomendador NÃO entra aqui: é push-only e scoped por uid
  /// (ver _pushRecommenderRuns).
  List<SyncableTable<dynamic>> get _syncables => [
    SyncableTable<RoutineRow>(
      name: _tableRoutines,
      ownerColumn: 'user_id',
      dirty: _db.routineDao.dirtyRoutines,
      markClean: _db.routineDao.markRoutinesClean,
      idOf: (r) => r.id,
      toJson: routineToJson,
      applyPulled: (j) =>
          _db.routineDao.upsert(routineFromJson(j), markDirty: false),
    ),
    SyncableTable<RoutineExerciseRow>(
      name: _tableRoutineExercises,
      ownerColumn: 'owner_user_id',
      dirty: _db.routineDao.dirtyExercises,
      markClean: _db.routineDao.markExercisesClean,
      idOf: (re) => re.id,
      toJson: (re) {
        final dbExId = _exIdToDb(re.exerciseId);
        if (dbExId == null) return null; // global nao seedado / extdb: local
        return routineExerciseToJson(re)..['exercise_id'] = dbExId;
      },
      applyPulled: (j) => _db.routineDao.upsertExercise(
        routineExerciseFromJson(j, _exIdFromDb),
        markDirty: false,
      ),
    ),
    SyncableTable<WorkoutSessionRow>(
      name: _tableSessions,
      ownerColumn: 'user_id',
      dirty: _db.sessionDao.dirty,
      markClean: _db.sessionDao.markCleanAll,
      idOf: (s) => s.id,
      toJson: sessionToJson,
      applyPulled: (j) =>
          _db.sessionDao.upsert(sessionFromJson(j), markDirty: false),
    ),
    SyncableTable<SetLogRow>(
      name: _tableSetLogs,
      ownerColumn: 'owner_user_id',
      dirty: _db.setLogDao.dirty,
      markClean: _db.setLogDao.markCleanAll,
      idOf: (l) => l.id,
      toJson: (l) {
        final dbExId = _exIdToDb(l.exerciseId);
        if (dbExId == null) return null;
        final sub = l.substituidoDeExerciseId;
        return setLogToJson(l)
          ..['exercise_id'] = dbExId
          ..['substituido_de_exercise_id'] = sub == null
              ? null
              : _exIdToDb(sub);
      },
      applyPulled: (j) => _db.setLogDao.upsert(
        setLogFromJson(j, _exIdFromDb),
        markDirty: false,
      ),
    ),
    SyncableTable<CardioSessionRow>(
      name: _tableCardio,
      ownerColumn: 'user_id',
      dirty: _db.cardioDao.dirty,
      markClean: _db.cardioDao.markCleanAll,
      idOf: (c) => c.id,
      toJson: cardioToJson,
      applyPulled: (j) =>
          _db.cardioDao.upsert(cardioFromJson(j), markDirty: false),
    ),
  ];

  // ============== PUSH ==============
  /// Retorna o total de linhas que falharam no fallback por linha do ciclo
  /// (0 = tudo subiu). Essas linhas ficam dirty e tentam de novo depois; o
  /// runOnce usa esse total para sinalizar pendencia real em vez de fingir
  /// sucesso.
  Future<int> _pushAll(dynamic client) async {
    var falhas = 0;
    for (final t in _syncables) {
      falhas += await _pushTable(client, t);
    }
    falhas += await _pushRecommenderRuns(client);
    return falhas;
  }

  /// Push genérico de um [SyncableTable]: coleta dirty, monta jsons (pulando os
  /// que [SyncableTable.toJson] retorna null = ficam locais) e delega ao
  /// _pushJsons (batch + fallback por linha).
  Future<int> _pushTable<T>(dynamic client, SyncableTable<T> t) async {
    final dirty = await t.dirty();
    final ids = <String>[];
    final jsons = <Map<String, dynamic>>[];
    // Receptor `dynamic`: `_syncables` é `List<SyncableTable<dynamic>>`, então
    // LER `t.toJson`/`t.idOf` insere um check de getter covariante — a closure
    // real é `Fn(RoutineRow)` mas o campo é tipado `Fn(dynamic)`, e `dynamic`
    // não é subtipo de `RoutineRow` (contravariância). Sob tipagem sã (dart2js
    // e o VM em teste) esse check derruba o push inteiro. Acesso dinâmico pula
    // o check de reificação; a validação recai só no parâmetro (r já é do tipo
    // certo), preservando o resultado em AOT.
    final td = t as dynamic;
    for (final r in dirty) {
      final j = td.toJson(r) as Map<String, dynamic>?;
      if (j == null) continue;
      ids.add(td.idOf(r) as String);
      jsons.add(j);
    }
    final falhas = await _pushJsons(
      client,
      table: t.name,
      ids: ids,
      jsons: jsons,
      markClean: t.markClean,
    );
    if (jsons.isNotEmpty) {
      await _db.syncStateDao.setLastPushAt(t.name, DateTime.now().toUtc());
    }
    return falhas;
  }

  /// Envia [jsons] (paralelo a [rows]) num unico upsert em batch (evita o N+1
  /// de 1 HTTP por linha). Em caso de erro do batch, cai para push por linha
  /// (2.4): uma linha quebrada — ex.: constraint do servidor — nao trava a
  /// fila inteira; ela fica dirty e tenta de novo no proximo ciclo. So marca
  /// clean o que realmente subiu.
  Future<int> _pushJsons(
    dynamic client, {
    required String table,
    required List<String> ids,
    required List<Map<String, dynamic>> jsons,
    required Future<void> Function(List<String>) markClean,
  }) async {
    if (jsons.isEmpty) return 0;
    try {
      await client.from(table).upsert(jsons);
      await markClean(ids);
      return 0;
    } catch (_) {
      var falhas = 0;
      for (var i = 0; i < jsons.length; i++) {
        try {
          await client.from(table).upsert(jsons[i]);
          await markClean([ids[i]]);
        } catch (e, st) {
          falhas++;
          await Observability.captureError(e, st, hint: 'sync_push_$table');
        }
      }
      return falhas;
    }
  }

  /// Push-only dos registros do recomendador (auditoria). So sobem os marcados
  /// `sincronizavel` = consentimento concedido na geracao (RN-051). Sao
  /// append-only: nao ha pull (a rotina salva ja sincroniza pela via normal).
  Future<int> _pushRecommenderRuns(dynamic client) async {
    final uid = client.auth.currentUser!.id as String;
    final pendentes = await _db.recommenderRunDao.pendentesSync(uid);
    return _pushJsons(
      client,
      table: _tableRecommenderRuns,
      ids: [for (final r in pendentes) r.id],
      jsons: [for (final r in pendentes) recommenderRunToJson(r)],
      markClean: (ids) => _db.recommenderRunDao.marcarSincronizadoAll(ids),
    );
  }

  /// Traduz exercise_id local -> id do banco para PUSH.
  /// - `seed:slug` -> uuid global (null se nao estiver no banco ainda).
  /// - `extdb:slug` -> null: exercicio de base externa nao existe no Supabase,
  ///   fica so local (mesmo tratamento de seed nao-seedado). Sem isso o slug
  ///   subiria verbatim como exercise_id, virava uuid invalido e derrubava o
  ///   sync inteiro em erro/retry.
  /// - uuid custom -> ele mesmo.
  String? _exIdToDb(String localId) {
    final eid = ExerciseId.parse(localId);
    if (eid.isExtdb) return null;
    if (!eid.isSeed) return localId;
    return _slugToUuid[eid.value];
  }

  /// So para testes: expoe a traducao de id usada no PUSH. `null` = nao sobe
  /// (fica local), que e o que impede o sync de quebrar com ids `extdb:`.
  @visibleForTesting
  String? debugExIdToDb(String localId) => _exIdToDb(localId);

  /// Traduz exercise_id do banco -> id local para PULL.
  /// - uuid de exercicio global -> `seed:slug`.
  /// - uuid custom (ou desconhecido) -> ele mesmo.
  String _exIdFromDb(String dbId) {
    final slug = _uuidToSlug[dbId];
    return slug == null ? dbId : 'seed:$slug';
  }

  /// Carrega o mapa slug<->uuid da biblioteca global (criado_por null).
  /// Falha graciosa: se a tabela nao existir/seed nao rodado, mapas vazios
  /// e set_logs/routine_exercises de exercicios padrao ficam so locais.
  Future<void> _loadExerciseMap(dynamic client) async {
    try {
      final rows =
          await client.from(_tableExercises).select('id, slug, criado_por')
              as List;
      final slugTo = <String, String>{};
      final uuidTo = <String, String>{};
      for (final r in rows.cast<Map<String, dynamic>>()) {
        if (r['criado_por'] != null) continue; // so biblioteca global
        final id = r['id'] as String?;
        final slug = r['slug'] as String?;
        if (id == null || slug == null) continue;
        slugTo[slug] = id;
        uuidTo[id] = slug;
      }
      _slugToUuid = slugTo;
      _uuidToSlug = uuidTo;
    } catch (e, st) {
      await Observability.captureError(e, st, hint: 'sync_exercise_map');
      // mantem mapas anteriores (ou vazios) — degrada sem quebrar o sync.
    }
  }

  // ============== PULL ==============
  Future<void> _pullAll(dynamic client) async {
    // Dono dos dados = usuario autenticado. runOnce ja garante != null.
    final uid = client.auth.currentUser!.id as String;
    for (final t in _syncables) {
      await _pullTable(
        client,
        table: t.name,
        ownerColumn: t.ownerColumn,
        uid: uid,
        apply: (rows) async {
          for (final j in rows) {
            await t.applyPulled(j);
          }
        },
      );
    }
  }

  /// PULL de uma tabela do dono. **Sempre** filtra por [ownerColumn] = [uid]:
  /// a RLS (Stage 4) deixa o treinador LER dados de alunos, mas esses dados
  /// nunca podem entrar no Drift local do treinador. Sem este filtro, o sync
  /// do professor baixaria o historico de todos os alunos. Ver
  /// docs/stages/stage-04-coaching.md, secao 5.
  Future<void> _pullTable(
    dynamic client, {
    required String table,
    required String ownerColumn,
    required String uid,
    required Future<void> Function(List<Map<String, dynamic>>) apply,
  }) async {
    final since = await _db.syncStateDao.lastPullAt(table);
    var filtered = client.from(table).select().eq(ownerColumn, uid);
    if (since != null) {
      filtered = filtered.gt('updated_at', since.toUtc().toIso8601String());
    }
    final rows = (await filtered as List).cast<Map<String, dynamic>>();
    await apply(rows);
    // Cursor = max(updated_at) das linhas puxadas, nao DateTime.now() do device.
    // O relogio do device pode estar adiantado em relacao ao servidor; gravar
    // "agora" como cursor pularia (perderia) linhas escritas no servidor com
    // updated_at entre o tempo do servidor e o do device. Avanca so quando ha
    // linhas; sem linhas, mantem o cursor anterior. O `.gt` (estrito) garante
    // que a propria linha-max nao volta no proximo pull.
    DateTime? maxUpdated;
    for (final j in rows) {
      final ts = parseTs(j['updated_at']);
      if (ts != null && (maxUpdated == null || ts.isAfter(maxUpdated))) {
        maxUpdated = ts;
      }
    }
    if (maxUpdated != null) {
      await _db.syncStateDao.setLastPullAt(table, maxUpdated);
    }
  }

  /// Dispara um PULL isolado de uma tabela. So para testes: permite verificar
  /// que o filtro de dono ([ownerColumn] = [uid]) realmente vai na query, sem
  /// depender de uma sessao de auth real.
  @visibleForTesting
  Future<void> debugPull(
    SupabaseClient client, {
    required String table,
    required String ownerColumn,
    required String uid,
  }) {
    return _pullTable(
      client,
      table: table,
      ownerColumn: ownerColumn,
      uid: uid,
      apply: (_) async {},
    );
  }
}
