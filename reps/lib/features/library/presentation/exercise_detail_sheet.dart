import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/exercise.dart';
import 'exercise_thumb.dart';

class ExerciseDetailSheet extends StatelessWidget {
  const ExerciseDetailSheet({required this.exercise, super.key});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, controller) {
        return SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ExerciseThumb(
                  exercise: exercise,
                  size: media.width * 0.7,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                exercise.nome,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(exercise.descricao),
              const SizedBox(height: 16),
              _TagSection(
                label: 'Grupo primario',
                tags: [exercise.grupoPrimario.label],
              ),
              if (exercise.gruposSecundarios.isNotEmpty)
                _TagSection(
                  label: 'Auxiliares',
                  tags: exercise.gruposSecundarios.map((g) => g.label).toList(),
                ),
              _TagSection(
                label: 'Padrao de movimento',
                tags: [exercise.padraoMovimento.label],
              ),
              _TagSection(
                label: 'Equipamento',
                tags: [exercise.equipamento.label],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/exercise/seed:${exercise.slug}');
                },
                icon: const Icon(Icons.show_chart),
                label: const Text('Ver historico e graficos'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({required this.label, required this.tags});

  final String label;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: tags.map((t) => Chip(label: Text(t))).toList(),
          ),
        ],
      ),
    );
  }
}
