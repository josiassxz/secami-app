import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/coach_providers.dart';
import '../data/coach_repository.dart';
import '../domain/coach_models.dart';
import 'coach_widgets.dart';

/// Detalhe de um aluno (lado professor): evolucao (read-only) e treinos.
class AlunoDetalheScreen extends ConsumerWidget {
  const AlunoDetalheScreen({
    super.key,
    required this.alunoId,
    required this.alunoNome,
  });

  final String alunoId;
  final String alunoNome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(alunoNome),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Evolução'),
              Tab(text: 'Treinos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _EvolucaoTab(alunoId: alunoId),
            _TreinosTab(alunoId: alunoId, alunoNome: alunoNome),
          ],
        ),
      ),
    );
  }
}

class _EvolucaoTab extends ConsumerWidget {
  const _EvolucaoTab({required this.alunoId});
  final String alunoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evo = ref.watch(evolucaoAlunoProvider(alunoId));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(evolucaoAlunoProvider(alunoId)),
      child: coachSwitcher(
        stateKey: evo.when(
          loading: () => 'loading',
          error: (_, _) => 'error',
          data: (e) => e.vazio ? 'empty' : 'data',
        ),
        child: evo.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => coachCenteredList(
            CoachErrorBox(
              mensagem: e is CoachException ? e.mensagem : 'Erro ao carregar.',
              onRetry: () => ref.invalidate(evolucaoAlunoProvider(alunoId)),
            ),
          ),
          data: (evo) {
            if (evo.vazio) {
              return coachCenteredList(
                const CoachEmptyBox(
                  icone: Icons.show_chart,
                  texto:
                      'Sem treinos registrados nos últimos 30 dias.\n'
                      'A evolução aparece conforme o aluno treina.',
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(AppTheme.space16),
              children: [
                _StatsRow(evo: evo),
                const SizedBox(height: AppTheme.space24),
                if (evo.volumePorGrupo.isNotEmpty) ...[
                  const _SectionLabel('Volume por grupo (30 dias)'),
                  const SizedBox(height: AppTheme.space12),
                  _VolumeBars(volume: evo.volumePorGrupo),
                  const SizedBox(height: AppTheme.space24),
                ],
                const _SectionLabel('Últimas sessões'),
                const SizedBox(height: AppTheme.space12),
                for (final s in evo.ultimasSessoes) _SessaoTile(sessao: s),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Rotulo de secao consistente (Title, §3 do design system).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(texto, style: Theme.of(context).textTheme.titleSmall);
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.evo});
  final EvolucaoAluno evo;

  @override
  Widget build(BuildContext context) {
    final ultima = evo.ultimaSessao;
    return Row(
      children: [
        _StatCard(valor: '${evo.sessoes30d}', rotulo: 'Sessões (30d)'),
        const SizedBox(width: AppTheme.space12),
        _StatCard(valor: '${evo.series30d}', rotulo: 'Séries (30d)'),
        const SizedBox(width: AppTheme.space12),
        _StatCard(
          valor: ultima != null
              ? DateFormat('dd/MM').format(ultima.toLocal())
              : '—',
          rotulo: 'Último treino',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.valor, required this.rotulo});
  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.space16,
            horizontal: AppTheme.space8,
          ),
          child: Column(
            children: [
              Text(
                valor,
                style: AppTheme.mono(
                  20,
                  weight: FontWeight.w700,
                ).copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: AppTheme.space4),
              Text(
                rotulo,
                textAlign: TextAlign.center,
                style: AppTheme.label(11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumeBars extends StatelessWidget {
  const _VolumeBars({required this.volume});
  final Map<String, double> volume;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = volume.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVol = entries.first.value;
    final fmt = NumberFormat.decimalPattern('pt_BR');
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space8),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    _rotuloGrupo(e.key),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: maxVol > 0
                            ? (e.value / maxVol).clamp(0.0, 1.0)
                            : 0,
                      ),
                      duration: AppTheme.motionSlow,
                      curve: AppTheme.easingStandard,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 18,
                        color: scheme.primary,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  '${fmt.format(e.value.round())} kg',
                  style: AppTheme.mono(
                    12,
                  ).copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _rotuloGrupo(String g) =>
      g.isEmpty ? g : g[0].toUpperCase() + g.substring(1);
}

class _SessaoTile extends StatelessWidget {
  const _SessaoTile({required this.sessao});
  final SessaoResumo sessao;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dur = sessao.duracaoSegundos;
    final subtitle = dur != null
        ? '${(dur / 60).round()} min'
        : (sessao.finalizada ? 'Concluída' : 'Em andamento');
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: const Icon(Icons.event_available_outlined, size: 20),
        ),
        title: Text(
          DateFormat(
            "EEE, dd 'de' MMM",
            'pt_BR',
          ).format(sessao.iniciadoEm.toLocal()),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _TreinosTab extends ConsumerWidget {
  const _TreinosTab({required this.alunoId, required this.alunoNome});
  final String alunoId;
  final String alunoNome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atribuidas = ref.watch(rotinasAtribuidasProvider(alunoId));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(rotinasAtribuidasProvider(alunoId)),
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.space16),
        children: [
          Row(
            children: [
              const Expanded(child: _SectionLabel('Treinos atribuídos')),
              FilledButton.icon(
                onPressed: () => context.push(
                  '/coach/aluno/$alunoId/atribuir',
                  extra: alunoNome,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Atribuir'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          coachSwitcher(
            stateKey: atribuidas.when(
              loading: () => 'loading',
              error: (_, _) => 'error',
              data: (l) => l.isEmpty ? 'empty' : 'data-${l.length}',
            ),
            child: atribuidas.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppTheme.space24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => CoachErrorBox(
                mensagem: e is CoachException
                    ? e.mensagem
                    : 'Erro ao carregar.',
                onRetry: () =>
                    ref.invalidate(rotinasAtribuidasProvider(alunoId)),
              ),
              data: (lista) {
                if (lista.isEmpty) {
                  return const CoachEmptyBox(
                    icone: Icons.assignment_outlined,
                    texto: 'Nenhum treino atribuído ainda.',
                  );
                }
                return Column(
                  children: [
                    for (final r in lista)
                      Card(
                        margin: const EdgeInsets.only(bottom: AppTheme.space8),
                        child: ListTile(
                          leading: Icon(
                            Icons.assignment_turned_in,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(r.nome),
                          subtitle: Text(
                            r.tipo == 'fixo' ? 'Treino fixo' : 'Avulso',
                          ),
                          trailing: r.ativo
                              ? null
                              : const Chip(label: Text('Inativo')),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
