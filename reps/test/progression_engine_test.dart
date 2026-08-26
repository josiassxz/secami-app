import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/data/local/database.dart';
import 'package:reps/domain/entities/planned_set.dart';
import 'package:reps/domain/usecases/progression_engine.dart';
import 'package:reps/features/library/data/library_repository.dart';

void main() {
  late AppDatabase db;
  late LibraryRepository repo;
  late ProgressionEngine engine;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LibraryRepository();
    engine = ProgressionEngine(db, repo);
  });

  tearDown(() async => db.close());

  SetLogRow log({required int reps, required double carga}) {
    final now = DateTime.now().toUtc();
    return SetLogRow(
      id: 'l-${reps}_$carga',
      sessionId: 's',
      exerciseId: 'seed:supino_reto_barra',
      ordemNoTreino: 0,
      numeroSerie: 1,
      repsRealizadas: reps,
      cargaKg: carga,
      tipoSerie: 'normal',
      executada: true,
      criadoEm: now,
      updatedAt: now,
      dirty: false,
    );
  }

  test('todas no topo da faixa em composto -> +2.5kg', () {
    final exercise = repo.findBySlug('supino_reto_barra')!;
    const planned = PlannedSet(numero: 1, repsAlvoMin: 8, repsAlvoMax: 10);
    final logs = [
      log(reps: 10, carga: 60),
      log(reps: 10, carga: 60),
      log(reps: 10, carga: 60),
    ];
    final s = engine.suggest(
      exercise: exercise,
      planned: planned,
      lastSessionLogs: logs,
    );
    expect(s.decision, ProgressionDecision.aumentar);
    expect(s.cargaSugerida, 62.5);
    expect(s.delta, 2.5);
  });

  test('todas no topo em isolador -> +1kg', () {
    final exercise = repo.findBySlug('rosca_direta_barra')!;
    const planned = PlannedSet(numero: 1, repsAlvoMin: 10, repsAlvoMax: 12);
    final logs = [log(reps: 12, carga: 20), log(reps: 12, carga: 20)];
    final s = engine.suggest(
      exercise: exercise,
      planned: planned,
      lastSessionLogs: logs,
    );
    expect(s.decision, ProgressionDecision.aumentar);
    expect(s.cargaSugerida, 21.0);
    expect(s.delta, 1.0);
  });

  test('todas abaixo da faixa minima -> -5%', () {
    final exercise = repo.findBySlug('supino_reto_barra')!;
    const planned = PlannedSet(numero: 1, repsAlvoMin: 8, repsAlvoMax: 10);
    final logs = [
      log(reps: 5, carga: 80),
      log(reps: 5, carga: 80),
      log(reps: 4, carga: 80),
    ];
    final s = engine.suggest(
      exercise: exercise,
      planned: planned,
      lastSessionLogs: logs,
    );
    expect(s.decision, ProgressionDecision.reduzir);
    expect(s.cargaSugerida, 76.0);
  });

  test('metade na faixa -> manter', () {
    final exercise = repo.findBySlug('supino_reto_barra')!;
    const planned = PlannedSet(numero: 1, repsAlvoMin: 8, repsAlvoMax: 10);
    final logs = [
      log(reps: 9, carga: 70),
      log(reps: 8, carga: 70),
      log(reps: 6, carga: 70),
      log(reps: 7, carga: 70),
    ];
    final s = engine.suggest(
      exercise: exercise,
      planned: planned,
      lastSessionLogs: logs,
    );
    expect(s.decision, ProgressionDecision.manter);
    expect(s.cargaSugerida, 70.0);
  });

  test('sem logs -> manter carga alvo', () {
    final exercise = repo.findBySlug('supino_reto_barra')!;
    const planned = PlannedSet(numero: 1, cargaAlvo: 50);
    final s = engine.suggest(
      exercise: exercise,
      planned: planned,
      lastSessionLogs: const [],
    );
    expect(s.decision, ProgressionDecision.manter);
    expect(s.cargaSugerida, 50);
  });
}
