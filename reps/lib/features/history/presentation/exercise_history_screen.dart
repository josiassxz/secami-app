import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/units/weight_unit.dart';
import '../../../data/local/database.dart';
import '../../../domain/entities/exercise_id.dart';
import '../../../domain/usecases/one_rm.dart';
import '../../library/data/library_repository.dart';
import '../../settings/data/settings_providers.dart';
import '../data/history_providers.dart';

class ExerciseHistoryScreen extends ConsumerWidget {
  const ExerciseHistoryScreen({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(libraryRepositoryProvider);
    final exercise = repo.findBySlug(ExerciseId.parse(exerciseId).librarySlug);
    final logsAsync = ref.watch(setLogsOfExerciseProvider(exerciseId));
    final unit = ref.watch(weightUnitProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(exercise?.nome ?? 'Exercício')),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bar_chart_outlined,
                      size: 64,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sem histórico para este exercício ainda.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final stats = _Stats.from(logs, unit);
          final fmt = DateFormat('dd/MM');

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // 1RM em destaque
              if (stats.estimatedOneRm != null) ...[
                const _SectionHeader('1RM ESTIMADO (EPLEY)'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: scheme.outline),
                    boxShadow: AppTheme.cardShadow(scheme),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        unit.format(stats.estimatedOneRm!),
                        style: AppTheme.mono(
                          40,
                          weight: FontWeight.w800,
                        ).copyWith(color: scheme.primary, height: 1),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          unit.suffix,
                          style: AppTheme.label(
                            13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${stats.sessions} sessões',
                        style: AppTheme.label(
                          11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Gráfico carga máxima
              if (stats.cargaMaxPorSessao.length >= 2) ...[
                _SectionHeader(
                  'CARGA MÁXIMA POR SESSÃO (${unit.suffix.toUpperCase()})',
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: _LineChart(
                    points: stats.cargaMaxPorSessao,
                    datas: stats.datas,
                    unitSuffix: unit.suffix,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Gráfico volume
              if (stats.volumePorSessao.length >= 2) ...[
                _SectionHeader(
                  'VOLUME TOTAL POR SESSÃO (${unit.suffix.toUpperCase()}·REP)',
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: _LineChart(
                    points: stats.volumePorSessao,
                    datas: stats.datas,
                    unitSuffix: '${unit.suffix}·rep',
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Últimas séries
              const _SectionHeader('ÚLTIMAS SÉRIES'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: scheme.outline),
                  boxShadow: AppTheme.cardShadow(scheme),
                ),
                child: Column(
                  children: [
                    for (final (i, l) in logs.take(15).indexed) ...[
                      if (i > 0)
                        Divider(height: 1, color: scheme.outlineVariant),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space16,
                          vertical: AppTheme.space12,
                        ),
                        child: Row(
                          children: [
                            Text(
                              fmt.format(l.criadoEm.toLocal()),
                              style: AppTheme.mono(
                                11,
                              ).copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              unit.format(l.cargaKg ?? 0),
                              style: AppTheme.mono(
                                15,
                                weight: FontWeight.w700,
                              ).copyWith(color: scheme.onSurface),
                            ),
                            Text(
                              ' ${unit.suffix}',
                              style: AppTheme.label(
                                11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '× ${l.repsRealizadas ?? 0} reps',
                              style: AppTheme.label(
                                13,
                              ).copyWith(color: scheme.onSurface),
                            ),
                            const Spacer(),
                            if (l.rpe != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSm,
                                  ),
                                ),
                                child: Text(
                                  'E${l.rpe}',
                                  style: AppTheme.mono(
                                    11,
                                  ).copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.label(
        11,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.points,
    required this.datas,
    required this.unitSuffix,
  });

  final List<double> points;
  final List<DateTime> datas;
  final String unitSuffix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd/MM');

    final spots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i]),
    ];
    final minY = points.reduce((a, b) => a < b ? a : b);
    final maxY = points.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.15;

    return LineChart(
      LineChartData(
        minY: (minY - pad).clamp(0, double.infinity).toDouble(),
        maxY: maxY + pad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: scheme.outlineVariant, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, _) => Text(
                value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
                style: AppTheme.mono(
                  10,
                ).copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (points.length / 4).ceilToDouble().clamp(
                1,
                double.infinity,
              ),
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= datas.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    fmt.format(datas[i]),
                    style: AppTheme.mono(
                      10,
                    ).copyWith(color: scheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.surfaceContainerHighest,
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    '${s.y.toStringAsFixed(1)} $unitSuffix',
                    AppTheme.mono(
                      13,
                      weight: FontWeight.w700,
                    ).copyWith(color: scheme.onSurface),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: scheme.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, xc, bar, idx) => FlDotCirclePainter(
                radius: idx == spots.length - 1 ? 4 : 3,
                color: scheme.primary,
                strokeColor: scheme.surface,
                strokeWidth: 1.5,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primary.withValues(alpha: 0.18),
                  scheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stats {
  _Stats({
    required this.cargaMaxPorSessao,
    required this.volumePorSessao,
    required this.datas,
    required this.estimatedOneRm,
    required this.sessions,
  });

  final List<double> cargaMaxPorSessao;
  final List<double> volumePorSessao;
  final List<DateTime> datas;
  final double? estimatedOneRm;
  final int sessions;

  static _Stats from(List<SetLogRow> logs, WeightUnit unit) {
    final bySession = <String, List<SetLogRow>>{};
    final order = <String>[];
    final sortedAsc = [...logs]
      ..sort((a, b) => a.criadoEm.compareTo(b.criadoEm));
    for (final l in sortedAsc) {
      if (!bySession.containsKey(l.sessionId)) {
        bySession[l.sessionId] = [];
        order.add(l.sessionId);
      }
      bySession[l.sessionId]!.add(l);
    }

    final cargaMax = <double>[];
    final volume = <double>[];
    final datas = <DateTime>[];
    double? best;

    for (final id in order) {
      final group = bySession[id]!;
      var maxC = 0.0;
      var vol = 0.0;
      for (final l in group) {
        final c = unit.fromKg(l.cargaKg ?? 0);
        final r = (l.repsRealizadas ?? 0).toDouble();
        if (c > maxC) maxC = c;
        vol += c * r;
        if (c > 0 && r > 0) {
          final est = oneRmEpley(l.cargaKg ?? 0, r);
          if (best == null || est > best) best = est;
        }
      }
      cargaMax.add(maxC);
      volume.add(vol);
      datas.add(group.first.criadoEm.toLocal());
    }

    return _Stats(
      cargaMaxPorSessao: cargaMax,
      volumePorSessao: volume,
      datas: datas,
      estimatedOneRm: best,
      sessions: order.length,
    );
  }
}
