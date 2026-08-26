// Fase 2.1 (docs/stages/stage-07-arquitetura.md): push em batch precisa marcar
// clean em lote (markCleanAll / markRoutinesClean) em vez de 1 update por linha.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('markRoutinesClean limpa varias rotinas de uma vez', () async {
    for (final id in ['r1', 'r2', 'r3']) {
      await db.routineDao.upsert(
        RoutinesCompanion.insert(id: id, userId: 'u1', nome: id),
      );
    }
    expect((await db.routineDao.dirtyRoutines()).length, 3);

    await db.routineDao.markRoutinesClean(['r1', 'r2', 'r3']);

    expect(await db.routineDao.dirtyRoutines(), isEmpty);
  });

  test('markCleanAll de sessoes e idempotente com lista vazia', () async {
    await db.sessionDao.upsert(
      WorkoutSessionsCompanion.insert(id: 's1', userId: 'u1'),
    );
    await db.sessionDao.markCleanAll([]); // no-op
    expect((await db.sessionDao.dirty()).length, 1);

    await db.sessionDao.markCleanAll(['s1']);
    expect(await db.sessionDao.dirty(), isEmpty);
  });

  // Fase 3.2: o auto-sync observa este contador; precisa somar as 5 tabelas.
  test('watchDirtyCount soma dirty das tabelas com dono', () async {
    expect(await db.watchDirtyCount().first, 0);

    await db.routineDao.upsert(
      RoutinesCompanion.insert(id: 'r1', userId: 'u1', nome: 'A'),
    );
    await db.sessionDao.upsert(
      WorkoutSessionsCompanion.insert(id: 's1', userId: 'u1'),
    );
    expect(await db.watchDirtyCount().first, 2);

    await db.routineDao.markRoutinesClean(['r1']);
    expect(await db.watchDirtyCount().first, 1);
  });
}
