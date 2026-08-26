import 'package:flutter_test/flutter_test.dart';
import 'package:reps/domain/usecases/substitute_exercise.dart';
import 'package:reps/features/library/data/library_repository.dart';

void main() {
  final repo = LibraryRepository();
  // Sem historico: lastCarga retorna null para todo mundo.
  final useCase = SubstituteExerciseUseCase(repo, (_) async => null);

  test('substituicoes mantem padrao de movimento e grupo primario', () async {
    final supino = repo.findBySlug('supino_reto_barra')!;
    final results = await useCase.find(supino);
    expect(results, isNotEmpty);
    expect(results.length, lessThanOrEqualTo(5));
    for (final c in results) {
      expect(c.exercise.padraoMovimento, supino.padraoMovimento);
      expect(c.exercise.grupoPrimario, supino.grupoPrimario);
      expect(c.exercise.id, isNot(supino.id));
    }
  });

  test(
    'substituicoes priorizam mesmo equipamento quando sem historico',
    () async {
      final supino = repo.findBySlug('supino_reto_barra')!;
      final results = await useCase.find(supino);
      if (results.length >= 2) {
        // Mesmo equipamento aparece antes de "qualquer equipamento"
        // (score 1 < score 2)
        expect(results.first.score, lessThanOrEqualTo(results.last.score));
      }
    },
  );
}
