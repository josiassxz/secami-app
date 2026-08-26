import 'package:flutter_test/flutter_test.dart';

import 'package:reps/features/library/data/library_repository.dart';
import 'package:reps/domain/entities/exercise.dart';

void main() {
  group('LibraryRepository', () {
    final repo = LibraryRepository();

    test(
      'exporta os 100 exercicios canonicos (extended opcional, vazio em test)',
      () {
        // Em test rootBundle nao tem o asset; conta apenas os canonicos.
        expect(repo.all().length, greaterThanOrEqualTo(100));
      },
    );

    test('todos os exercicios tem slug nao vazio e unico', () {
      final all = repo.all();
      final slugs = <String>{};
      for (final e in all) {
        expect(e.slug, isNotEmpty);
        expect(slugs.add(e.slug), isTrue, reason: 'slug duplicado: ${e.slug}');
      }
    });

    test('busca por termo filtra por nome', () {
      final results = repo.search(termo: 'supino');
      expect(results, isNotEmpty);
      for (final e in results) {
        final hay = (e.nome + e.descricao).toLowerCase();
        expect(hay.contains('supino'), isTrue);
      }
    });

    test('filtro por grupo muscular respeita selecao', () {
      final results = repo.search(grupos: {GrupoMuscular.peito});
      expect(results, isNotEmpty);
      for (final e in results) {
        expect(e.grupoPrimario, GrupoMuscular.peito);
      }
    });

    test('cobre os 10 grupos musculares principais', () {
      final all = repo.all();
      for (final g in GrupoMuscular.values) {
        expect(
          all.any((e) => e.grupoPrimario == g),
          isTrue,
          reason: 'falta exercicio para ${g.name}',
        );
      }
    });

    test('findBySlug retorna o exercicio correto', () {
      final e = repo.findBySlug('supino_reto_barra');
      expect(e, isNotNull);
      expect(e!.nome.toLowerCase().contains('supino reto'), isTrue);
    });
  });
}
