import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../library/data/library_repository.dart';
import '../../../domain/entities/exercise.dart';
import '../../library/presentation/exercise_thumb.dart';

/// Picker de exercicios com selecao multipla.
///
/// Usuario toca em varios exercicios para marcar/desmarcar e clica em
/// "ADICIONAR (n)" no rodape pra confirmar. Retorna `List<Exercise>` via pop.
class LibraryPickerSheet extends ConsumerStatefulWidget {
  const LibraryPickerSheet({super.key});

  @override
  ConsumerState<LibraryPickerSheet> createState() => _LibraryPickerState();
}

class _LibraryPickerState extends ConsumerState<LibraryPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _selectedIds = <String>{};
  final _selectedOrder = <Exercise>[]; // mantem ordem de selecao
  Timer? _debounce;
  String _termo = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _termo = v);
    });
  }

  void _toggle(Exercise ex) {
    setState(() {
      if (_selectedIds.contains(ex.id)) {
        _selectedIds.remove(ex.id);
        _selectedOrder.removeWhere((e) => e.id == ex.id);
      } else {
        _selectedIds.add(ex.id);
        _selectedOrder.add(ex);
      }
    });
  }

  void _confirm() {
    Navigator.of(context).pop<List<Exercise>>(_selectedOrder);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(libraryRepositoryProvider);
    final results = repo.search(termo: _termo);
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, controller) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adicionar exercícios',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SELECIONE UM OU MAIS · ${results.length} DISPONIVEIS',
                          style: AppTheme.label(
                            10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onChanged,
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Buscar exercício…',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
            ),
            // List
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum resultado.',
                        style: AppTheme.label(
                          11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: scheme.outline.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (context, i) {
                        final ex = results[i];
                        final isSelected = _selectedIds.contains(ex.id);
                        final selectedIndex = _selectedOrder.indexWhere(
                          (e) => e.id == ex.id,
                        );
                        return _PickerTile(
                          exercise: ex,
                          selected: isSelected,
                          selectedIndex: selectedIndex >= 0
                              ? selectedIndex + 1
                              : null,
                          onTap: () => _toggle(ex),
                        );
                      },
                    ),
            ),
            // Bottom bar
            _BottomBar(
              count: _selectedOrder.length,
              onCancel: () =>
                  Navigator.of(context).pop<List<Exercise>>(const []),
              onConfirm: _selectedOrder.isEmpty ? null : _confirm,
            ),
          ],
        );
      },
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.exercise,
    required this.selected,
    required this.selectedIndex,
    required this.onTap,
  });

  final Exercise exercise;
  final bool selected;
  final int? selectedIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: selected
            ? BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                border: Border(
                  left: BorderSide(color: scheme.primary, width: 3),
                ),
              )
            : null,
        padding: EdgeInsets.fromLTRB(selected ? 9 : 12, 12, 12, 12),
        child: Row(
          children: [
            ExerciseThumb(exercise: exercise, size: 48),
            const SizedBox(width: 12),
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
                      Expanded(
                        child: Text(
                          exercise.equipamento.label.toUpperCase(),
                          style: AppTheme.label(
                            10,
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _SelectionMark(
              selected: selected,
              order: selectedIndex,
              scheme: scheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({
    required this.selected,
    required this.order,
    required this.scheme,
  });

  final bool selected;
  final int? order;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outline,
          width: 1,
        ),
      ),
      child: selected
          ? Text(
              '$order',
              style: AppTheme.mono(
                11,
                weight: FontWeight.w700,
              ).copyWith(color: scheme.onPrimary),
            )
          : null,
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.count,
    required this.onCancel,
    required this.onConfirm,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                flex: 0,
                child: TextButton(
                  onPressed: onCancel,
                  child: Text(
                    'CANCELAR',
                    style: AppTheme.label(12, color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: onConfirm,
                    child: Text(
                      count == 0
                          ? 'SELECIONE EXERCÍCIOS'
                          : count == 1
                          ? 'ADICIONAR 1 EXERCÍCIO'
                          : 'ADICIONAR $count EXERCÍCIOS',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
