import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../data/local/daos/custom_exercise_dao.dart';
import '../../../data/local/database.dart';
import '../../../domain/entities/exercise.dart';
import 'library_repository.dart';

final customExerciseDaoProvider = Provider<CustomExerciseDao>((ref) {
  return ref.watch(appDatabaseProvider).customExerciseDao;
});

final customExercisesStreamProvider = StreamProvider<List<CustomExerciseRow>>((
  ref,
) {
  return ref.watch(customExerciseDaoProvider).watchAll();
});

/// Sincroniza o stream de exercicios personalizados com o LibraryRepository
/// em memoria. Retorna o numero de exercicios customizados (muda quando a
/// lista muda, forcando rebuild nos consumers que assistem este provider).
final customExercisesSyncProvider = Provider<int>((ref) {
  final rows =
      ref.watch(customExercisesStreamProvider).asData?.value ?? const [];
  final repo = ref.watch(libraryRepositoryProvider);
  final exercises = rows
      .map(
        (r) => Exercise(
          id: 'custom:${r.id}',
          slug: r.id,
          nome: r.nome,
          descricao: r.descricao,
          grupoPrimario:
              GrupoMuscular.fromString(r.grupoPrimario) ?? GrupoMuscular.core,
          gruposSecundarios: const [],
          padraoMovimento:
              PadraoMovimento.fromString(r.padraoMovimento) ??
              PadraoMovimento.isolador,
          equipamento:
              Equipamento.fromString(r.equipamento) ??
              Equipamento.peso_corporal,
        ),
      )
      .toList();
  repo.updateCustom(exercises);
  return exercises.length;
});

class CustomExerciseService {
  CustomExerciseService(this._dao);

  final CustomExerciseDao _dao;

  Future<void> save({
    String? id,
    required String nome,
    required String descricao,
    required GrupoMuscular grupoPrimario,
    required PadraoMovimento padraoMovimento,
    required Equipamento equipamento,
  }) {
    final resolvedId = id ?? const Uuid().v4();
    return _dao.upsert(
      CustomExercisesCompanion.insert(
        id: resolvedId,
        nome: nome,
        descricao: Value(descricao),
        grupoPrimario: grupoPrimario.name,
        padraoMovimento: padraoMovimento.name,
        equipamento: equipamento.name,
      ),
    );
  }

  Future<void> archive(String id) => _dao.archive(id);
}

final customExerciseServiceProvider = Provider<CustomExerciseService>((ref) {
  return CustomExerciseService(ref.watch(customExerciseDaoProvider));
});
