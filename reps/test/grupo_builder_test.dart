// Stage-07/06: regressão do agrupamento bi-set/circuito no builder.
// Crava que agruparComAnterior/definirTipoGrupo persistem grupo_id/grupo_tipo
// LOCALMENTE (independente de sync). Se isto passa, "não mudou no front" é
// sync/seed ou UX, não bug de persistência.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/data/local/database.dart';
import 'package:reps/domain/entities/grupo_exercicio.dart';
import 'package:reps/features/routines/data/routine_providers.dart';

void main() {
  late AppDatabase db;
  late RoutineService svc;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    svc = RoutineService(db, 'u1');
  });

  tearDown(() async => db.close());

  Future<(String, String, String)> rotinaCom2() async {
    final rid = await svc.create(
      nome: 'Peito',
      tipo: 'fixo',
      diasDaSemana: const [],
    );
    final e1 = await svc.addExercise(
      routineId: rid,
      exerciseId: 'seed:supino-reto',
      ordem: 0,
    );
    final e2 = await svc.addExercise(
      routineId: rid,
      exerciseId: 'seed:crucifixo',
      ordem: 1,
    );
    return (rid, e1, e2);
  }

  test('agruparComAnterior cria grupo bi-set nos dois exercicios', () async {
    final (rid, e1, e2) = await rotinaCom2();

    await svc.agruparComAnterior(rid, e2);

    final list = await svc.exercisesOf(rid);
    final r1 = list.firstWhere((e) => e.id == e1);
    final r2 = list.firstWhere((e) => e.id == e2);
    expect(r1.grupoId, isNotNull);
    expect(r1.grupoId, r2.grupoId, reason: 'mesmo grupo nos dois');
    expect(r1.grupoTipo, 'bi_set');
    expect(r2.grupoTipo, 'bi_set');
    expect(r1.dirty, isTrue, reason: 'precisa subir no sync');
    expect(r2.dirty, isTrue);
  });

  test('definirTipoGrupo aplica tipo/rounds a todos os membros', () async {
    final (rid, _, e2) = await rotinaCom2();
    await svc.agruparComAnterior(rid, e2);
    final gid = (await svc.exercisesOf(rid)).first.grupoId!;

    await svc.definirTipoGrupo(
      routineId: rid,
      grupoId: gid,
      tipo: GrupoTipo.circuito,
      rounds: 4,
    );

    final list = await svc.exercisesOf(rid);
    expect(list.every((e) => e.grupoTipo == 'circuito'), isTrue);
    expect(list.every((e) => e.rounds == 4), isTrue);
  });

  test('desagrupar com 2 membros volta ambos a solo', () async {
    final (rid, _, e2) = await rotinaCom2();
    await svc.agruparComAnterior(rid, e2);

    await svc.desagrupar(rid, e2);

    final list = await svc.exercisesOf(rid);
    expect(list.every((e) => e.grupoId == null), isTrue);
    expect(list.every((e) => e.grupoTipo == 'normal'), isTrue);
  });
}
