import 'package:flutter_test/flutter_test.dart';
import 'package:reps/domain/entities/grupo_exercicio.dart';
import 'package:reps/domain/entities/planned_set.dart';
import 'package:reps/features/workout/data/workout_controller.dart';

void main() {
  // idGen deterministico pra facilitar leitura.
  var n = 0;
  String idGen() => 'slot-${n++}';

  setUp(() => n = 0);

  List<PlannedSet> series(int q) => [
    for (var i = 1; i <= q; i++) PlannedSet(numero: i),
  ];

  group('buildActiveSlots — solo (normal)', () {
    test('exercicio solo gera serie a serie', () {
      final slots = buildActiveSlots([
        SlotSpec(id: 'a', exerciseId: 'ex:a', series: series(3)),
        SlotSpec(id: 'b', exerciseId: 'ex:b', series: series(2)),
      ], idGen: idGen);

      expect(slots.length, 5);
      // Todas as series de A, depois todas de B.
      expect(slots.map((s) => s.exerciseId).toList(), [
        'ex:a',
        'ex:a',
        'ex:a',
        'ex:b',
        'ex:b',
      ]);
      expect(slots.every((s) => s.grupoId == null), isTrue);
      // ordemNoTreino = indice absoluto do exercicio.
      expect(slots[0].ordemNoTreino, 0);
      expect(slots[3].ordemNoTreino, 1);
    });

    test('serie vazia vira uma serie default', () {
      final slots = buildActiveSlots([
        const SlotSpec(id: 'a', exerciseId: 'ex:a', series: []),
      ], idGen: idGen);
      expect(slots.length, 1);
      expect(slots.first.numeroSerie, 1);
    });
  });

  group('buildActiveSlots — bi-set', () {
    test('intercala A·s1 B·s1 A·s2 B·s2 A·s3 B·s3', () {
      final slots = buildActiveSlots([
        SlotSpec(
          id: 'a',
          exerciseId: 'ex:a',
          series: series(3),
          grupoId: 'g1',
          grupoTipo: 'bi_set',
        ),
        SlotSpec(
          id: 'b',
          exerciseId: 'ex:b',
          series: series(3),
          grupoId: 'g1',
          grupoTipo: 'bi_set',
        ),
      ], idGen: idGen);

      expect(slots.length, 6);
      expect(slots.map((s) => s.exerciseId).toList(), [
        'ex:a',
        'ex:b',
        'ex:a',
        'ex:b',
        'ex:a',
        'ex:b',
      ]);
      // round alterna por rodada.
      expect(slots.map((s) => s.round).toList(), [0, 0, 1, 1, 2, 2]);
      // ordemNoTreino preserva identidade do exercicio.
      expect(slots.map((s) => s.ordemNoTreino).toList(), [0, 1, 0, 1, 0, 1]);
      expect(slots.every((s) => s.grupoId == 'g1'), isTrue);
    });

    test('rodadas = maior nº de series do grupo', () {
      final slots = buildActiveSlots([
        SlotSpec(
          id: 'a',
          exerciseId: 'ex:a',
          series: series(3),
          grupoId: 'g1',
          grupoTipo: 'bi_set',
        ),
        SlotSpec(
          id: 'b',
          exerciseId: 'ex:b',
          series: series(2),
          grupoId: 'g1',
          grupoTipo: 'bi_set',
        ),
      ], idGen: idGen);
      // 3 rodadas; na 3a so A tem serie.
      expect(slots.map((s) => s.exerciseId).toList(), [
        'ex:a',
        'ex:b',
        'ex:a',
        'ex:b',
        'ex:a',
      ]);
    });
  });

  group('buildActiveSlots — circuito', () {
    test('usa rounds explicito e repete config da ultima serie', () {
      final slots = buildActiveSlots([
        SlotSpec(
          id: 'a',
          exerciseId: 'ex:a',
          series: series(1),
          grupoId: 'g1',
          grupoTipo: 'circuito',
          rounds: 3,
        ),
        SlotSpec(
          id: 'b',
          exerciseId: 'ex:b',
          series: series(1),
          grupoId: 'g1',
          grupoTipo: 'circuito',
          rounds: 3,
        ),
      ], idGen: idGen);

      expect(slots.length, 6); // 3 rodadas x 2 exercicios
      expect(slots.map((s) => s.round).toList(), [0, 0, 1, 1, 2, 2]);
      expect(slots.map((s) => s.numeroSerie).toList(), [1, 1, 2, 2, 3, 3]);
    });
  });

  group('buildActiveSlots — misto', () {
    test('solo + bi-set + solo na mesma rotina', () {
      final slots = buildActiveSlots([
        SlotSpec(id: 'a', exerciseId: 'ex:a', series: series(1)),
        SlotSpec(
          id: 'b',
          exerciseId: 'ex:b',
          series: series(2),
          grupoId: 'g1',
          grupoTipo: 'bi_set',
        ),
        SlotSpec(
          id: 'c',
          exerciseId: 'ex:c',
          series: series(2),
          grupoId: 'g1',
          grupoTipo: 'bi_set',
        ),
        SlotSpec(id: 'd', exerciseId: 'ex:d', series: series(1)),
      ], idGen: idGen);

      expect(slots.map((s) => s.exerciseId).toList(), [
        'ex:a',
        'ex:b',
        'ex:c',
        'ex:b',
        'ex:c',
        'ex:d',
      ]);
      // ordemNoTreino do bloco do meio = 1 e 2; o solo final = 3.
      expect(slots.last.ordemNoTreino, 3);
      expect(slots.last.grupoId, isNull);
    });
  });

  group('slotBlockKey', () {
    test('solo usa ordemNoTreino; grupo usa grupoId', () {
      const solo = ActiveSetSlot(
        id: 'x',
        exerciseId: 'e',
        routineExerciseId: 'r',
        ordemNoTreino: 2,
        numeroSerie: 1,
        planned: PlannedSet(numero: 1),
      );
      const grp = ActiveSetSlot(
        id: 'y',
        exerciseId: 'e',
        routineExerciseId: 'r',
        ordemNoTreino: 0,
        numeroSerie: 1,
        planned: PlannedSet(numero: 1),
        grupoId: 'g1',
      );
      expect(slotBlockKey(solo), 'solo:2');
      expect(slotBlockKey(grp), 'g1');
    });
  });

  test('GrupoTipo.fromString defaulta para normal', () {
    expect(GrupoTipo.fromString('bi_set'), GrupoTipo.bi_set);
    expect(GrupoTipo.fromString('circuito'), GrupoTipo.circuito);
    expect(GrupoTipo.fromString('xxx'), GrupoTipo.normal);
    expect(GrupoTipo.fromString(null), GrupoTipo.normal);
  });
}
