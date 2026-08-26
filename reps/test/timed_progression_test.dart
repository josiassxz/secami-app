// Stage-06 E6: PR por maior duração e progressão por tempo para exercícios
// medidos por tempo (prancha, farmer carry).

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/data/local/database.dart';
import 'package:reps/domain/entities/planned_set.dart';
import 'package:reps/domain/usecases/pr_detector.dart';
import 'package:reps/domain/usecases/progression_engine.dart';
import 'package:reps/features/library/data/library_repository.dart';

void main() {
  late AppDatabase db;
  late PrDetector detector;
  late ProgressionEngine engine;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    detector = PrDetector(db);
    engine = ProgressionEngine(db, LibraryRepository());
    await db.sessionDao.upsert(
      WorkoutSessionsCompanion.insert(id: 's1', userId: 'u1'),
    );
  });

  tearDown(() async => db.close());

  Future<void> addTimed({
    required String id,
    required int dur,
    double? carga,
    int? rpe,
    int serie = 1,
  }) async {
    await db.setLogDao.upsert(
      SetLogsCompanion.insert(
        id: id,
        sessionId: 's1',
        exerciseId: 'seed:prancha',
        ordemNoTreino: 0,
        numeroSerie: serie,
        duracaoSegundos: Value(dur),
        cargaKg: Value(carga),
        rpe: Value(rpe),
      ),
    );
  }

  group('PrDetector.detectTimed', () {
    test('primeira série por tempo = PR de maior duração', () async {
      await addTimed(id: 'a', dur: 45);
      final prs = await detector.detectTimed(
        exerciseId: 'seed:prancha',
        duracaoSegundos: 45,
        cargaKg: 0,
        currentSetLogId: 'a',
      );
      expect(prs.single.tipo, PrTipo.duracaoMax);
      expect(prs.single.valor, 45);
    });

    test('duração maior que histórico gera duracaoMax', () async {
      await addTimed(id: 'a', dur: 45);
      await addTimed(id: 'b', dur: 60);
      final prs = await detector.detectTimed(
        exerciseId: 'seed:prancha',
        duracaoSegundos: 60,
        cargaKg: 0,
        currentSetLogId: 'b',
      );
      expect(prs.map((p) => p.tipo), contains(PrTipo.duracaoMax));
    });

    test('duração menor não gera PR', () async {
      await addTimed(id: 'a', dur: 60);
      await addTimed(id: 'b', dur: 40);
      final prs = await detector.detectTimed(
        exerciseId: 'seed:prancha',
        duracaoSegundos: 40,
        cargaKg: 0,
        currentSetLogId: 'b',
      );
      expect(prs, isEmpty);
    });

    test(
      'carga maior em hold com peso gera cargaMax, não duracaoMax',
      () async {
        await addTimed(id: 'a', dur: 60, carga: 10);
        await addTimed(id: 'b', dur: 50, carga: 20);
        final prs = await detector.detectTimed(
          exerciseId: 'seed:prancha',
          duracaoSegundos: 50,
          cargaKg: 20,
          currentSetLogId: 'b',
        );
        final tipos = prs.map((p) => p.tipo).toSet();
        expect(tipos, contains(PrTipo.cargaMax));
        expect(tipos, isNot(contains(PrTipo.duracaoMax)));
      },
    );
  });

  group('ProgressionEngine.suggestTimed', () {
    const planned = PlannedSet(numero: 1, duracaoAlvoSegundos: 45);
    Future<List<SetLogRow>> logs() => db.setLogDao.ofSession('s1');

    test('todas atingiram o alvo -> aumentar +5s', () async {
      await addTimed(id: 'a', dur: 45, serie: 1);
      await addTimed(id: 'b', dur: 48, serie: 2);
      final sug = engine.suggestTimed(
        planned: planned,
        lastSessionLogs: await logs(),
      );
      expect(sug.decision, ProgressionDecision.aumentar);
      expect(sug.duracaoSugeridaSegundos, 50);
      expect(sug.deltaSegundos, 5);
    });

    test('RPE fácil dobra o incremento', () async {
      await addTimed(id: 'a', dur: 50, rpe: 5, serie: 1);
      await addTimed(id: 'b', dur: 50, rpe: 6, serie: 2);
      final sug = engine.suggestTimed(
        planned: planned,
        lastSessionLogs: await logs(),
      );
      expect(sug.decision, ProgressionDecision.aumentar);
      expect(sug.deltaSegundos, 10);
    });

    test('maioria abaixo do alvo -> reduzir para a maior alcançada', () async {
      await addTimed(id: 'a', dur: 30, serie: 1);
      await addTimed(id: 'b', dur: 35, serie: 2);
      final sug = engine.suggestTimed(
        planned: planned,
        lastSessionLogs: await logs(),
      );
      expect(sug.decision, ProgressionDecision.reduzir);
      expect(sug.duracaoSugeridaSegundos, 35);
    });

    test('sem séries por tempo -> manter alvo', () {
      final sug = engine.suggestTimed(
        planned: planned,
        lastSessionLogs: const [],
      );
      expect(sug.decision, ProgressionDecision.manter);
      expect(sug.duracaoSugeridaSegundos, 45);
      expect(sug.baseadoEmSessoes, 0);
    });
  });
}
