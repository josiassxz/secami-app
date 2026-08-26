import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/observability.dart';
import '../../../domain/entities/exercise_id.dart';
import '../../../domain/usecases/substitute_exercise.dart';
import '../../library/data/library_repository.dart';
import '../../library/presentation/exercise_thumb.dart';
import '../data/workout_controller.dart';

class SubstituteSheet extends ConsumerWidget {
  const SubstituteSheet({required this.originalExerciseId, super.key});

  final String originalExerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(libraryRepositoryProvider);
    final slug = ExerciseId.parse(originalExerciseId).librarySlug;
    final original = repo.findBySlug(slug);

    if (original == null) {
      return const SizedBox.shrink();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, controller) {
        return FutureBuilder<List<SubstitutionCandidate>>(
          future: ref.read(substituteExerciseProvider).find(original),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snap.data ?? const [];
            if (list.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhuma alternativa com este padrao disponivel.',
                  ),
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Substituir ${original.nome}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final cand = list[i];
                      return ListTile(
                        leading: ExerciseThumb(exercise: cand.exercise),
                        title: Text(cand.exercise.nome),
                        subtitle: Text(
                          cand.ultimaCargaKg == null
                              ? cand.exercise.equipamento.label
                              : '${cand.exercise.equipamento.label} · ultima: ${cand.ultimaCargaKg!.toStringAsFixed(1)} kg',
                        ),
                        onTap: () async {
                          await ref
                              .read(workoutControllerProvider.notifier)
                              .substituteCurrent(
                                newExerciseId: cand.exercise.id,
                                cargaAlvo: cand.ultimaCargaKg,
                              );
                          await Observability.track('exercise_substituted', {
                            'from': originalExerciseId,
                            'to': cand.exercise.id,
                          });
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
