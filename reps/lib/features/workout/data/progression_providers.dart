import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../data/local/database.dart';
import '../../../domain/entities/exercise_id.dart';
import '../../../domain/usecases/progression_engine.dart';
import '../../library/data/library_repository.dart';
import 'workout_controller.dart';

/// Insights do exercicio do slot atual, derivados da sessao anterior:
/// sugestao de progressao + series executadas (mapa numeroSerie -> log).
class ExerciseInsight {
  const ExerciseInsight({
    this.suggestion,
    this.timedSuggestion,
    this.lastByNumero = const {},
  });

  /// Sugestao de carga (exercicio por reps). Null para exercicio por tempo.
  final ProgressionSuggestion? suggestion;

  /// Sugestao de duracao (exercicio por tempo — E6). Null para por reps.
  final TimedProgressionSuggestion? timedSuggestion;
  final Map<int, SetLogRow> lastByNumero;

  bool get isEmpty =>
      suggestion == null && timedSuggestion == null && lastByNumero.isEmpty;
}

final exerciseInsightProvider = FutureProvider.autoDispose<ExerciseInsight>((
  ref,
) async {
  final state = ref.watch(workoutControllerProvider);
  final cur = state?.current;
  if (cur == null) return const ExerciseInsight();

  final repo = ref.watch(libraryRepositoryProvider);
  final slug = ExerciseId.parse(cur.exerciseId).librarySlug;
  final exercise = repo.findBySlug(slug);
  if (exercise == null) return const ExerciseInsight();

  final db = ref.watch(appDatabaseProvider);
  // ofExercise ja filtra executada=true e ordena por criadoEm desc.
  final logs = await db.setLogDao.ofExercise(cur.exerciseId);
  final prior = logs.where((l) => l.sessionId != state!.sessionId).toList();
  if (prior.isEmpty) return const ExerciseInsight();

  final lastSessionId = prior.first.sessionId;
  final lastLogs = prior.where((l) => l.sessionId == lastSessionId).toList();

  final lastByNumero = <int, SetLogRow>{};
  for (final l in lastLogs) {
    lastByNumero[l.numeroSerie] = l;
  }

  final engine = ref.watch(progressionEngineProvider);
  final timed = exercise.medidaPorTempo || cur.planned.porTempo;
  if (timed) {
    final timedSuggestion = engine.suggestTimed(
      planned: cur.planned,
      lastSessionLogs: lastLogs,
    );
    return ExerciseInsight(
      timedSuggestion: timedSuggestion,
      lastByNumero: lastByNumero,
    );
  }

  final suggestion = engine.suggest(
    exercise: exercise,
    planned: cur.planned,
    lastSessionLogs: lastLogs,
  );

  return ExerciseInsight(suggestion: suggestion, lastByNumero: lastByNumero);
});
