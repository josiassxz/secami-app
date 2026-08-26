import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/exercise_id.dart';
import '../../auth/data/auth_providers.dart';
import '../../library/data/library_repository.dart';

class _RecordRow {
  const _RecordRow({
    required this.exerciseId,
    required this.cargaMax,
    required this.reps,
    required this.data,
  });

  final String exerciseId;
  final double cargaMax;
  final int reps;
  final DateTime data;
}

final recordsProvider = FutureProvider.autoDispose<List<_RecordRow>>((
  ref,
) async {
  final db = ref.watch(appDatabaseProvider);
  final userId = ref.watch(effectiveUserIdProvider);

  // Pega todas as sessoes do user, depois todos os set_logs delas.
  final sessions = await db.sessionDao.watchByUser(userId).first;
  final sessionIds = sessions.map((s) => s.id).toSet();

  final byExercise = <String, _RecordRow>{};
  final logs = await db.setLogDao.ofSessions(sessionIds.toList());
  for (final l in logs) {
    if (!sessionIds.contains(l.sessionId)) continue;
    if (!l.executada) continue;
    final c = l.cargaKg ?? 0;
    final cur = byExercise[l.exerciseId];
    if (cur == null || c > cur.cargaMax) {
      byExercise[l.exerciseId] = _RecordRow(
        exerciseId: l.exerciseId,
        cargaMax: c,
        reps: l.repsRealizadas ?? 0,
        data: l.criadoEm,
      );
    }
  }
  return byExercise.values.toList()
    ..sort((a, b) => b.cargaMax.compareTo(a.cargaMax));
});

class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(libraryRepositoryProvider);
    final asyncList = ref.watch(recordsProvider);
    final scheme = Theme.of(context).colorScheme;
    final df = DateFormat('dd/MM/yy');

    return Scaffold(
      appBar: AppBar(title: const Text('Recordes')),
      body: asyncList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 64,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppTheme.space12),
                    Text(
                      'Sem recordes ainda.\n'
                      'Registre algumas séries para ver seus PRs aqui.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppTheme.space8),
            itemBuilder: (context, i) {
              final r = list[i];
              final slug = ExerciseId.parse(r.exerciseId).librarySlug;
              final ex = repo.findBySlug(slug);
              return _RecordCard(
                nome: ex?.nome ?? r.exerciseId,
                cargaMax: r.cargaMax,
                reps: r.reps,
                dataLabel: df.format(r.data.toLocal()),
                onTap: () => context.push('/exercise/${r.exerciseId}'),
              );
            },
          );
        },
      ),
    );
  }
}

/// Card de recorde pessoal — tratamento de "conquista": selo circular
/// dourado (mesmo papel do token `secondary` em toda a paleta) e o número
/// principal (carga) em fonte monoespaçada pra alinhamento de dígitos.
class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.nome,
    required this.cargaMax,
    required this.reps,
    required this.dataLabel,
    required this.onTap,
  });

  final String nome;
  final double cargaMax;
  final int reps;
  final String dataLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: scheme.onSecondaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          cargaMax.toStringAsFixed(1),
                          style: AppTheme.mono(
                            18,
                            weight: FontWeight.w700,
                          ).copyWith(color: scheme.onSurface),
                        ),
                        Text(
                          ' kg  ×  ',
                          style: AppTheme.label(
                            11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '$reps',
                          style: AppTheme.mono(
                            14,
                            weight: FontWeight.w600,
                          ).copyWith(color: scheme.onSurface),
                        ),
                        Text(
                          ' reps',
                          style: AppTheme.label(
                            11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dataLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
