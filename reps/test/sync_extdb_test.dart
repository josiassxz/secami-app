// Fase 1.2 (docs/stages/stage-07-arquitetura.md): id de exercicio `extdb:slug`
// (base externa) nao existe no Supabase. Se subisse verbatim como exercise_id,
// viraria uuid invalido -> excecao -> sync inteiro em erro/retry. A traducao
// de PUSH deve retornar null (fica local), igual ao seed nao-seedado.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/core/sync/sync_engine.dart';
import 'package:reps/data/local/database.dart';

void main() {
  late AppDatabase db;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    engine = SyncEngine(db);
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  test('extdb: nao sobe (fica local) — nao derruba o sync', () {
    expect(engine.debugExIdToDb('extdb:agachamento-bulgaro'), isNull);
  });

  test('seed: nao mapeado fica local', () {
    expect(engine.debugExIdToDb('seed:supino-reto'), isNull);
  });

  test('uuid de exercicio custom sobe como ele mesmo', () {
    expect(engine.debugExIdToDb('e3f1c2a0-custom'), 'e3f1c2a0-custom');
  });
}
