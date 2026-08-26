part of '../library_screen.dart';

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter, required this.onClear});

  final bool hasFilter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 64,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'Nenhum exercício bate com os filtros.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (hasFilter) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onClear,
                child: const Text('Limpar filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterStrip extends ConsumerWidget {
  const _FilterStrip({required this.filter});

  final LibraryFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _ChipMulti<GrupoMuscular>(
            label: 'GRUPO',
            selected: filter.grupos,
            values: GrupoMuscular.values,
            labelOf: (v) => v.label,
            onToggle: (v) =>
                ref.read(libraryFilterProvider.notifier).toggleGrupo(v),
          ),
          _ChipMulti<PadraoMovimento>(
            label: 'MOVIMENTO',
            selected: filter.padroes,
            values: PadraoMovimento.values,
            labelOf: (v) => v.label,
            onToggle: (v) =>
                ref.read(libraryFilterProvider.notifier).togglePadrao(v),
          ),
          _ChipMulti<Equipamento>(
            label: 'EQUIPAMENTO',
            selected: filter.equipamentos,
            values: Equipamento.values,
            labelOf: (v) => v.label,
            onToggle: (v) =>
                ref.read(libraryFilterProvider.notifier).toggleEquipamento(v),
          ),
        ],
      ),
    );
  }
}

class _ChipMulti<T> extends StatelessWidget {
  const _ChipMulti({
    required this.label,
    required this.selected,
    required this.values,
    required this.labelOf,
    required this.onToggle,
  });

  final String label;
  final Set<T> selected;
  final List<T> values;
  final String Function(T) labelOf;
  final void Function(T) onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSel = selected.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        backgroundColor: hasSel ? scheme.primary : scheme.surfaceContainerHigh,
        side: BorderSide(color: hasSel ? scheme.primary : scheme.outline),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTheme.label(
                11,
                color: hasSel ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
            if (hasSel) ...[
              const SizedBox(width: 6),
              Text(
                '${selected.length}',
                style: AppTheme.mono(
                  11,
                  weight: FontWeight.w700,
                ).copyWith(color: scheme.onPrimary),
              ),
            ],
          ],
        ),
        onPressed: () async {
          await showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            backgroundColor: scheme.surface,
            builder: (ctx) {
              return StatefulBuilder(
                builder: (ctx, setLocal) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 12, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                icon: const Icon(Icons.close),
                                tooltip: 'Fechar',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: values.map((v) {
                              final isSel = selected.contains(v);
                              return FilterChip(
                                label: Text(labelOf(v)),
                                selected: isSel,
                                onSelected: (_) {
                                  onToggle(v);
                                  setLocal(() {});
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ExerciseTile extends ConsumerWidget {
  const _ExerciseTile({required this.exercise, required this.index});

  final Exercise exercise;
  final int index;

  bool get _isCustom => ExerciseId.parse(exercise.id).isCustom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    final Widget tile = InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: scheme.surface,
        builder: (_) => ExerciseDetailSheet(exercise: exercise),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Row(
          children: [
            // Index editorial à esquerda (numero do exercicio)
            SizedBox(
              width: 28,
              child: Text(
                (index + 1).toString().padLeft(2, '0'),
                style: AppTheme.mono(
                  11,
                  weight: FontWeight.w500,
                ).copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            ExerciseThumb(exercise: exercise, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.nome,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        exercise.grupoPrimario.label.toUpperCase(),
                        style: AppTheme.label(11, color: scheme.primary),
                      ),
                      Text(
                        '  ·  ',
                        style: AppTheme.label(
                          10,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        exercise.equipamento.label.toUpperCase(),
                        style: AppTheme.label(
                          10,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isCustom)
              Icon(
                Icons.edit_outlined,
                color: scheme.onSurfaceVariant,
                size: 18,
              )
            else
              Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
                size: 20,
              ),
          ],
        ),
      ),
    );

    if (!_isCustom) return tile;

    // Exercicios custom: swipe para arquivar
    return Dismissible(
      key: ValueKey(exercise.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: scheme.error,
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Arquivar exercício?'),
            content: Text('"${exercise.nome}" será removido da biblioteca.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('ARQUIVAR'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        final rawId = exercise.id.replaceFirst('custom:', '');
        ref.read(customExerciseServiceProvider).archive(rawId);
      },
      child: tile,
    );
  }
}
