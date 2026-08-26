import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/data/local/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('ofSessions retorna logs de varias sessoes numa query', () async {
    await db.sessionDao.upsert(
      WorkoutSessionsCompanion.insert(id: 's1', userId: 'u1'),
    );
    await db.sessionDao.upsert(
      WorkoutSessionsCompanion.insert(id: 's2', userId: 'u1'),
    );
    await db.setLogDao.upsert(
      SetLogsCompanion.insert(
        id: 'l1',
        sessionId: 's1',
        exerciseId: 'seed:supino_reto_barra',
        ordemNoTreino: 0,
        numeroSerie: 1,
        cargaKg: const Value(50.0),
      ),
    );
    await db.setLogDao.upsert(
      SetLogsCompanion.insert(
        id: 'l2',
        sessionId: 's2',
        exerciseId: 'seed:supino_reto_barra',
        ordemNoTreino: 0,
        numeroSerie: 1,
        cargaKg: const Value(60.0),
      ),
    );

    final logs = await db.setLogDao.ofSessions(['s1', 's2']);
    expect(logs.map((e) => e.id).toSet(), {'l1', 'l2'});
  });

  test('ofSessions ignora soft-deleted', () async {
    await db.sessionDao.upsert(
      WorkoutSessionsCompanion.insert(id: 's1', userId: 'u1'),
    );
    await db.setLogDao.upsert(
      SetLogsCompanion.insert(
        id: 'l1',
        sessionId: 's1',
        exerciseId: 'seed:supino_reto_barra',
        ordemNoTreino: 0,
        numeroSerie: 1,
        cargaKg: const Value(50.0),
      ),
    );
    await db.setLogDao.softDelete('l1');

    final logs = await db.setLogDao.ofSessions(['s1']);
    expect(logs, isEmpty);
  });

  test('ofSessions com lista vazia retorna vazio', () async {
    expect(await db.setLogDao.ofSessions(const []), isEmpty);
  });
}
