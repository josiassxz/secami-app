import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/exercise_id.dart';
import '../../auth/data/auth_providers.dart';
import '../../library/data/library_repository.dart';
import '../../../domain/entities/exercise.dart';
import '../../../core/network/erro_amigavel.dart';

class _GroupVolume {
  _GroupVolume(this.grupo);

  final GrupoMuscular grupo;
  double volume = 0;
  int series = 0;
}

final weeklyVolumeProvider =
    FutureProvider.autoDispose<
      (Map<GrupoMuscular, _GroupVolume>, Map<GrupoMuscular, _GroupVolume>)
    >((ref) async {
      final db = ref.watch(appDatabaseProvider);
      final repo = ref.watch(libraryRepositoryProvider);
      final userId = ref.watch(effectiveUserIdProvider);

      final now = DateTime.now();
      // Inicio da semana = segunda-feira
      final monday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: (now.weekday - 1)));
      final mondayPrev = monday.subtract(const Duration(days: 7));

      final sessions = await db.sessionDao.watchByUser(userId).first;
      final sessionById = {for (final s in sessions) s.id: s};
      final logs = await db.setLogDao.ofSessions(
        sessions.map((s) => s.id).toList(),
      );

      Map<GrupoMuscular, _GroupVolume> aggregate(DateTime from, DateTime to) {
        final acc = <GrupoMuscular, _GroupVolume>{};
        for (final l in logs) {
          if (!l.executada) continue;
          final sess = sessionById[l.sessionId];
          if (sess == null) continue;
          if (sess.iniciadoEm.isBefore(from) || sess.iniciadoEm.isAfter(to)) {
            continue;
          }
          final slug = ExerciseId.parse(l.exerciseId).librarySlug;
          final ex = repo.findBySlug(slug);
          if (ex == null) continue;
          final agg = acc.putIfAbsent(
            ex.grupoPrimario,
            () => _GroupVolume(ex.grupoPrimario),
          );
          agg.volume += (l.cargaKg ?? 0) * (l.repsRealizadas ?? 0);
          agg.series += 1;
        }
        return acc;
      }

      final atual = aggregate(monday, now);
      final anterior = aggregate(mondayPrev, monday);
      return (atual, anterior);
    });

class WeeklyVolumeScreen extends ConsumerWidget {
  const WeeklyVolumeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTuple = ref.watch(weeklyVolumeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Resumo semanal')),
      body: asyncTuple.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            mensagemDeErro(e, fallback: 'Não foi possível carregar o volume.'),
          ),
        ),
        data: (tuple) {
          final atual = tuple.$1;
          final anterior = tuple.$2;
          final scheme = Theme.of(context).colorScheme;
          if (atual.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bar_chart_outlined,
                      size: 64,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppTheme.space12),
                    Text(
                      'Nenhum treino nesta semana ainda.\n'
                      'Dê play em um treino e volte aqui.',
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
          final maxVolume = atual.values
              .map((v) => v.volume)
              .fold<double>(1, (a, b) => a > b ? a : b);
          final ordered = [...atual.values]
            ..sort((a, b) => b.volume.compareTo(a.volume));

          final totalVolume = atual.values.fold<double>(
            0,
            (a, b) => a + b.volume,
          );
          final totalVolumeAnterior = anterior.values.fold<double>(
            0,
            (a, b) => a + b.volume,
          );
          final totalSeries = atual.values.fold<int>(0, (a, b) => a + b.series);
          final totalDiff = totalVolumeAnterior > 0
              ? ((totalVolume - totalVolumeAnterior) / totalVolumeAnterior) *
                    100
              : null;

          final semAtividade = [
            for (final g in GrupoMuscular.values)
              if (!atual.containsKey(g)) g,
          ];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Número principal grande: volume total da semana. Contexto
              // (séries, período, variação) fica visualmente secundário.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.space20),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: scheme.outline),
                  boxShadow: AppTheme.cardShadow(scheme),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VOLUME TOTAL · SEGUNDA A HOJE',
                      style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          totalVolume.toStringAsFixed(0),
                          style: AppTheme.mono(
                            40,
                            weight: FontWeight.w800,
                          ).copyWith(color: scheme.primary, height: 1),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'kg·rep',
                            style: AppTheme.label(
                              13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (totalDiff != null) ...[
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _DiffPill(value: totalDiff),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      totalSeries == 1
                          ? '1 série registrada'
                          : '$totalSeries séries registradas',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space24),
              Text(
                'POR GRUPO MUSCULAR',
                style: AppTheme.label(11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.space4),
              for (final v in ordered)
                _BarRow(
                  label: v.grupo.label,
                  volume: v.volume,
                  series: v.series,
                  max: maxVolume,
                  diffPct: _diffPct(v, anterior[v.grupo]),
                  scheme: scheme,
                ),
              if (semAtividade.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space24),
                Text(
                  'SEM ATIVIDADE ESTA SEMANA',
                  style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppTheme.space8),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: scheme.outline),
                  ),
                  child: Column(
                    children: [
                      for (final (i, g) in semAtividade.indexed) ...[
                        if (i > 0)
                          Divider(height: 1, color: scheme.outlineVariant),
                        ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.warning_amber_outlined,
                            color: scheme.secondary,
                          ),
                          title: Text('${g.label}: 0 séries esta semana'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.space16),
            ],
          );
        },
      ),
    );
  }

  double? _diffPct(_GroupVolume atual, _GroupVolume? anterior) {
    if (anterior == null || anterior.volume == 0) return null;
    return ((atual.volume - anterior.volume) / anterior.volume) * 100;
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.volume,
    required this.series,
    required this.max,
    required this.diffPct,
    required this.scheme,
  });

  final String label;
  final double volume;
  final int series;
  final double max;
  final double? diffPct;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final ratio = (volume / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                volume.toStringAsFixed(0),
                style: AppTheme.mono(
                  15,
                  weight: FontWeight.w700,
                ).copyWith(color: scheme.onSurface),
              ),
              Text(
                ' kg·rep',
                style: AppTheme.label(10, color: scheme.onSurfaceVariant),
              ),
              if (diffPct != null) ...[
                const SizedBox(width: AppTheme.space8),
                _DiffPill(value: diffPct!),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            series == 1 ? '1 série' : '$series séries',
            style: AppTheme.label(11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.space4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffPill extends StatelessWidget {
  const _DiffPill({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final up = value >= 0;
    // green-400 tem contraste ~4.8:1 sobre surfaceContainer em dark mode.
    // Usar scheme.error para queda preserva o token semântico do tema.
    final color = up
        ? const Color(0xFF4ADE80)
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward : Icons.arrow_downward,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${up ? '+' : ''}${value.toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
