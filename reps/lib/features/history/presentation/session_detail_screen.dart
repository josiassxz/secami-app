import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart';
import '../../../domain/entities/exercise_id.dart';
import '../../library/data/library_repository.dart';
import '../data/history_providers.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionByIdProvider(sessionId));
    final logsAsync = ref.watch(setLogsOfSessionProvider(sessionId));
    final repo = ref.watch(libraryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Treino')),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (session) {
          if (session == null) {
            return const Center(child: Text('Sessão não encontrada.'));
          }
          return logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (logs) {
              final byExercise = <String, List<SetLogRow>>{};
              for (final l in logs) {
                byExercise.putIfAbsent(l.exerciseId, () => []).add(l);
              }
              final df = DateFormat("dd/MM 'às' HH:mm");
              final dur = Duration(seconds: session.duracaoTotalSegundos ?? 0);
              final executadas = logs.where((l) => l.executada).length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // Cabeçalho: data como elemento dominante da tela.
                  Text(
                    df.format(session.iniciadoEm.toLocal()),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppTheme.space12),
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.fitness_center_outlined,
                        value: '${byExercise.length}',
                        label: byExercise.length == 1
                            ? 'exercício'
                            : 'exercícios',
                      ),
                      const SizedBox(width: AppTheme.space8),
                      _StatChip(
                        icon: Icons.repeat_rounded,
                        value: '$executadas',
                        label: executadas == 1 ? 'série' : 'séries',
                      ),
                      if (session.finalizadoEm != null) ...[
                        const SizedBox(width: AppTheme.space8),
                        _StatChip(
                          icon: Icons.timer_outlined,
                          value:
                              '${dur.inMinutes}min '
                              '${(dur.inSeconds % 60).toString().padLeft(2, '0')}s',
                          label: null,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppTheme.space24),
                  for (final entry in byExercise.entries) ...[
                    _ExerciseBlock(
                      exerciseId: entry.key,
                      logs: entry.value,
                      nome:
                          repo.findBySlug(_slugFromId(entry.key))?.nome ??
                          entry.key,
                    ),
                    const SizedBox(height: AppTheme.space12),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _slugFromId(String id) => ExerciseId.parse(id).librarySlug;
}

/// Pílula compacta de estatística no cabeçalho (contexto secundário — a data
/// já é o elemento dominante da tela).
class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value, this.label});

  final IconData icon;
  final String value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            value,
            style: AppTheme.mono(
              12,
              weight: FontWeight.w700,
            ).copyWith(color: scheme.onSurface),
          ),
          if (label != null) ...[
            const SizedBox(width: 3),
            Text(
              label!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({
    required this.exerciseId,
    required this.nome,
    required this.logs,
  });

  final String exerciseId;
  final String nome;
  final List<SetLogRow> logs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = [...logs]
      ..sort((a, b) => a.numeroSerie.compareTo(b.numeroSerie));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    nome,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  sorted.length == 1 ? '1 série' : '${sorted.length} séries',
                  style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            Divider(height: 1, color: scheme.outlineVariant),
            for (final l in sorted) _SetRow(log: l),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.log});

  final SetLogRow log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${log.numeroSerie}',
              style: AppTheme.mono(
                11,
                weight: FontWeight.w700,
              ).copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: log.executada
                ? Row(
                    children: [
                      Text(
                        '${log.repsRealizadas ?? 0}',
                        style: AppTheme.mono(
                          15,
                          weight: FontWeight.w700,
                        ).copyWith(color: scheme.onSurface),
                      ),
                      Text(
                        ' reps × ',
                        style: AppTheme.label(
                          12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        (log.cargaKg ?? 0).toStringAsFixed(1),
                        style: AppTheme.mono(
                          15,
                          weight: FontWeight.w700,
                        ).copyWith(color: scheme.onSurface),
                      ),
                      Text(
                        ' kg',
                        style: AppTheme.label(
                          12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.remove_circle_outline,
                        size: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Pulada · ${log.motivoPulo ?? "sem motivo"}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (log.rpe != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                'E${log.rpe}',
                style: AppTheme.mono(
                  11,
                ).copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
