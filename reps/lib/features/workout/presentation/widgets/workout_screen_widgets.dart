part of '../workout_screen.dart';

class _GrupoBadge extends StatelessWidget {
  const _GrupoBadge({required this.state, required this.cur});

  final ActiveWorkoutState state;
  final ActiveSetSlot cur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tipo = GrupoTipo.fromString(cur.grupoTipo);
    final totalRodadas = state.slots
        .where((sl) => sl.grupoId == cur.grupoId)
        .map((sl) => sl.round)
        .toSet()
        .length;
    // Quantos exercicios compoem o grupo (para "exercício 1/2 da rodada").
    final membros =
        state.slots
            .where((sl) => sl.grupoId == cur.grupoId)
            .map((sl) => sl.ordemNoTreino)
            .toSet()
            .toList()
          ..sort();
    final posicao = membros.indexOf(cur.ordemNoTreino) + 1;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space8,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppTheme.space8),
          Text(
            '${tipo.label.toUpperCase()} · RODADA ${cur.round + 1}/$totalRodadas'
            ' · EXERCÍCIO $posicao/${membros.length}',
            style: AppTheme.label(10, color: scheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

class _SeriesOverview extends StatelessWidget {
  const _SeriesOverview({
    required this.state,
    required this.unit,
    required this.timed,
  });

  final ActiveWorkoutState state;
  final WeightUnit unit;
  final bool timed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cur = state.current!;
    final sets = state.slots
        .where((sl) => sl.ordemNoTreino == cur.ordemNoTreino)
        .toList();
    // Justificado: os chips dividem a largura por igual (sem scroll).
    return Row(
      children: [
        for (var i = 0; i < sets.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _chip(scheme, cur, sets[i])),
        ],
      ],
    );
  }

  Widget _chip(ColorScheme scheme, ActiveSetSlot cur, ActiveSetSlot sl) {
    final isCurrent = sl.id == cur.id;

    Color border;
    Color bg;
    Color fg;
    if (isCurrent) {
      border = scheme.primary;
      bg = scheme.primary;
      fg = scheme.onPrimary;
    } else if (sl.completed) {
      border = scheme.primary;
      bg = scheme.surfaceContainerLow;
      fg = scheme.onSurface;
    } else if (sl.skipped) {
      border = scheme.outline;
      bg = scheme.surfaceContainerLow;
      fg = scheme.onSurfaceVariant;
    } else {
      border = scheme.outline;
      bg = scheme.surface;
      fg = scheme.onSurfaceVariant;
    }

    String detail;
    if (sl.completed) {
      if (timed) {
        final d = _fmtMmss(sl.duracaoSegundos ?? 0);
        detail = (sl.cargaKg ?? 0) > 0 ? '$d·${unit.format(sl.cargaKg!)}' : d;
      } else {
        detail = '${unit.format(sl.cargaKg ?? 0)}×${sl.repsRealizadas ?? 0}';
      }
    } else if (sl.skipped) {
      detail = '—';
    } else {
      detail = timed
          ? _fmtMmss(sl.planned.duracaoAlvoSegundos ?? 45)
          : '${sl.planned.repsAlvoMin}–${sl.planned.repsAlvoMax}';
    }

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space8,
        vertical: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: border, width: isCurrent ? 1.5 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('S${sl.numeroSerie}', style: AppTheme.label(11, color: fg)),
          const SizedBox(height: AppTheme.space4),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.mono(
              13,
              weight: FontWeight.w700,
            ).copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Visao de lista do treino inteiro (alternavel com o modo foco).
/// Um cartao por exercicio, com as series e seus estados. Tocar numa serie
/// move o cursor para ela e volta ao modo foco (serie feita reabre em edicao).
class _WorkoutListView extends ConsumerWidget {
  const _WorkoutListView({
    required this.state,
    required this.unit,
    required this.onTapSlot,
  });

  final ActiveWorkoutState state;
  final WeightUnit unit;
  final ValueChanged<String> onTapSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.watch(libraryRepositoryProvider);
    // Agrupa por exercicio (ordemNoTreino) preservando a ordem de aparicao.
    // Em bi-set/circuito os slots intercalam; o cartao junta todos do mesmo
    // exercicio.
    final ordens = <int>[];
    final porOrdem = <int, List<ActiveSetSlot>>{};
    for (final sl in state.slots) {
      porOrdem
          .putIfAbsent(sl.ordemNoTreino, () {
            ordens.add(sl.ordemNoTreino);
            return [];
          })
          .add(sl);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: ordens.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final sets = porOrdem[ordens[i]]!;
        final first = sets.first;
        final exercise = repo.findBySlug(
          ExerciseId.parse(first.exerciseId).librarySlug,
        );
        final timed =
            (exercise?.medidaPorTempo ?? false) || first.planned.porTempo;
        final feitas = sets.where((sl) => sl.completed).length;
        final isCurrentEx = state.current?.ordemNoTreino == first.ordemNoTreino;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isCurrentEx ? scheme.primary : scheme.outline,
              width: isCurrentEx ? 1.5 : 1,
            ),
            boxShadow: AppTheme.cardShadow(scheme),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (exercise != null) ...[
                    ExerciseThumb(
                      exercise: exercise,
                      size: 40,
                      expandable: true,
                    ),
                    const SizedBox(width: AppTheme.space12),
                  ],
                  Expanded(
                    child: Text(
                      exercise?.nome ?? 'Exercício',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$feitas/${sets.length}',
                    style: AppTheme.mono(
                      12,
                    ).copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space8),
              for (final sl in sets) _setRow(context, scheme, sl, timed),
            ],
          ),
        );
      },
    );
  }

  Widget _setRow(
    BuildContext context,
    ColorScheme scheme,
    ActiveSetSlot sl,
    bool timed,
  ) {
    final isCurrent = state.current?.id == sl.id;
    final IconData icon;
    final Color color;
    if (isCurrent) {
      icon = Icons.play_arrow;
      color = scheme.primary;
    } else if (sl.completed) {
      icon = Icons.check_circle;
      color = scheme.primary;
    } else if (sl.skipped) {
      icon = Icons.remove_circle_outline;
      color = scheme.onSurfaceVariant;
    } else {
      icon = Icons.radio_button_unchecked;
      color = scheme.onSurfaceVariant;
    }

    final String detail;
    if (sl.completed) {
      detail = timed
          ? _fmtMmss(sl.duracaoSegundos ?? 0)
          : '${unit.format(sl.cargaKg ?? 0)} ${unit.suffix} × '
                '${sl.repsRealizadas ?? 0}';
    } else if (sl.skipped) {
      detail = 'pulada';
    } else {
      detail = timed
          ? 'alvo ${_fmtMmss(sl.planned.duracaoAlvoSegundos ?? 45)}'
          : 'alvo ${sl.planned.repsAlvoMin}–${sl.planned.repsAlvoMax}';
    }

    return InkWell(
      onTap: () => onTapSlot(sl.id),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppTheme.space12),
            Text(
              'S${sl.numeroSerie}',
              style: AppTheme.label(
                11,
                color: isCurrent ? scheme.primary : scheme.onSurface,
              ),
            ),
            if (sl.planned.aquecimento) ...[
              const SizedBox(width: 8),
              Text(
                'AQ',
                style: AppTheme.label(9, color: scheme.onSurfaceVariant),
              ),
            ],
            const Spacer(),
            Text(
              detail,
              style: AppTheme.mono(12, weight: FontWeight.w600).copyWith(
                color: sl.completed
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressionCard extends ConsumerWidget {
  const _ProgressionCard({required this.unit, required this.onApply});

  final WeightUnit unit;
  final ValueChanged<double> onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(exerciseInsightProvider).asData?.value;
    final timed = insight?.timedSuggestion;
    if (timed != null) return _buildTimed(context, timed);
    final sug = insight?.suggestion;
    if (sug == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    final (IconData icon, Color color, String verbo) = switch (sug.decision) {
      ProgressionDecision.aumentar => (
        Icons.arrow_upward,
        scheme.primary,
        'AUMENTAR',
      ),
      ProgressionDecision.manter => (
        Icons.arrow_forward,
        scheme.onSurfaceVariant,
        'MANTER',
      ),
      ProgressionDecision.reduzir => (
        Icons.arrow_downward,
        scheme.error,
        'REDUZIR',
      ),
    };

    final carga = unit.format(sug.cargaSugerida);
    // delta e variacao de carga; converte de kg para a unidade exibida.
    final deltaDisp = unit.fromKg(sug.delta);
    final deltaTxt = sug.delta == 0
        ? null
        : '${deltaDisp > 0 ? '+' : ''}'
              '${deltaDisp.toStringAsFixed(1)} ${unit.suffix}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => onApply(sug.cargaSugerida),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: color),
            boxShadow: AppTheme.cardShadow(scheme),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROGRESSÃO · $verbo',
                      style: AppTheme.label(11, color: color),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      'baseado na última sessão',
                      style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        carga,
                        style: AppTheme.mono(
                          20,
                          weight: FontWeight.w800,
                        ).copyWith(color: scheme.onSurface),
                      ),
                      const SizedBox(width: 3),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          unit.suffix,
                          style: AppTheme.label(
                            10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (deltaTxt != null)
                    Text(deltaTxt, style: AppTheme.label(11, color: color)),
                  Text(
                    'toque p/ usar',
                    style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card de progressao por tempo (E6) — informativo (alvo de duracao em mm:ss).
  /// Sem "toque p/ usar": o alvo timed vem do plano, nao de input ao vivo.
  Widget _buildTimed(BuildContext context, TimedProgressionSuggestion sug) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color, String verbo) = switch (sug.decision) {
      ProgressionDecision.aumentar => (
        Icons.arrow_upward,
        scheme.primary,
        'AUMENTAR',
      ),
      ProgressionDecision.manter => (
        Icons.arrow_forward,
        scheme.onSurfaceVariant,
        'MANTER',
      ),
      ProgressionDecision.reduzir => (
        Icons.arrow_downward,
        scheme.error,
        'REDUZIR',
      ),
    };
    final deltaTxt = sug.deltaSegundos == 0
        ? null
        : '${sug.deltaSegundos > 0 ? '+' : ''}${sug.deltaSegundos}s';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color),
          boxShadow: AppTheme.cardShadow(scheme),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PROGRESSÃO · $verbo',
                    style: AppTheme.label(11, color: color),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    'duração · baseado na última sessão',
                    style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmtMmss(sug.duracaoSugeridaSegundos),
                  style: AppTheme.mono(
                    20,
                    weight: FontWeight.w800,
                  ).copyWith(color: scheme.onSurface),
                ),
                if (deltaTxt != null)
                  Text(deltaTxt, style: AppTheme.label(11, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LastTimeRow extends ConsumerWidget {
  const _LastTimeRow({required this.unit});

  final WeightUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(exerciseInsightProvider).asData?.value.lastByNumero;
    if (last == null || last.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    final numeros = last.keys.toList()..sort();
    final partes = <String>[];
    for (final n in numeros) {
      final l = last[n]!;
      partes.add('${unit.format(l.cargaKg ?? 0)}×${l.repsRealizadas ?? 0}');
    }

    return Row(
      children: [
        Text(
          'ÚLTIMA VEZ',
          style: AppTheme.label(11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Text(
            partes.join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.mono(
              12,
              weight: FontWeight.w600,
            ).copyWith(color: scheme.onSurface),
          ),
        ),
      ],
    );
  }
}

/// Campo numerico com steppers +/- pra carga e reps. Destaca a borda em
/// [AppTheme.primary] quando o TextField ganha foco (design-system.md §7 —
/// todo componente interativo precisa do estado de foco, nunca "outline:
/// none" sem substituto — o `InputBorder.none` interno so remove o contorno
/// padrao do Material porque este Container assume o papel visualmente).
class _NumberInput extends StatefulWidget {
  const _NumberInput({
    required this.label,
    required this.controller,
    this.allowDecimal = false,
    this.step = 1,
  });

  final String label;
  final TextEditingController controller;
  final bool allowDecimal;
  final num step;

  @override
  State<_NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<_NumberInput> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _bump(num delta) {
    final raw = widget.controller.text.replaceAll(',', '.');
    final current = double.tryParse(raw) ?? 0;
    final next = (current + delta).clamp(0, 9999).toDouble();
    if (widget.allowDecimal) {
      final asString = next % 1 == 0
          ? next.toStringAsFixed(1)
          : next.toStringAsFixed(1);
      widget.controller.text = asString;
    } else {
      widget.controller.text = next.toInt().toString();
    }
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTheme.label(11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.space8),
        AnimatedContainer(
          duration: AppTheme.motionFast,
          curve: AppTheme.easingStandard,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: _focused ? scheme.primary : scheme.outline,
              width: _focused ? 2 : 1,
            ),
            boxShadow: AppTheme.cardShadow(scheme),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepButton(
                  icon: Icons.remove,
                  onTap: () => _bump(-widget.step),
                  onLong: () => _bump(-widget.step * 4),
                  scheme: scheme,
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: widget.allowDecimal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: AppTheme.mono(26, weight: FontWeight.w700),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                _StepButton(
                  icon: Icons.add,
                  onTap: () => _bump(widget.step),
                  onLong: () => _bump(widget.step * 4),
                  scheme: scheme,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.onLong,
    required this.scheme,
  });

  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLong;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLong();
      },
      child: SizedBox(
        width: 44,
        child: Center(child: Icon(icon, color: scheme.onSurface, size: 22)),
      ),
    );
  }
}

class _RpeRow extends StatelessWidget {
  const _RpeRow({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ESFORÇO',
          style: AppTheme.label(11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        // Escala 1-10 em 2 linhas de 5: cabe sem scroll horizontal e mantem
        // alvo de toque >= 48pt. NAO reduzir para 1-5: o progression_engine
        // decide carga com thresholds da escala 1-10 (avgRpe >= 9 / <= 6) e o
        // historico ja tem RPE 1-10 gravado.
        for (final linha in const [
          [1, 2, 3, 4, 5],
          [6, 7, 8, 9, 10],
        ]) ...[
          Row(
            children: [
              for (final i in linha) ...[
                if (i != linha.first) const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: _RpeChip(
                    value: i,
                    selected: value == i,
                    onTap: () => onChanged(value == i ? null : i),
                  ),
                ),
              ],
            ],
          ),
          if (linha.first == 1) const SizedBox(height: AppTheme.space8),
        ],
      ],
    );
  }
}

class _RpeChip extends StatelessWidget {
  const _RpeChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Material + InkWell (em vez de GestureDetector) pra ganhar de graca os
    // state layers de hover/focus/pressed do M3 (design-system.md §7) por
    // cima do AnimatedContainer que ja da o feedback de selecao.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppTheme.motionFast,
          curve: AppTheme.easingStandard,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: AppTheme.motionFast,
            style: AppTheme.mono(
              13,
              weight: selected ? FontWeight.w700 : FontWeight.w500,
            ).copyWith(color: selected ? scheme.onPrimary : scheme.onSurface),
            child: Text('$value'),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.state});

  final ActiveWorkoutState state;

  @override
  Widget build(BuildContext context) {
    final total = state.slots.length;
    final done = state.cursor;
    final scheme = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Container(
      height: 4,
      color: scheme.surfaceContainerHigh,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: AppTheme.motionSlow,
        curve: AppTheme.easingStandard,
        builder: (_, value, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: Container(color: scheme.primary),
        ),
      ),
    );
  }
}

class _FinishedView extends StatelessWidget {
  const _FinishedView({required this.onFinish});

  final Future<void> Function() onFinish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 96,
                color: scheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'CONCLUÍDO',
                style: AppTheme.label(13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Text(
                'Todas as séries feitas.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: onFinish,
                child: const Text('FINALIZAR E VER HISTÓRICO'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ponto pulsante do indicador "EM TREINO" na AppBar — so opacidade (sem
/// bounce/elastic, design-system.md §8), confirma visualmente que a sessao
/// esta ativa mesmo num relance rapido de olho.
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(
        begin: 0.35,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
