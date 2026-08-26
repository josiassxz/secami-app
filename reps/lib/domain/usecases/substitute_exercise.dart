import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_providers.dart';
import '../../features/library/data/library_repository.dart';
import '../entities/exercise.dart';

class SubstitutionCandidate {
  const SubstitutionCandidate({
    required this.exercise,
    required this.score,
    required this.ultimaCargaKg,
  });

  final Exercise exercise;
  final int score; // mais baixo = melhor
  final double? ultimaCargaKg;
}

/// Encontra de 3 a 5 alternativas para o exercicio dado.
/// Ordem:
///   1) Mesmo padrao + mesmo grupo + ja tem historico do usuario (carga conhecida)
///   2) Mesmo padrao + mesmo grupo + mesmo equipamento
///   3) Mesmo padrao + mesmo grupo + qualquer equipamento
class SubstituteExerciseUseCase {
  SubstituteExerciseUseCase(this._repo, this._lastCargaProvider);

  final LibraryRepository _repo;
  final Future<double?> Function(String exerciseId) _lastCargaProvider;

  Future<List<SubstitutionCandidate>> find(Exercise original) async {
    final candidates = _repo.all().where(
      (e) =>
          e.id != original.id &&
          e.padraoMovimento == original.padraoMovimento &&
          e.grupoPrimario == original.grupoPrimario,
    );

    final result = <SubstitutionCandidate>[];
    for (final c in candidates) {
      final carga = await _lastCargaProvider(c.id);
      int score;
      if (carga != null) {
        score = 0;
      } else if (c.equipamento == original.equipamento) {
        score = 1;
      } else {
        score = 2;
      }
      result.add(
        SubstitutionCandidate(exercise: c, score: score, ultimaCargaKg: carga),
      );
    }
    result.sort((a, b) => a.score.compareTo(b.score));
    return result.take(5).toList();
  }
}

final substituteExerciseProvider = Provider<SubstituteExerciseUseCase>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  final db = ref.watch(appDatabaseProvider);
  Future<double?> lastCarga(String exerciseId) async {
    final logs = await db.setLogDao.ofExercise(exerciseId, limit: 1);
    if (logs.isEmpty) return null;
    return logs.first.cargaKg;
  }

  return SubstituteExerciseUseCase(repo, lastCarga);
});
