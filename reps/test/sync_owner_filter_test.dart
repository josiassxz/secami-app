// Anti-regressao do Stage 4 (docs/stages/stage-04-coaching.md, secao 5):
// o PULL do sync DEVE sempre filtrar pelo dono dos dados. A RLS deixa o
// treinador LER dados de alunos; sem este filtro, o sync do professor baixaria
// o historico de todos os alunos para o Drift local dele.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:reps/core/sync/sync_engine.dart';
import 'package:reps/data/local/database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// http.Client que nao faz rede: registra a ultima URL e responde `[]`.
class _CapturingClient extends http.BaseClient {
  final List<Uri> urls = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    urls.add(request.url);
    return http.StreamedResponse(
      Stream.value(utf8.encode('[]')),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }
}

void main() {
  late AppDatabase db;
  late _CapturingClient httpClient;
  late SupabaseClient supabase;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    httpClient = _CapturingClient();
    supabase = SupabaseClient(
      'https://exemplo.supabase.co',
      'anon-key-de-teste',
      httpClient: httpClient,
    );
  });

  tearDown(() async {
    await db.close();
  });

  // (tabela, coluna de dono) que o PULL precisa filtrar.
  const casos = {
    'routines': 'user_id',
    'routine_exercises': 'owner_user_id',
    'workout_sessions': 'user_id',
    'set_logs': 'owner_user_id',
    'cardio_sessions': 'user_id',
  };

  for (final caso in casos.entries) {
    test('pull de ${caso.key} filtra por ${caso.value} = uid', () async {
      const uid = 'prof-123';
      final engine = SyncEngine(db);
      await engine.debugPull(
        supabase,
        table: caso.key,
        ownerColumn: caso.value,
        uid: uid,
      );

      expect(httpClient.urls, isNotEmpty);
      final query = httpClient.urls.last.query;
      // PostgREST: filtro vira `<coluna>=eq.<valor>`.
      expect(
        query,
        contains('${caso.value}=eq.$uid'),
        reason: 'sem o filtro de dono o sync vaza dados de outros usuarios',
      );
    });
  }
}
