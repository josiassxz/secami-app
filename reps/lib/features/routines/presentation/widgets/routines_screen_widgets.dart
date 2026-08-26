part of '../routines_screen.dart';

class _RoutinesList extends ConsumerWidget {
  const _RoutinesList({required this.rows, required this.isFixo});

  final List<RoutineRow> rows;
  final bool isFixo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFixo)
                Text(
                  '7',
                  style: AppTheme.mono(
                    96,
                    weight: FontWeight.w300,
                  ).copyWith(color: scheme.onSurfaceVariant, height: 1),
                )
              else
                Icon(
                  Icons.all_inclusive,
                  size: 80,
                  color: scheme.onSurfaceVariant,
                ),
              const SizedBox(height: 4),
              Text(
                isFixo ? 'DIAS DA SEMANA' : 'TREINOS AVULSOS',
                style: AppTheme.label(11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Text(
                isFixo
                    ? 'Nenhuma rotina semanal ainda.\nToque em "Nova rotina" pra criar a primeira.'
                    : 'Nenhum treino avulso.\nUse pra mobilidade ou treino de viagem.',
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = rows[i];
        final dias = RoutineService.decodeDias(r.diasDaSemana)..sort();
        return _SwipeableRoutine(routine: r, dias: dias, index: i + 1);
      },
    );
  }
}

/// Card de rotina com swipe horizontal:
///  - Arrastar pra esquerda revela 'Editar' e 'Excluir' (com confirmacao).
///  - Tap normal abre o builder da rotina.
class _SwipeableRoutine extends ConsumerStatefulWidget {
  const _SwipeableRoutine({
    required this.routine,
    required this.dias,
    required this.index,
  });

  final RoutineRow routine;
  final List<int> dias;
  final int index;

  @override
  ConsumerState<_SwipeableRoutine> createState() => _SwipeableRoutineState();
}

class _SwipeableRoutineState extends ConsumerState<_SwipeableRoutine>
    with SingleTickerProviderStateMixin {
  static const _maxDrag = 168.0; // largura das duas acoes
  double _drag = 0;
  late AnimationController _ctrl;
  Animation<double>? _tween;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _ctrl.addListener(() {
      if (_tween != null) setState(() => _drag = _tween!.value);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _tween = Tween<double>(
      begin: _drag,
      end: target,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl
      ..reset()
      ..forward();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _drag = (_drag - d.delta.dx).clamp(0.0, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (_drag > _maxDrag / 2) {
      _animateTo(_maxDrag);
    } else {
      _animateTo(0);
    }
  }

  void _close() => _animateTo(0);

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      // dialogCtx (NAO o context da linha): a linha fica sob o Navigator
      // aninhado da ShellRoute, mas o dialog vive no Navigator raiz. Usar o
      // context da linha pop-ava a pagina /routines do Navigator da shell ->
      // filho da shell vazio -> TELA PRETA. dialogCtx fecha o proprio dialog.
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Excluir rotina?'),
        content: Text(
          '"${widget.routine.nome}" sera removida da semana. O histórico continua salvo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogCtx).colorScheme.error,
              foregroundColor: Theme.of(dialogCtx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );
    if (ok != true) {
      _close();
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Fecha o swipe ANTES do await: se a linha some da lista durante o
      // delete, o State e descartado e a animacao nao mexe em widget morto.
      _close();
      await ref.read(routineServiceProvider).remove(widget.routine.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('"${widget.routine.nome}" excluída'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e, st) {
      await Observability.captureError(e, st, hint: 'routine_delete_swipe');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Erro ao excluir'),
          content: Text('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _editar() {
    _close();
    context.push('/routines/${widget.routine.id}');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      // Tap no card normal navega; o _close evita gesto preso aberto.
      onTap: () {
        if (_drag > 0) {
          _close();
        } else {
          context.push('/routines/${widget.routine.id}');
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Stack(
          children: [
            // Fundo: dois botoes revelados ao arrastar pra esquerda.
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionTile(
                    width: _maxDrag / 2,
                    color: scheme.surfaceContainerHigh,
                    icon: Icons.edit_outlined,
                    label: 'EDITAR',
                    onTap: _editar,
                    iconColor: scheme.onSurface,
                  ),
                  _ActionTile(
                    width: _maxDrag / 2,
                    color: scheme.error,
                    icon: Icons.delete_outline,
                    label: 'EXCLUIR',
                    onTap: _excluir,
                    iconColor: scheme.onError,
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: Offset(-_drag, 0),
              child: _RoutineCard(
                routine: widget.routine,
                dias: widget.dias,
                index: widget.index,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.width,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.iconColor,
  });

  final double width;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        color: color,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.label(
                11,
                color: iconColor,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.dias,
    required this.index,
  });

  final RoutineRow routine;
  final List<int> dias;
  final int index;

  static const _diasShort = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  routine.nome,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
          if (routine.origem == 'atribuida') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.sports_outlined, size: 14, color: scheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Do seu treinador',
                  style: AppTheme.mono(
                    11,
                    weight: FontWeight.w500,
                  ).copyWith(color: scheme.primary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Calendario semanal mini (DOM..SAB)
          Row(
            children: List.generate(7, (i) {
              final ativo = dias.contains(i);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 6 ? 0 : 4),
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ativo
                          ? scheme.primary
                          : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: ativo ? scheme.primary : scheme.outline,
                      ),
                    ),
                    child: Text(
                      _diasShort[i],
                      style: AppTheme.mono(11, weight: FontWeight.w700)
                          .copyWith(
                            color: ativo
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _HomeStatsBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(homeStatsProvider);
    final scheme = Theme.of(context).colorScheme;

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (s) {
        if (s.treinsEstaSemana == 0 && s.streakDias == 0) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: scheme.outline),
            boxShadow: AppTheme.cardShadow(scheme),
          ),
          child: Row(
            children: [
              // Streak — dourado (scheme.secondary), mesmo tom usado no
              // banner de PR: streak tambem e uma conquista.
              if (s.streakDias > 0) ...[
                Icon(
                  Icons.local_fire_department,
                  size: 16,
                  color: scheme.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${s.streakDias}d',
                  style: AppTheme.mono(
                    13,
                    weight: FontWeight.w700,
                  ).copyWith(color: scheme.onSurface),
                ),
                const SizedBox(width: 12),
              ],
              // Treinos esta semana
              Icon(
                Icons.fitness_center,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${s.treinsEstaSemana}×',
                style: AppTheme.mono(
                  13,
                  weight: FontWeight.w600,
                ).copyWith(color: scheme.onSurface),
              ),
              const SizedBox(width: 4),
              Text(
                'esta semana',
                style: AppTheme.label(11, color: scheme.onSurfaceVariant),
              ),
              // Volume diff
              if (s.diffPct != null) ...[
                const Spacer(),
                _VolumeDiff(pct: s.diffPct!),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _VolumeDiff extends StatelessWidget {
  const _VolumeDiff({required this.pct});

  final double pct;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final up = pct >= 0;
    // Verde institucional pra alta (crescimento), vermelho do tema pra queda
    // — nada de cor solta fora do ColorScheme.
    final color = up ? scheme.primary : scheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_upward : Icons.arrow_downward,
          size: 11,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '${up ? '+' : ''}${pct.toStringAsFixed(0)}% vol',
          style: AppTheme.mono(
            11,
            weight: FontWeight.w600,
          ).copyWith(color: color),
        ),
      ],
    );
  }
}
