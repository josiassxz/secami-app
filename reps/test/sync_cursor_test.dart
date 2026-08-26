// Fase 2.2 (docs/stages/stage-07-arquitetura.md): o cursor de PULL deve
// avancar para max(updated_at) das linhas puxadas, nao para DateTime.now() do
// device. Com clock skew (device adiantado), gravar "agora" pularia linhas
// escritas no servidor entre o tempo do servidor e o do device.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:reps/core/sync/sync_engine.dart';
import 'package:reps/data/local/database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// http.Client que responde sempre com o [body] JSON fixo, sem rede.
class _StubClient extends http.BaseClient {
  _StubClient(this.body);

  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  SupabaseClient supa(http.Client c) =>
      SupabaseClient('https://exemplo.supabase.co', 'anon-key', httpClient: c);

  test('cursor avanca para max(updated_at) das linhas', () async {
    final rows = [
      {'id': 'a', 'user_id': 'u1', 'updated_at': '2026-01-01T10:00:00.000Z'},
      {'id': 'b', 'user_id': 'u1', 'updated_at': '2026-01-02T10:00:00.000Z'},
    ];
    final engine = SyncEngine(db);

    await engine.debugPull(
      supa(_StubClient(jsonEncode(rows))),
      table: 'routines',
      ownerColumn: 'user_id',
      uid: 'u1',
    );

    final cursor = await db.syncStateDao.lastPullAt('routines');
    expect(cursor, isNotNull);
    expect(
      cursor!.isAtSameMomentAs(DateTime.utc(2026, 1, 2, 10)),
      isTrue,
      reason: 'cursor = max(updated_at), nao o relogio do device',
    );
    engine.dispose();
  });

  test('sem linhas, cursor nao avanca (fica null)', () async {
    final engine = SyncEngine(db);

    await engine.debugPull(
      supa(_StubClient('[]')),
      table: 'routines',
      ownerColumn: 'user_id',
      uid: 'u1',
    );

    expect(await db.syncStateDao.lastPullAt('routines'), isNull);
    engine.dispose();
  });
}
