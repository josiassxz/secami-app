import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart';
import '../data/history_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: sessionsAsync.when(
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
                      Icons.event_note_outlined,
                      size: 64,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppTheme.space12),
                    Text(
                      'Sem treinos registrados ainda.\n'
                      'Finalize um treino para ver aqui.',
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
          final grouped = _groupByDay(list);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              for (final (i, entry) in grouped.entries.indexed) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    4,
                    i == 0 ? 0 : AppTheme.space24,
                    4,
                    AppTheme.space8,
                  ),
                  child: Text(
                    _dayLabel(entry.key).toUpperCase(),
                    style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                  ),
                ),
                for (final s in entry.value) ...[
                  _SessionCard(session: s, subtitle: _subtitle(s)),
                  const SizedBox(height: AppTheme.space8),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Map<DateTime, List<WorkoutSessionRow>> _groupByDay(
    List<WorkoutSessionRow> all,
  ) {
    final out = <DateTime, List<WorkoutSessionRow>>{};
    for (final s in all) {
      final d = s.iniciadoEm.toLocal();
      final key = DateTime(d.year, d.month, d.day);
      out.putIfAbsent(key, () => []).add(s);
    }
    return out;
  }

  String _dayLabel(DateTime d) {
    final hoje = DateTime.now();
    final isToday =
        d.year == hoje.year && d.month == hoje.month && d.day == hoje.day;
    if (isToday) return 'Hoje';
    final ontem = hoje.subtract(const Duration(days: 1));
    if (d.year == ontem.year && d.month == ontem.month && d.day == ontem.day) {
      return 'Ontem';
    }
    return DateFormat("dd 'de' MMMM, EEEE", 'pt_BR').format(d);
  }

  String _subtitle(WorkoutSessionRow s) {
    final iniciou = DateFormat('HH:mm').format(s.iniciadoEm.toLocal());
    if (s.finalizadoEm == null) {
      return 'Iniciado $iniciou - sem finalizar';
    }
    final dur = Duration(seconds: s.duracaoTotalSegundos ?? 0);
    final min = dur.inMinutes;
    return 'Iniciado $iniciou · ${min}min';
  }
}

/// Card de sessão do histórico. Ícone de status (concluído vs. em andamento)
/// dá o contexto visual antes mesmo de ler o texto — hierarquia em 3s.
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.subtitle});

  final WorkoutSessionRow session;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final finalizado = session.finalizadoEm != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/history/${session.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space16,
            vertical: AppTheme.space12,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: finalizado
                      ? scheme.primaryContainer
                      : scheme.secondaryContainer,
                ),
                child: Icon(
                  finalizado ? Icons.check_rounded : Icons.timelapse_rounded,
                  size: 20,
                  color: finalizado
                      ? scheme.onPrimaryContainer
                      : scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      finalizado ? 'Treino' : 'Em andamento',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
