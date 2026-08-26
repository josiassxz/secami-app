// Plano 013: o status de sync tem que ser honesto no fim de um runOnce.
//   1) sucesso de verdade zera pendingPush e limpa o erro;
//   2) push que o servidor rejeita por linha NAO pode terminar "sincronizado" —
//      as linhas seguem dirty e pendingPush precisa reflete-las (regressao do
//      bug do `pendingPush: 0` cravado);
//   3) o guard de concorrencia (_running/_inFlight) faz o 2o runOnce esperar o
//      1o em vez de rodar um ciclo novo;
//   4) erro no ciclo (pull falha) deixa o status em phase.error com lastError.
//
// Segue o padrao de test/sync_owner_filter_test.dart: stub de http.BaseClient +
// Drift in-memory + SupabaseClient construido no teste. A sessao e injetada
// localmente via GoTrue.setInitialSession (sem rede) para currentUser != null,
// e o ciclo real roda por SyncEngine.debugRunOnce(client).

import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:reps/core/sync/sync_engine.dart';
import 'package:reps/core/sync/sync_status.dart';
import 'package:reps/data/local/database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stub de rede: registra cada request e responde conforme o modo.
/// - GET (pull + mapa de exercicios): 200 `[]` (a menos de [failAll]).
/// - escrita (upsert = POST/PATCH): 400 quando [failPush] ou [failAll].
/// - [gate]: se setado, cada send espera esse future antes de responder —
///   permite sobrepor dois runOnce para exercitar o guard de concorrencia.
class _StubClient extends http.BaseClient {
  _StubClient({this.failPush = false, this.failAll = false, this.gate});

  final bool failPush;
  final bool failAll;
  final Future<void>? gate;
  final List<http.BaseRequest> requests = [];

  int writesTo(String table) => requests
      .where((r) => r.method != 'GET' && r.url.path.endsWith('/$table'))
      .length;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (gate != null) await gate;
    final isWrite = request.method != 'GET';
    final falha = failAll || (failPush && isWrite);
    final body = falha ? '{"message":"boom","code":"PGRST"}' : '[]';
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      falha ? 400 : 200,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }
}

void main() {
  late AppDatabase db;

  setUpAll(() {
    // Observability.captureError (chamado no fallback de push e no catch do
    // ciclo) le Env/dotenv; sem init joga NotInitializedError.
    dotenv.testLoad();
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // SupabaseClient de teste ja autenticado: injeta uma sessao local (sem rede)
  // para que client.auth.currentUser != null e o runOnce nao caia no ramo
  // "sem auth".
  Future<SupabaseClient> authedClient(http.Client c) async {
    final client = SupabaseClient(
      'https://exemplo.supabase.co',
      'anon-key',
      httpClient: c,
    );
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'fake-token',
        'token_type': 'bearer',
        'user': {
          'id': 'user-123',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00.000Z',
        },
      }),
    );
    return client;
  }

  Future<void> seedDuasRotinasDirty() async {
    await db.routineDao.upsert(
      RoutinesCompanion.insert(id: 'r1', userId: 'user-123', nome: 'A'),
    );
    await db.routineDao.upsert(
      RoutinesCompanion.insert(id: 'r2', userId: 'user-123', nome: 'B'),
    );
  }

  test('sessao injetada deixa currentUser != null', () async {
    final client = await authedClient(_StubClient());
    expect(client.auth.currentUser, isNotNull);
    expect(client.auth.currentUser!.id, 'user-123');
    await client.dispose();
  });

  test(
    'push rejeitado por linha: pendingPush honesto e lastError set',
    () async {
      await seedDuasRotinasDirty();
      expect((await db.routineDao.dirtyRoutines()).length, 2);

      final stub = _StubClient(failPush: true); // pull ok, escrita rejeitada
      final client = await authedClient(stub);
      final engine = SyncEngine(db);

      await engine.debugRunOnce(client);

      // As 2 rotinas nao subiram -> continuam dirty -> pendingPush = 2.
      expect((await db.routineDao.dirtyRoutines()).length, 2);
      expect(engine.status.phase, SyncPhase.idle);
      expect(engine.status.pendingPush, 2);
      expect(
        engine.status.lastError,
        isNotNull,
        reason: 'falha por linha tem que ser visivel no status',
      );

      engine.dispose();
      await client.dispose();
    },
  );

  test('sucesso real zera pendingPush e limpa o erro', () async {
    await seedDuasRotinasDirty();

    final stub = _StubClient(); // tudo 200
    final client = await authedClient(stub);
    final engine = SyncEngine(db);

    await engine.debugRunOnce(client);

    expect(await db.routineDao.dirtyRoutines(), isEmpty);
    expect(engine.status.phase, SyncPhase.idle);
    expect(engine.status.pendingPush, 0);
    expect(engine.status.lastError, isNull);
    expect(engine.status.lastSuccessAt, isNotNull);

    engine.dispose();
    await client.dispose();
  });

  test(
    'concorrencia: 2o runOnce espera o 1o (um unico ciclo de push)',
    () async {
      await seedDuasRotinasDirty();

      final gate = Completer<void>();
      final stub = _StubClient(gate: gate.future);
      final client = await authedClient(stub);
      final engine = SyncEngine(db);

      // Dispara os dois antes de liberar a rede. O 1o segura _running=true no
      // primeiro await; o 2o cai no guard e passa a esperar _inFlight.
      final f1 = engine.debugRunOnce(client);
      final f2 = engine.debugRunOnce(client);
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future.wait([f1, f2]);

      // So um ciclo escreveu em routines (o 2o nao rodou push proprio).
      expect(
        stub.writesTo('routines'),
        1,
        reason:
            'o 2o runOnce deve reusar o ciclo em andamento, nao abrir outro',
      );
      expect(await db.routineDao.dirtyRoutines(), isEmpty);

      engine.dispose();
      await client.dispose();
    },
  );

  test('erro no ciclo (pull falha): phase.error com lastError', () async {
    await seedDuasRotinasDirty();

    final stub = _StubClient(failAll: true); // pull tambem lanca
    final client = await authedClient(stub);
    final engine = SyncEngine(db);

    await engine.debugRunOnce(client);

    expect(engine.status.phase, SyncPhase.error);
    expect(engine.status.lastError, isNotNull);

    engine.dispose();
    await client.dispose();
  });
}
