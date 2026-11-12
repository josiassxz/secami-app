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

  group('backend SECAMI (REST, exercise_id texto)', () {
    test(
      'seed não mapeado sobe como "seed:slug" (carga não fica só local)',
      () {
        expect(
          engine.debugExIdToDb('seed:supino-reto', backendRest: true),
          'seed:supino-reto',
        );
      },
    );

    test('extdb sobe como está', () {
      expect(
        engine.debugExIdToDb('extdb:agachamento-bulgaro', backendRest: true),
        'extdb:agachamento-bulgaro',
      );
    });

    test('uuid do catálogo sobe como ele mesmo', () {
      expect(
        engine.debugExIdToDb('e3f1c2a0-custom', backendRest: true),
        'e3f1c2a0-custom',
      );
    });
  });
}
