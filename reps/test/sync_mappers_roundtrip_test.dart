// Fase 3.1 (docs/stages/stage-07-arquitetura.md): cada mapper extraído precisa
// de roundtrip JSON — toJson seguido de fromJson preserva os campos sincronizados.
// Usa um DB in-memory só para materializar as Rows com defaults realistas.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/core/sync/sync_mappers.dart';
import 'package:reps/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  String ident(String s) => s;

  test('routine roundtrip preserva campos', () async {
    await db.routineDao.upsert(
      RoutinesCompanion.insert(
        id: 'r1',
        userId: 'u1',
        nome: 'Treino A',
        tipo: const Value('ondulatorio'),
        diasDaSemana: const Value('[1,3,5]'),
        ordem: const Value(2),
        ativo: const Value(false),
        origem: const Value('atribuida'),
        atribuidoPor: const Value('prof-1'),
      ),
    );
    final r = (await db.routineDao.findById('r1'))!;

    final c = routineFromJson(routineToJson(r));

    expect(c.id.value, r.id);
    expect(c.userId.value, r.userId);
    expect(c.nome.value, r.nome);
    expect(c.tipo.value, r.tipo);
    expect(c.diasDaSemana.value, r.diasDaSemana);
    expect(c.ordem.value, r.ordem);
    expect(c.ativo.value, r.ativo);
    expect(c.origem.value, r.origem);
    expect(c.atribuidoPor.value, r.atribuidoPor);
    expect(c.criadoEm.value.isAtSameMomentAs(r.criadoEm), isTrue);
    expect(c.updatedAt.value.isAtSameMomentAs(r.updatedAt), isTrue);
    expect(c.dirty.value, isFalse);
  });

  test('routine_exercise roundtrip (exId identidade) preserva grupo', () async {
    await db.routineDao.upsert(
      RoutinesCompanion.insert(id: 'r1', userId: 'u1', nome: 'A'),
    );
    await db.routineDao.upsertExercise(
      RoutineExercisesCompanion.insert(
        id: 're1',
        routineId: 'r1',
        exerciseId: 'seed:supino',
        ordem: const Value(3),
        seriesPlanejadas: const Value('[{"reps":10}]'),
        grupoId: const Value('g1'),
        grupoTipo: const Value('bi_set'),
        rounds: const Value(4),
      ),
    );
    final re = (await db.routineDao.exercisesOf('r1')).single;

    final c = routineExerciseFromJson(routineExerciseToJson(re), ident);

    expect(c.id.value, re.id);
    expect(c.routineId.value, re.routineId);
    expect(c.exerciseId.value, re.exerciseId);
    expect(c.ordem.value, re.ordem);
    expect(c.seriesPlanejadas.value, re.seriesPlanejadas);
    expect(c.grupoId.value, re.grupoId);
    expect(c.grupoTipo.value, re.grupoTipo);
    expect(c.rounds.value, re.rounds);
  });

  test('session roundtrip preserva campos', () async {
    await db.sessionDao.upsert(
      WorkoutSessionsCompanion.insert(
        id: 's1',
        userId: 'u1',
        sentimento: const Value(4),
        notas: const Value('puxado'),
      ),
    );
    final s = (await db.sessionDao.findById('s1'))!;

    final c = sessionFromJson(sessionToJson(s));

    expect(c.id.value, s.id);
    expect(c.userId.value, s.userId);
    expect(c.sentimento.value, s.sentimento);
    expect(c.notas.value, s.notas);
    expect(c.iniciadoEm.value.isAtSameMomentAs(s.iniciadoEm), isTrue);
  });

  test('set_log roundtrip preserva carga, duracao e substituido', () async {
    await db.sessionDao.upsert(
      WorkoutSessionsCompanion.insert(id: 's1', userId: 'u1'),
    );
    await db.setLogDao.upsert(
      SetLogsCompanion.insert(
        id: 'l1',
        sessionId: 's1',
        exerciseId: 'seed:supino',
        ordemNoTreino: 1,
        numeroSerie: 2,
        cargaKg: const Value(80.5),
        duracaoSegundos: const Value(45),
        substituidoDeExerciseId: const Value('seed:crucifixo'),
      ),
    );
    final l = (await db.setLogDao.ofSession('s1')).single;

    final c = setLogFromJson(setLogToJson(l), ident);

    expect(c.id.value, l.id);
    expect(c.exerciseId.value, l.exerciseId);
    expect(c.cargaKg.value, l.cargaKg);
    expect(c.duracaoSegundos.value, l.duracaoSegundos);
    expect(c.substituidoDeExerciseId.value, l.substituidoDeExerciseId);
  });

  test('cardio roundtrip preserva distancia e fc', () async {
    await db.cardioDao.upsert(
      CardioSessionsCompanion.insert(
        id: 'c1',
        userId: 'u1',
        modalidade: 'corrida',
        duracaoMinutos: 40,
        distanciaKm: const Value(8.2),
        fcMedia: const Value(150),
        fcMax: const Value(178),
      ),
    );
    final c0 = (await db.cardioDao.watchByUser('u1').first).single;

    final c = cardioFromJson(cardioToJson(c0));

    expect(c.id.value, c0.id);
    expect(c.modalidade.value, c0.modalidade);
    expect(c.duracaoMinutos.value, c0.duracaoMinutos);
    expect(c.distanciaKm.value, c0.distanciaKm);
    expect(c.fcMedia.value, c0.fcMedia);
    expect(c.fcMax.value, c0.fcMax);
  });
}
