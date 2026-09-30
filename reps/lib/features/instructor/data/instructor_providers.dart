import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'instructor_api.dart';

/// Fichas de treino de um aluno, por `studentId`.
final studentPlansProvider = FutureProvider.autoDispose
    .family<List<InstructorWorkoutPlan>, String>((ref, studentId) {
      return ref.watch(instructorApiProvider).studentPlans(studentId);
    });

/// Catálogo completo de exercícios (sem arquivados). Busca e filtro por grupo
/// muscular são aplicados em memória no seletor — uma ida à rede por abertura.
final exerciseCatalogProvider =
    FutureProvider.autoDispose<List<CatalogExercise>>((ref) {
      return ref.watch(instructorApiProvider).exercises();
    });
