import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/planned_set.dart';
import '../data/recommender_providers.dart';
import '../domain/treino_recomendado.dart';
import 'tipo_serie_sheet.dart';

/// Apresentacao do treino recomendado (RN-043..047). Quando a triagem
/// encaminha, mostra apenas a orientacao (CA-002).
class ResultadoTreinoScreen extends ConsumerStatefulWidget {
  const ResultadoTreinoScreen({super.key, required this.treino});

  final TreinoRecomendado treino;

  @override
  ConsumerState<ResultadoTreinoScreen> createState() =>
      _ResultadoTreinoScreenState();
}

class _ResultadoTreinoScreenState extends ConsumerState<ResultadoTreinoScreen> {
  bool _salvando = false;

  /// Cópia editável do treino recomendado: o usuário pode trocar o tipo de
  /// série de cada exercício antes de salvar como rotina.
  late TreinoRecomendado _treino = widget.treino;

  /// Aplica [tipo] a todas as séries do exercício [exIdx] do dia [diaIdx],
  /// reconstruindo o treino imutável.
  void _mudarTipo(int diaIdx, int exIdx, TipoSerie tipo) {
    final dia = _treino.dias[diaIdx];
    final ex = dia.exercicios[exIdx];
    final novasSeries = [
      for (final s in ex.series) s.copyWith(tipoSerie: tipo),
    ];
    final novosExs = [...dia.exercicios]
      ..[exIdx] = ex.copyWith(series: novasSeries);
    final novosDias = [..._treino.dias]
      ..[diaIdx] = dia.copyWith(exercicios: novosExs);
    setState(() => _treino = _treino.copyWith(dias: novosDias));
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      final ids = await ref
          .read(recommenderServiceProvider)
          .salvarComoRotina(_treino);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length} rotina(s) criada(s).')),
      );
      context.go('/routines');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _treino;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sua recomendacao'),
        actions: [
          if (!t.bloqueado)
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Tipos de série',
              onPressed: () => mostrarAjudaTipoSerie(context),
            ),
        ],
      ),
      body: t.bloqueado ? _bloqueado(context) : _buildTreino(context, t),
      bottomNavigationBar: t.bloqueado
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('SALVAR COMO ROTINA'),
                ),
              ),
            ),
    );
  }

  Widget _bloqueado(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: scheme.error),
            boxShadow: AppTheme.cardShadow(scheme),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.health_and_safety_outlined,
                    color: scheme.error,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Procure avaliacao antes de treinar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.treino.triagem.orientacao,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (widget.treino.alertas.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final a in widget.treino.alertas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $a',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.go('/routines'),
          child: const Text('VOLTAR'),
        ),
      ],
    );
  }

  Widget _buildTreino(BuildContext context, TreinoRecomendado t) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        // Justificativa (RN-044)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: scheme.outline),
            boxShadow: AppTheme.cardShadow(scheme),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'POR QUE ESTE TREINO',
                    style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                t.justificativa,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        // Alertas globais (RN-046)
        if (t.alertas.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: scheme.secondary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final a in t.alertas)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 15,
                          color: scheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            a,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (t.divisao != null)
          Text(
            'DIVISAO: ${t.divisao!.label.toUpperCase()}',
            style: AppTheme.label(11, color: scheme.onSurfaceVariant),
          ),
        const SizedBox(height: 8),
        for (var i = 0; i < t.dias.length; i++) ...[
          _DiaCard(
            dia: t.dias[i],
            index: i + 1,
            onChangeTipo: (exIdx, tipo) => _mudarTipo(i, exIdx, tipo),
          ),
          const SizedBox(height: AppTheme.space12),
        ],
        const SizedBox(height: 8),
        Text(
          'Versao das regras: ${t.versaoRegras}',
          style: AppTheme.label(10, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _DiaCard extends StatelessWidget {
  const _DiaCard({
    required this.dia,
    required this.index,
    required this.onChangeTipo,
  });

  final DiaTreino dia;
  final int index;
  final void Function(int exIdx, TipoSerie tipo) onChangeTipo;

  static const _dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diasTxt = dia.diasDaSemana.map((d) => _dias[d % 7]).join(', ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.outline),
        boxShadow: AppTheme.cardShadow(scheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                index.toString().padLeft(2, '0'),
                style: AppTheme.mono(
                  11,
                  weight: FontWeight.w500,
                ).copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dia.nome,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (diasTxt.isNotEmpty)
                Text(diasTxt, style: AppTheme.label(11, color: scheme.primary)),
            ],
          ),
          const Divider(height: 20),
          for (var ei = 0; ei < dia.exercicios.length; ei++)
            _linhaExercicio(context, dia.exercicios[ei], ei),
        ],
      ),
    );
  }

  Widget _linhaExercicio(BuildContext context, ExercicioPrescrito e, int ei) {
    final scheme = Theme.of(context).colorScheme;
    final s = e.series.isEmpty ? null : e.series.first;
    final resumo = s == null
        ? ''
        : '${e.series.length}x${s.repsAlvoMin}-${s.repsAlvoMax} · '
              '${s.descansoSegundos}s';
    final tipo = s?.tipoSerie ?? TipoSerie.normal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  e.exercicio.nome,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                resumo,
                style: AppTheme.mono(
                  12,
                  weight: FontWeight.w600,
                ).copyWith(color: scheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _chipTipo(context, tipo, ei),
          if (e.observacao != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                e.observacao!,
                style: AppTheme.label(10, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  /// Chip tappável que mostra o tipo de série atual e abre o seletor.
  Widget _chipTipo(BuildContext context, TipoSerie tipo, int ei) {
    final scheme = Theme.of(context).colorScheme;
    final normal = tipo == TipoSerie.normal;
    final cor = normal ? scheme.onSurfaceVariant : scheme.secondary;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        final escolhido = await mostrarSeletorTipoSerie(context, tipo);
        if (escolhido != null && escolhido != tipo) {
          onChangeTipo(ei, escolhido);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tipo.label, style: AppTheme.label(10, color: cor)),
            const SizedBox(width: 3),
            Icon(Icons.expand_more, size: 14, color: cor),
          ],
        ),
      ),
    );
  }
}
