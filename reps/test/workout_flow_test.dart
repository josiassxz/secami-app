// Teste de integracao do fluxo de treino contra um banco Drift em memoria.
// Garante que finalize, set_logs persistem e podem ser lidos do DAO.

import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  test('persiste workout_sessions e set_logs com finalize', () async {
    await db.sessionDao.upsert(
      WorkoutSessionsCompanion.insert(id: 's1', userId: 'u1'),
    );
    final start = await db.sessionDao.findActive('u1');
    expect(start, isNotNull);
    expect(start!.finalizadoEm, isNull);

    await db.setLogDao.upsert(
      SetLogsCompanion.insert(
        id: 'l1',
        sessionId: 's1',
        exerciseId: 'seed:supino_reto_barra',
        ordemNoTreino: 0,
        numeroSerie: 1,
        repsRealizadas: const Value(10),
        cargaKg: const Value(50.0),
      ),
    );
    await db.setLogDao.upsert(
      SetLogsCompanion.insert(
        id: 'l2',
        sessionId: 's1',
        exerciseId: 'seed:supino_reto_barra',
        ordemNoTreino: 0,
        numeroSerie: 2,
        repsRealizadas: const Value(8),
        cargaKg: const Value(52.5),
      ),
    );

    final logs = await db.setLogDao.ofSession('s1');
    expect(logs.length, 2);
    expect(logs.first.cargaKg, 50.0);
    expect(logs.last.cargaKg, 52.5);

    await db.sessionDao.finalize(
      id: 's1',
      finalizadoEm: DateTime.now().toUtc(),
      duracaoSegundos: 1800,
    );
    final closed = await db.sessionDao.findById('s1');
    expect(closed!.finalizadoEm, isNotNull);
    expect(closed.duracaoTotalSegundos, 1800);
  });

  test('listar treinos do usuario ordena por iniciado_em desc', () async {
    final now = DateTime.now().toUtc();
    await db.sessionDao.upsert(
      WorkoutSessionsCompanion.insert(
        id: 'a',
        userId: 'u1',
        iniciadoEm: Value(now.subtract(const Duration(days: 1))),
      ),
    );
    await db.sessionDao.upsert(
      WorkoutSessionsCompanion.insert(
        id: 'b',
        userId: 'u1',
        iniciadoEm: Value(now),
      ),
    );

    final stream = db.sessionDao.watchByUser('u1');
    final first = await stream.first;
    expect(first.map((e) => e.id), ['b', 'a']);
  });
}
