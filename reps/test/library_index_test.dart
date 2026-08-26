import 'package:flutter_test/flutter_test.dart';
import 'package:reps/domain/entities/exercise.dart';
import 'package:reps/features/library/data/exercises_seed.dart';
import 'package:reps/features/library/data/library_repository.dart';

void main() {
  // findBySlug usa rootBundle indiretamente apenas via ensureLoaded; o indice
  // em si e puro. Inicializa o binding para o teste de ensureLoaded.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LibraryRepository.findBySlug (indice memoizado)', () {
    test('slug de seed conhecido retorna o Exercise certo', () {
      final repo = LibraryRepository();
      final seedSlug = exercisesSeed.first.slug; // 'supino_reto_barra'
      final found = repo.findBySlug(seedSlug);

      expect(found, isNotNull);
      expect(found!.slug, seedSlug);
      expect(found.nome, exercisesSeed.first.nome);
      // Exercicios de seed viram id 'seed:<slug>'.
      expect(found.id, 'seed:$seedSlug');
    });

    test('slug inexistente retorna null', () {
      final repo = LibraryRepository();
      expect(repo.findBySlug('__nao_existe__'), isNull);
    });

    test('slug de custom NAO e encontrado por findBySlug', () {
      final repo = LibraryRepository();
      const customSlug = 'meu_exercicio_custom';
      repo.updateCustom(const [
        Exercise(
          id: 'custom:$customSlug',
          slug: customSlug,
          nome: 'Meu exercicio custom',
          descricao: '',
          grupoPrimario: GrupoMuscular.peito,
          gruposSecundarios: [],
          padraoMovimento: PadraoMovimento.empurrada_horizontal,
          equipamento: Equipamento.peso_corporal,
        ),
      ]);

      // Comportamento preservado: custom fica FORA do findBySlug.
      expect(repo.findBySlug(customSlug), isNull);
      // Mas continua visivel em all().
      expect(all(repo).any((e) => e.slug == customSlug), isTrue);
    });

    test(
      'apos ensureLoaded (extended vazio em teste), seed continua achavel',
      () async {
        final repo = LibraryRepository();
        final seedSlug = exercisesSeed.first.slug;

        await repo.ensureLoaded();

        final found = repo.findBySlug(seedSlug);
        expect(found, isNotNull);
        expect(found!.slug, seedSlug);
      },
    );
  });
}

Iterable<Exercise> all(LibraryRepository repo) => repo.all();
