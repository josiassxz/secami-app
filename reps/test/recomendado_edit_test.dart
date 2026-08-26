// Edição do tipo de série no treino recomendado: a troca via copyWith aplica a
// todas as séries do exercício, preserva o resto e mantém o original imutável.

import 'package:flutter_test/flutter_test.dart';
import 'package:reps/domain/entities/planned_set.dart';
import 'package:reps/features/library/data/library_repository.dart';
import 'package:reps/features/recommender/domain/treino_recomendado.dart';

void main() {
  test('trocar tipo de série via copyWith aplica e preserva o resto', () {
    final ex = LibraryRepository().all().first;
    final original = ExercicioPrescrito(
      exercicio: ex,
      series: const [PlannedSet(numero: 1), PlannedSet(numero: 2)],
      observacao: 'obs',
    );
    final dia = DiaTreino(
      nome: 'A',
      exercicios: [original],
      diasDaSemana: const [1],
    );

    final novasSeries = [
      for (final s in original.series)
        s.copyWith(tipoSerie: TipoSerie.drop_set),
    ];
    final novoDia = dia.copyWith(
      exercicios: [original.copyWith(series: novasSeries)],
    );

    final exEditado = novoDia.exercicios.single;
    expect(
      exEditado.series.every((s) => s.tipoSerie == TipoSerie.drop_set),
      isTrue,
    );
    expect(exEditado.observacao, 'obs'); // preservado
    expect(novoDia.nome, 'A');
    expect(novoDia.diasDaSemana, const [1]);
    // Original permanece imutável (normal).
    expect(dia.exercicios.single.series.first.tipoSerie, TipoSerie.normal);
  });

  test('todo tipo de série tem label e descrição própria', () {
    final descricoes = <String>{};
    for (final t in TipoSerie.values) {
      expect(t.label, isNotEmpty);
      expect(t.descricao.length, greaterThan(20));
      descricoes.add(t.descricao);
    }
    // Explicações individuais (sem repetir entre tipos).
    expect(descricoes.length, TipoSerie.values.length);
  });
}
