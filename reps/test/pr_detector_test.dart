import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/data/local/database.dart';
import 'package:reps/domain/usecases/pr_detector.dart';

void main() {
  late AppDatabase db;
  late PrDetector detector;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    detector = PrDetector(db);
    // session base
    await db.sessionDao.upsert(
      WorkoutSessionsCompanion.insert(id: 's1', userId: 'u1'),
    );
  });

  tearDown(() async => db.close());

  Future<void> addLog({
    required String id,
    required int reps,
    required double carga,
  }) async {
    await db.setLogDao.upsert(
      SetLogsCompanion.insert(
        id: id,
        sessionId: 's1',
        exerciseId: 'seed:supino_reto_barra',
        ordemNoTreino: 0,
        numeroSerie: 1,
        repsRealizadas: Value(reps),
        cargaKg: Value(carga),
      ),
    );
  }

  test('primeira serie do exercicio gera PR de carga maxima', () async {
    await addLog(id: 'a', reps: 10, carga: 60);
    final prs = await detector.detect(
      exerciseId: 'seed:supino_reto_barra',
      reps: 10,
      cargaKg: 60,
      currentSetLogId: 'a',
    );
    expect(prs.length, 1);
    expect(prs.first.tipo, PrTipo.cargaMax);
  });

  test('primeira serie sem carga (0kg) nao gera PR', () async {
    await addLog(id: 'a', reps: 12, carga: 0);
    final prs = await detector.detect(
      exerciseId: 'seed:supino_reto_barra',
      reps: 12,
      cargaKg: 0,
      currentSetLogId: 'a',
    );
    expect(prs, isEmpty);
  });

  test('primeira serie com carga (20kg) gera PR de cargaMax', () async {
    await addLog(id: 'a', reps: 10, carga: 20);
    final prs = await detector.detect(
      exerciseId: 'seed:supino_reto_barra',
      reps: 10,
      cargaKg: 20,
      currentSetLogId: 'a',
    );
    expect(prs.length, 1);
    expect(prs.first.tipo, PrTipo.cargaMax);
  });

  test('carga maior que historico gera PR de cargaMax', () async {
    await addLog(id: 'a', reps: 10, carga: 60);
    await addLog(id: 'b', reps: 8, carga: 65);
    final prs = await detector.detect(
      exerciseId: 'seed:supino_reto_barra',
      reps: 8,
      cargaKg: 65,
      currentSetLogId: 'b',
    );
    final tipos = prs.map((p) => p.tipo).toSet();
    expect(tipos.contains(PrTipo.cargaMax), isTrue);
  });

  test('mesma carga com mais reps gera PR de repsNaCarga', () async {
    await addLog(id: 'a', reps: 8, carga: 60);
    await addLog(id: 'b', reps: 10, carga: 60);
    final prs = await detector.detect(
      exerciseId: 'seed:supino_reto_barra',
      reps: 10,
      cargaKg: 60,
      currentSetLogId: 'b',
    );
    final tipos = prs.map((p) => p.tipo).toSet();
    expect(tipos.contains(PrTipo.repsNaCarga), isTrue);
  });
}
